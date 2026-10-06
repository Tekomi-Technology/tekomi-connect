import os
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Header, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field

from rag_core import HybridRagStore, RagError


class IndexDocument(BaseModel):
    model_config = ConfigDict(extra="forbid")

    account_id: int = Field(gt=0)
    record_type: str = Field(min_length=1, max_length=100)
    record_id: int = Field(gt=0)
    text: str = Field(min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)
    openrouter_api_key: str = Field(min_length=1, repr=False)


class BatchIndexRequest(BaseModel):
    documents: list[IndexDocument] = Field(min_length=1, max_length=500)


class SearchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    account_id: int = Field(gt=0)
    query: str = Field(min_length=1)
    record_type: str | None = Field(default=None, max_length=100)
    filters: dict[str, Any] = Field(default_factory=dict)
    limit: int = Field(default=5, ge=1, le=50)
    openrouter_api_key: str = Field(min_length=1, repr=False)


class DeleteRequest(BaseModel):
    account_id: int = Field(gt=0)
    record_type: str = Field(min_length=1, max_length=100)
    record_id: int = Field(gt=0)


def _check_token(token: str | None) -> None:
    expected = os.getenv("RAG_SERVICE_TOKEN", "")
    if expected and token != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid RAG service token")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    app.state.store = HybridRagStore.from_environment()
    yield


app = FastAPI(title="Tekomi Core RAG", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/index")
def index_document(document: IndexDocument, x_rag_service_token: str | None = Header(default=None)) -> dict[str, Any]:
    _check_token(x_rag_service_token)
    try:
        return app.state.store.index_document(document.model_dump())
    except RagError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/v1/index/batch")
def index_documents(request: BatchIndexRequest, x_rag_service_token: str | None = Header(default=None)) -> dict[str, Any]:
    _check_token(x_rag_service_token)
    try:
        return app.state.store.index_documents([document.model_dump() for document in request.documents])
    except RagError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/v1/search")
def search(request: SearchRequest, x_rag_service_token: str | None = Header(default=None)) -> dict[str, Any]:
    _check_token(x_rag_service_token)
    try:
        return app.state.store.search(request.model_dump())
    except RagError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/v1/delete")
def delete_document(request: DeleteRequest, x_rag_service_token: str | None = Header(default=None)) -> dict[str, Any]:
    _check_token(x_rag_service_token)
    try:
        return app.state.store.delete_document(request.model_dump())
    except RagError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
