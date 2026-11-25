# Agentic AI Projects

Two agentic AI applications built while following the **Codebasics Agentic AI Crash Course (2026)**: a tool-calling shopping agent and a Dockerised RAG customer-support chatbot. Both use Groq for fast LLM inference.

| Project | What it does | Key tech |
| --- | --- | --- |
| [🛒 Shopping Agent](shopping_agent/) | Finds grocery products by text or photo, checks ratings and places orders | LangChain agent, Qwen3-32B, Llama 4 Scout (vision), SQLite, Streamlit |
| [📞 Telecom RAG Chatbot](Telecom_chatbot/) 🐳 | Answers telecom support questions from FAQs, past tickets and a user guide | LangChain, ChromaDB, Sentence Transformers, Qwen on Groq, Streamlit, Docker |

---

## 1. 🛒 Shopping Agent

A conversational grocery assistant. Ask *"I want organic honey under $20 with a 4.5+ rating"* and it searches the catalogue, checks ratings, lists the matching products, and orders the one you choose.

### How it works

A LangChain agent (`create_agent`) running **Qwen3-32B on Groq** decides which tool to call:

| Tool | What it does |
| --- | --- |
| `search_products` | Keyword search over product name, description and category in SQLite, with optional max-price and organic filters (parameterised SQL) |
| `get_rating` | Returns a product's average rating and review count |
| `checkout` | Saves an order to the `orders` table and returns a confirmation |
| `describe_product_image` | Sends an uploaded photo to **Llama 4 Scout** (vision model) and returns product attributes as JSON, which feed into `search_products` |

The system prompt defines three flows (image search, browsing, ordering) and two rules: **never place an order without explicit confirmation**, and **never guess a product ID**. The Streamlit app passes the full chat history on every turn, so the agent understands replies like *"order number 2"*.

**Data:** `setup_db.py` creates `store.db` with 32 products across 8 categories, customer reviews, and an `orders` table. Sample images for image search are in `resources/`.

### Tech stack

Python · LangChain · Groq (Qwen3-32B, Llama 4 Scout 17B) · SQLite · Streamlit

### Run it

Requires Python 3.10+ and a free [Groq API key](https://console.groq.com).

```bash
cd shopping_agent
pip install "langchain>=1.0" langchain-groq streamlit python-dotenv
echo "GROQ_API_KEY=your_groq_api_key_here" > .env
python setup_db.py        # creates or resets store.db
streamlit run app.py
```

Then try *"I want organic honey with 4.5+ rating and less than $20"*, or upload `resources/honey.png` under **Shop by Image** in the sidebar.

---

## 2. 📞 Telecom RAG Chatbot 🐳

A customer-care chatbot that answers questions about connectivity, billing, SIM issues and roaming, using retrieval-augmented generation (RAG) over three knowledge sources.

### How it works

1. **Ingestion:** each source is stored in its own ChromaDB collection:
   - **FAQ** (`faq.csv`): one document per question-and-answer pair
   - **Resolved support tickets** (`tickets.db`, SQLite): issue, description and resolution combined into one document
   - **Telecom user guide** (`telecom_guide.pdf`): split into 600-character chunks with 100-character overlap
2. **Embeddings:** `sentence-transformers/all-MiniLM-L6-v2`, run locally through Hugging Face.
3. **Retrieval:** a merged retriever returns the top 3 matches from each collection.
4. **Generation:** the retrieved context, labelled by source, goes to **Qwen on Groq** (temperature 0) with instructions to answer only from that context and to direct the customer to support when unsure.
5. **Interface:** streaming answers in a Streamlit chat app, plus a command-line version (`main.py`).

### Tech stack

Python · LangChain · ChromaDB · Sentence Transformers · Hugging Face · Groq (Qwen) · SQLite · Streamlit · Docker · uv

### 🐳 Docker implementation

The chatbot is containerised, so it runs the same way on any machine with Docker, with no Python setup needed.

- **`Dockerfile`**: builds an image with Python 3.11, all dependencies (pinned in `uv.lock`), the app code and the source data. It runs as a non-root user, exposes port `8501` and includes a health check.
- **`docker-entrypoint.sh`**: on first start, builds the ChromaDB vector store from the FAQ, the ticket database and the PDF guide, then launches the Streamlit app. Set `FORCE_REINGEST=1` to rebuild it.
- **Persistent volumes**: keep the vector store and the downloaded embedding model between runs, so later starts are fast.
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

To run without Docker, and for the full architecture and troubleshooting guide, see [`Telecom_chatbot/README.md`](Telecom_chatbot/README.md).

---

## Limitations and next steps

**Shopping agent**
- Order confirmation is enforced by the prompt. A production version would enforce it in code with a pending-order step and an idempotency key.
- Search is keyword-based. Adding embeddings would let a query like "sweetener" find honey.
- Ratings are fetched one product at a time. The batch lookup already in `reviews_api.py` would reduce latency and token use.

**Telecom chatbot**
- Each question is answered on its own, with no conversation memory for follow-ups.
- It always retrieves 3 results per source. A similarity threshold or reranker would drop irrelevant ones.
- There is no automated evaluation yet, such as a RAGAS test set.

---

## Repository structure

```
Agentic_AI_Projects/
├── shopping_agent/
│   ├── shopping_agent.py      # agent, tools and system prompt
│   ├── app.py                 # Streamlit UI: chat and image upload
│   ├── reviews_api.py         # rating lookups
│   ├── setup_db.py            # creates store.db with products and reviews
│   └── resources/             # sample product images
└── Telecom_chatbot/
    ├── ingest_faq.py          # FAQ CSV → Chroma
    ├── ingest_tickets.py      # SQLite tickets → Chroma
    ├── ingest_pdf.py          # PDF guide → chunks → Chroma
    ├── retriever.py           # merged retriever over 3 collections
    ├── rag_chain.py           # prompt + Groq LLM chain
    ├── app.py                 # Streamlit UI
    ├── main.py                # command-line chat
    ├── Dockerfile
    ├── docker-entrypoint.sh
    └── data/                  # faq.csv, tickets.db, telecom_guide.pdf
```

---

Both projects were developed while following the **Codebasics Agentic AI Crash Course**.
