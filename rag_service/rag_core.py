import hashlib
import math
import os
import re
import sqlite3
import threading
import time
import uuid
from collections import Counter
from typing import Any

import httpx
from qdrant_client import QdrantClient, models


class RagError(RuntimeError):
    """Raised when the RAG service cannot complete an operation."""


class Vocabulary:
    def __init__(self, path: str):
        self._lock = threading.Lock()
        self._connection = sqlite3.connect(path, check_same_thread=False)
        self._connection.execute("CREATE TABLE IF NOT EXISTS tokens (token TEXT PRIMARY KEY, token_id INTEGER UNIQUE NOT NULL)")
        self._connection.commit()

    def ids_for(self, tokens: list[str]) -> dict[str, int]:
        unique_tokens = sorted(set(tokens))
        if not unique_tokens:
            return {}

        with self._lock:
            placeholders = ",".join("?" for _ in unique_tokens)
            existing = dict(self._connection.execute(
                f"SELECT token, token_id FROM tokens WHERE token IN ({placeholders})",
                unique_tokens,
            ).fetchall())
            next_id = self._connection.execute("SELECT COALESCE(MAX(token_id), 0) + 1 FROM tokens").fetchone()[0]
            for token in unique_tokens:
                if token in existing:
                    continue
                existing[token] = next_id
                self._connection.execute("INSERT INTO tokens(token, token_id) VALUES (?, ?)", (token, next_id))
                next_id += 1
            self._connection.commit()
            return existing


class OpenRouterEmbedder:
    def __init__(self, model: str, timeout_seconds: float = 60):
        self.model = model
        self.timeout = httpx.Timeout(timeout_seconds, connect=10)

    def embed(self, texts: list[str], api_key: str) -> list[list[float]]:
        try:
            response = httpx.post(
                "https://openrouter.ai/api/v1/embeddings",
                headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                json={"model": self.model, "input": texts},
                timeout=self.timeout,
            )
            response.raise_for_status()
            data = response.json().get("data", [])
            embeddings = sorted(data, key=lambda item: item["index"])
            if len(embeddings) != len(texts):
                raise RagError("OpenRouter returned an incomplete embedding response")
            return [item["embedding"] for item in embeddings]
        except (httpx.HTTPError, KeyError, TypeError, ValueError) as error:
            raise RagError(f"OpenRouter embedding failed: {error}") from error


