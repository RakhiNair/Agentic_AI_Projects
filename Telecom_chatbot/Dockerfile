# Telecom RAG Chatbot — Streamlit UI backed by ChromaDB (vectors) and SQLite (tickets)

FROM python:3.11-slim

# uv for fast, lockfile-reproducible installs
RUN pip install --no-cache-dir uv==0.11.3

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    HF_HOME=/app/.cache/huggingface \
    TRANSFORMERS_VERBOSITY=error \
    ANONYMIZED_TELEMETRY=False \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

WORKDIR /app

# 1) Dependencies only (cached layer — rebuilt only when the lockfile changes)
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# 2) Application code + source data (faq.csv, tickets.db, telecom_guide.pdf)
COPY *.py docker-entrypoint.sh ./
COPY data/ ./data/

RUN chmod +x docker-entrypoint.sh \
 && useradd --create-home --uid 1000 appuser \
 && mkdir -p /app/chroma_store /app/.cache/huggingface \
 && chown -R appuser:appuser /app
USER appuser

# Persist the vector store and the downloaded embedding model across runs
VOLUME ["/app/chroma_store", "/app/.cache/huggingface"]

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8501/_stcore/health')" || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
