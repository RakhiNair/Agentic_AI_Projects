#!/bin/sh
# Builds the Chroma vector store on first start (or when FORCE_REINGEST=1),
# then hands off to the container command (Streamlit by default).
set -e

if [ "${FORCE_REINGEST:-0}" = "1" ] || [ ! -f chroma_store/chroma.sqlite3 ]; then
    echo "[entrypoint] Building Chroma vector store from data/ ..."
    rm -rf chroma_store/* 2>/dev/null || true
    python ingest_faq.py
    python ingest_tickets.py
    python ingest_pdf.py
    echo "[entrypoint] Ingestion complete."
else
    echo "[entrypoint] Existing Chroma store found — skipping ingestion."
fi

if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "[entrypoint] WARNING: GROQ_API_KEY is not set; the chatbot cannot generate answers." >&2
fi

exec "$@"