class HybridRagStore:
    TOKEN_PATTERN = re.compile(r"[\wÀ-ỹ]+", re.UNICODE)
    COLLECTION = os.getenv("QDRANT_COLLECTION", "tekomi_rag")

    def __init__(self, qdrant: QdrantClient, embedder: OpenRouterEmbedder, vocabulary: Vocabulary):
        self.qdrant = qdrant
        self.embedder = embedder
        self.vocabulary = vocabulary
        self.ensure_collection()

    @classmethod
    def from_environment(cls) -> "HybridRagStore":
        qdrant = QdrantClient(
            url=os.getenv("QDRANT_URL", "http://qdrant:6333"),
            api_key=os.getenv("QDRANT_API_KEY") or None,
            timeout=float(os.getenv("QDRANT_TIMEOUT_SECONDS", "30")),
        )
        vocabulary = Vocabulary(os.getenv("RAG_VOCAB_PATH", "/data/vocabulary.sqlite3"))
        embedder = OpenRouterEmbedder(os.getenv("RAG_DENSE_MODEL", "baai/bge-m3"))
        last_error = None
        for attempt in range(10):
            try:
                return cls(qdrant, embedder, vocabulary)
            except Exception as error:  # Qdrant may still be booting when compose starts this service.
                last_error = error
                if attempt == 9:
                    break
                time.sleep(2)
        raise RagError(f"Qdrant is unavailable: {last_error}")

    def ensure_collection(self) -> None:
        if self.qdrant.collection_exists(self.COLLECTION):
            return

        self.qdrant.create_collection(
            collection_name=self.COLLECTION,
            vectors_config={"dense": models.VectorParams(size=1024, distance=models.Distance.COSINE)},
            sparse_vectors_config={"sparse": models.SparseVectorParams(modifier=models.Modifier.IDF)},
        )
        for field in ("account_id", "record_type", "record_id", "assistant_id", "article_id", "status", "language"):
            self.qdrant.create_payload_index(
                collection_name=self.COLLECTION,
                field_name=field,
                field_schema="integer" if field.endswith("_id") else "keyword",
            )

    def index_document(self, document: dict[str, Any]) -> dict[str, Any]:
        return self.index_documents([document])

    def index_documents(self, documents: list[dict[str, Any]]) -> dict[str, Any]:
        by_key: dict[tuple[int, str, int], dict[str, Any]] = {}
        for document in documents:
            by_key[(document["account_id"], document["record_type"], document["record_id"])] = document

        for document in by_key.values():
            self.delete_document(document)

        points: list[models.PointStruct] = []
        for document in by_key.values():
            chunks = self.chunk_text(document["text"])
            embeddings = self.embedder.embed(chunks, document["openrouter_api_key"])
            for chunk_index, (chunk, dense) in enumerate(zip(chunks, embeddings)):
                sparse = self.sparse_vector(chunk)
                payload = {
                    **document.get("payload", {}),
                    "account_id": document["account_id"],
                    "record_type": document["record_type"],
                    "record_id": document["record_id"],
                    "chunk_index": chunk_index,
                    "text": chunk,
                }
                points.append(models.PointStruct(
                    id=self.point_id(document["record_type"], document["record_id"], chunk_index),
                    vector={"dense": dense, "sparse": sparse},
                    payload=payload,
                ))

        if points:
            self.qdrant.upsert(collection_name=self.COLLECTION, points=points, wait=True)
        return {"indexed": len(points), "records": len(by_key)}

    def search(self, request: dict[str, Any]) -> dict[str, Any]:
        dense = self.embedder.embed([request["query"]], request["openrouter_api_key"])[0]
        sparse = self.sparse_vector(request["query"])
        conditions = [models.FieldCondition(key="account_id", match=models.MatchValue(value=request["account_id"]))]
        if request.get("record_type"):
            conditions.append(models.FieldCondition(key="record_type", match=models.MatchValue(value=request["record_type"])))
        for key, value in request.get("filters", {}).items():
            if isinstance(value, list):
                conditions.append(models.FieldCondition(key=key, match=models.MatchAny(any=value)))
            else:
                conditions.append(models.FieldCondition(key=key, match=models.MatchValue(value=value)))
        query_filter = models.Filter(must=conditions)
        prefetch_limit = min(request["limit"] * 4, 100)
        result = self.qdrant.query_points(
            collection_name=self.COLLECTION,
            prefetch=[
                models.Prefetch(query=dense, using="dense", limit=prefetch_limit, filter=query_filter),
                models.Prefetch(query=sparse, using="sparse", limit=prefetch_limit, filter=query_filter),
            ],
            query=models.FusionQuery(fusion=models.Fusion.RRF),
            limit=prefetch_limit,
            with_payload=True,
        )
        seen: set[tuple[str, int]] = set()
        hits = []
        for point in result.points:
            payload = point.payload or {}
            key = (str(payload.get("record_type")), int(payload.get("record_id", 0)))
            if key in seen:
                continue
            seen.add(key)
            hits.append({"record_type": key[0], "record_id": key[1], "score": point.score, "payload": payload})
            if len(hits) >= request["limit"]:
                break
        return {"hits": hits}

    def delete_document(self, document: dict[str, Any]) -> dict[str, Any]:
        query_filter = models.Filter(must=[
            models.FieldCondition(key="account_id", match=models.MatchValue(value=document["account_id"])),
            models.FieldCondition(key="record_type", match=models.MatchValue(value=document["record_type"])),
            models.FieldCondition(key="record_id", match=models.MatchValue(value=document["record_id"])),
        ])
        self.qdrant.delete(collection_name=self.COLLECTION, points_selector=models.FilterSelector(filter=query_filter), wait=True)
        return {"deleted": True}

    def sparse_vector(self, text: str) -> models.SparseVector:
        tokens = self.tokens(text)
        token_ids = self.vocabulary.ids_for(tokens)
        counts = Counter(token_ids[token] for token in tokens if token in token_ids)
        return models.SparseVector(
            indices=list(counts.keys()),
            values=[1.0 + math.log(count) for count in counts.values()],
        )

    @classmethod
    def tokens(cls, text: str) -> list[str]:
        return [token.casefold() for token in cls.TOKEN_PATTERN.findall(text)]

    @staticmethod
    def chunk_text(text: str, size: int = 2000, overlap: int = 200) -> list[str]:
        normalized = " ".join(text.split())
        if not normalized:
            return []
        if len(normalized) <= size:
            return [normalized]
        step = size - overlap
        return [normalized[start:start + size] for start in range(0, len(normalized), step) if normalized[start:start + size]]

    @staticmethod
    def point_id(record_type: str, record_id: int, chunk_index: int) -> str:
        raw = f"tekomi-rag:{record_type}:{record_id}:{chunk_index}".encode()
        digest = hashlib.md5(raw).digest()
        return str(uuid.UUID(bytes=digest, version=4))
