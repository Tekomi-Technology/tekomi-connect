# Tekomi Core RAG

This service owns retrieval vectors for Tekomi. It calls OpenRouter with the
tenant's BYOK key for `baai/bge-m3` dense embeddings and builds a Qdrant sparse
BM25-style vector from normalized tokens. Qdrant fuses the named `dense` and
`sparse` searches with RRF and every query is constrained by `account_id`.

The service stores only its vocabulary in the mounted `/data` directory. FAQ,
FAQ-suggestion, and help-center article metadata remains in Rails/Postgres;
their retrieval vectors and chunks live in Qdrant.

Run locally:

```bash
docker compose up qdrant rag
curl http://localhost:8090/health
```

After the Rails migration has run, backfill existing records with:

```bash
bundle exec rake tekomi:rag:backfill
```
