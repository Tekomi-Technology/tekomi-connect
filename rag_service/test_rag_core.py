import tempfile

from qdrant_client import QdrantClient

from rag_core import HybridRagStore, Vocabulary


class FakeEmbedder:
    def embed(self, texts, _api_key):
        return [[0.1] * 1024 for _ in texts]


def test_hybrid_search_is_tenant_scoped_and_deduplicates_records():
    with tempfile.TemporaryDirectory() as path:
        store = HybridRagStore(
            QdrantClient(":memory:"),
            FakeEmbedder(),
            Vocabulary(f"{path}/vocabulary.sqlite3"),
        )
        store.index_documents([
            {
                "account_id": 1,
                "record_type": "assistant_response",
                "record_id": 10,
                "text": "đổi trả sản phẩm",
                "payload": {"assistant_id": 5, "status": "approved"},
                "openrouter_api_key": "test",
            },
            {
                "account_id": 2,
                "record_type": "assistant_response",
                "record_id": 20,
                "text": "đổi trả sản phẩm",
                "payload": {"assistant_id": 5, "status": "approved"},
                "openrouter_api_key": "test",
            },
        ])

        result = store.search({
            "account_id": 1,
            "record_type": "assistant_response",
            "filters": {"assistant_id": 5, "status": "approved"},
            "query": "đổi trả",
            "limit": 5,
            "openrouter_api_key": "test",
        })

        assert [hit["record_id"] for hit in result["hits"]] == [10]
