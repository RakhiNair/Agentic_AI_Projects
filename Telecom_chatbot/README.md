# RAG Telecom Chatbot

A Retrieval-Augmented Generation (RAG) customer care chatbot for telecom support. It answers questions about mobile connectivity, billing, SIM issues, and roaming by retrieving relevant context from three knowledge sources and generating responses with Qwen3.8-27B via Groq.

## Architecture

```
User question
     │
     ▼
Merged Retriever (top-k from each store)
  ├── ChromaDB · faq        (FAQ entries from CSV)
  ├── ChromaDB · tickets    (resolved support tickets from SQLite)
  └── ChromaDB · guides     (PDF guide chunks)
     │
     ▼
ChatPromptTemplate → Qwen3.8-27B (Groq) → Answer
```

**Embedding model:** `sentence-transformers/all-MiniLM-L6-v2` (runs locally via HuggingFace)  
**LLM:** `qwen/qwen3.8-27b` served by [Groq](https://groq.com) (override with `GROQ_MODEL` in `.env`)

## Project Structure

```
rag-telecom-chatbot/
├── app.py              # Streamlit web UI
├── main.py             # CLI entry point
├── rag_chain.py        # Builds the LangChain RAG chain
├── retriever.py        # Merges the three Chroma retrievers
├── ingest_faq.py       # Loads data/faq.csv → Chroma 'faq' collection
├── ingest_tickets.py   # Loads data/tickets.db → Chroma 'tickets' collection
├── ingest_pdf.py       # Loads data/telecom_guide.pdf → Chroma 'guides' collection
├── data/
│   ├── faq.csv             # FAQ question/answer pairs
│   ├── tickets.db          # SQLite database of resolved support tickets
│   ├── telecom_guide.pdf   # Telecom user guide (chunked at ingest)
│   ├── seed_tickets.py     # Script to seed the tickets database
│   └── generate_pdf.py     # Script to generate the telecom guide PDF
├── chroma_store/       # Persisted Chroma vector database (created at ingest)
├── pyproject.toml
├── uv.lock
└── .env.example
```

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (recommended) or pip
- A [Groq API key](https://console.groq.com)
- A [HuggingFace token](https://huggingface.co/settings/tokens) (for downloading the embedding model)

## Setup

**1. Clone and install dependencies**

```bash
git clone <repo-url>
cd rag-telecom-chatbot
uv sync          # or: pip install -e .
```

**2. Configure environment variables**

```bash
cp .env.example .env
```

Edit `.env` and fill in your keys:

```
GROQ_API_KEY=your_groq_api_key_here
GROQ_MODEL=qwen/qwen3.8-27b
HF_TOKEN=your_huggingface_token_here
```

- Write each line as `NAME=value`, with no quotes and no spaces around `=`. Docker passes quotes through as part of the value.
- `GROQ_MODEL` is optional. Groq retires models from time to time; if you get a `model_not_found` error, list the models your key can use with `curl https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY"` and set `GROQ_MODEL` to one of them. If the new model is not a reasoning model, remove `reasoning_format="parsed"` from `rag_chain.py`.
- `HF_TOKEN` is optional; the embedding model is public.

**3. Ingest data into Chroma**

Run the three ingestion scripts once to build the vector store:

```bash
python ingest_faq.py
python ingest_tickets.py
python ingest_pdf.py
```

Each script embeds the source data and persists it to `chroma_store/`. Re-run a script only when its source data changes.

## Running the App

**Streamlit web UI**

```bash
streamlit run app.py
```

Opens at `http://localhost:8501`. The sidebar has one-click sample questions and a button to clear the conversation history.

**CLI**

```bash
python main.py
```

Interactive prompt — type a question and press Enter. Type `quit` to exit.

## Running with Docker

The `Dockerfile` packages the Streamlit app with all dependencies (installed from `uv.lock`) and the source data (`faq.csv`, `tickets.db`, `telecom_guide.pdf`).

**1. Build the image** (from the `Telecom_chatbot/` directory)

```bash
docker build -t telecom-rag-chatbot .
```

**2. Run the container**

```bash
docker run --rm -p 8501:8501 --env-file .env -v telecom-chroma:/app/chroma_store -v telecom-hf-cache:/app/.cache/huggingface telecom-rag-chatbot
```

Open `http://localhost:8501`.

- `--env-file .env` passes `GROQ_API_KEY` (required) and `HF_TOKEN` (optional) into the container. You can use `-e GROQ_API_KEY=...` instead.
- On first start the entrypoint runs `ingest_faq.py`, `ingest_tickets.py` and `ingest_pdf.py` to build the Chroma store from the CSV, the SQLite ticket database and the PDF. This downloads the embedding model from Hugging Face, so the first start takes a minute or two and needs internet access.
- The two named volumes keep the Chroma store and the embedding model between runs, so later starts skip ingestion. Without them, ingestion runs again on every start.
- To rebuild the vector store after changing anything in `data/`, rebuild the image and add `-e FORCE_REINGEST=1` to the run command.

**Troubleshooting**

| Error | Fix |
|---|---|
| `--env-file: open .env: ... cannot find the file` | Run the command from the `Telecom_chatbot/` folder and create `.env` from `.env.example`. |
| `Bind for 0.0.0.0:8501 failed: port is already allocated` | An earlier container is still running. Stop it with `docker ps` then `docker stop <id>`, or map another port: `-p 8502:8501`. |
| `401 Invalid API Key` | Check `GROQ_API_KEY` in `.env` (no quotes or spaces), then restart the container. No rebuild is needed for `.env` changes. |
| `404 model_not_found` | Set `GROQ_MODEL` in `.env` to a model your key can use (see Setup). |
| `ModuleNotFoundError` after editing code | Rebuild the image. Code is copied in at build time. |

**Run the CLI instead of the web UI**

```bash
docker run --rm -it --env-file .env -v telecom-chroma:/app/chroma_store -v telecom-hf-cache:/app/.cache/huggingface telecom-rag-chatbot python main.py
```

## Data Sources

| Collection | Source file | Granularity |
|---|---|---|
| `faq` | `data/faq.csv` | 1 document per FAQ row |
| `tickets` | `data/tickets.db` | 1 document per resolved ticket |
| `guides` | `data/telecom_guide.pdf` | Chunks of 600 chars with 100-char overlap |

The retriever fetches the top 3 results from each collection (9 context documents total) for every query.

## Regenerating Seed Data

```bash
# Seed the SQLite ticket database
python data/seed_tickets.py

# Regenerate the PDF guide
python data/generate_pdf.py
```

After regenerating, re-run the corresponding ingest script.
