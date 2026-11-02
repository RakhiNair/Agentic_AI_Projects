# Agentic_AI_Projects

Built two Agentic AI projects as part of the **Codebasics Agentic AI Crash Course**:

### 1. 🛒 Shopping Agent
- Developed an AI-powered shopping assistant using:
  - LangChain
  - ChromaDB
  - Llama Vision Model
  - Qwen LLM
  - Streamlit
  - SQLite
  - Hugging Face
  - Sentence Transformers

### 2. 📞 Telecom RAG Chatbot 🐳
- Built a Retrieval-Augmented Generation (RAG) chatbot for telecom-related queries using:
  - LangChain
  - ChromaDB
  - Qwen LLM (`qwen/qwen3.8-27b` via Groq)
  - Streamlit
  - SQLite
  - Hugging Face
  - Sentence Transformers
  - **Docker**
- Answers questions about connectivity, billing, SIM issues and roaming by retrieving context from three knowledge sources: an FAQ (CSV), resolved support tickets (SQLite) and a telecom user guide (PDF).

#### 🐳 Docker Implementation
The Telecom RAG Chatbot is containerised, so it runs the same way on any machine with Docker, with no Python setup needed.

- **`Dockerfile`**: builds an image with Python 3.11, all dependencies (pinned in `uv.lock`), the app code and the source data. It runs as a non-root user, exposes port `8501` and includes a health check.
- **`docker-entrypoint.sh`**: on first start, builds the ChromaDB vector store from the FAQ CSV, the SQLite ticket database and the PDF guide, then launches the Streamlit app.
- **Persistent volumes**: keep the vector store and the downloaded embedding model between runs, so later starts are instant.
- **Configurable model**: the Groq model is set with `GROQ_MODEL` in `.env`, so you can switch models without changing code.
- **`.dockerignore`**: keeps secrets (`.env`) and local build files out of the image.

**Quick start**

```bash
cd Telecom_chatbot
cp .env.example .env        # then add your GROQ_API_KEY
docker build -t telecom-rag-chatbot .
docker run --rm -p 8501:8501 --env-file .env \
  -v telecom-chroma:/app/chroma_store \
  -v telecom-hf-cache:/app/.cache/huggingface \
  telecom-rag-chatbot
```

Then open **http://localhost:8501**.

> On Windows Command Prompt, use `copy .env.example .env` and put the `docker run` command on a single line.

See [`Telecom_chatbot/README.md`](Telecom_chatbot/README.md) for the full setup, architecture and troubleshooting guide.

---

Both projects were developed while following the **Codebasics Agentic AI Crash Course**.
