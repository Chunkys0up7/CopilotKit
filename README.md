# CopilotKit Kickstarter

A **production-ready scaffold** built on top of [CopilotKit](https://www.copilotkit.ai/) — the open-source framework for in-app AI copilots, generative UI, and CoAgents.

This repository is a *kickstarter*: it gives you a clean, extensively documented starting point with all the wiring done — LLM provider abstraction, action registry, frontend hooks, generative UI, and a native testing/eval framework.

> **Source of truth.** This README, [`ARCHITECTURE.md`](ARCHITECTURE.md), and [`docs/`](docs/) are kept in sync with the code on every change. If a class exists, it has a spec doc. If a capability ships, it's listed here.

---

## What you get out of the box

| Layer | Tech | Purpose |
|---|---|---|
| **Frontend** | Next.js 14 (App Router) + React 18 + TypeScript | Hosts the chat UI and registers client-side actions/readables |
| **CopilotKit UI** | `@copilotkit/react-core`, `@copilotkit/react-ui` | Sidebar, chat, popup, textarea — all theme-able |
| **Runtime route** | `@copilotkit/runtime` (Node, in `app/api/copilotkit/route.ts`) | Hosts the LLM service adapter (OpenAI/Anthropic/Empty) **and** forwards actions to the Python backend |
| **Backend** | FastAPI + `copilotkit` (PyPI) | Hosts server-side actions; ready for a LangGraph CoAgent drop-in |
| **LLM layer** | Symmetric: Next-side adapter + Python `LLMProvider` | One `LLM_PROVIDER` env var configures both. Used for chat (Next) and evals/CoAgents (Python). |
| **Evals** | Native pytest-based scenario runner | Declarative YAML scenarios; deterministic via the mock provider |

---

## Quickstart

**Prerequisites:** Python 3.11+, Node 20+, pnpm or npm.

```bash
# 1. Backend
cd backend
python -m venv .venv
. .venv/Scripts/activate          # PowerShell:  .venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp ../.env.example ../.env        # then edit keys (optional — mock works out of the box)
uvicorn app.main:app --reload --port 8000

# 2. Frontend (in a new terminal)
cd frontend
npm install
npm run dev                       # http://localhost:3000

# 3. Evals
cd backend
pytest evals/                     # or: python -m evals.runner
```

Open <http://localhost:3000>. The page loads and the sidebar opens with the **mock** provider. To get an actual model response, set:

```dotenv
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

…in your `.env` and restart `npm run dev`. (Anthropic works the same way: `LLM_PROVIDER=anthropic` + `ANTHROPIC_API_KEY`.)

---

## Repository layout

```
.
├── README.md                      <- you are here
├── ARCHITECTURE.md                <- system design, request flow, sequence diagrams
├── .env.example                   <- all env vars documented
├── docs/
│   ├── classes/                   <- one spec doc per class (see docs/classes/INDEX.md)
│   ├── ui-capabilities.md         <- every prebuilt UI component & its props
│   ├── actions-and-readables.md   <- how to register new actions / context
│   ├── llm-providers.md           <- how to wire a new provider
│   └── eval-framework.md          <- how scenarios run, how to add one
├── backend/
│   ├── requirements.txt           <- pinned Python deps
│   ├── pyproject.toml
│   ├── app/
│   │   ├── main.py                <- FastAPI entrypoint
│   │   ├── config.py              <- pydantic-settings
│   │   ├── runtime.py             <- CopilotKitRemoteEndpoint wiring
│   │   ├── llm/                   <- provider abstraction (base, mock, openai, anthropic)
│   │   ├── actions/               <- ActionRegistry + example actions
│   │   └── agents/                <- CoAgent definitions (LangGraph-ready)
│   ├── tests/                     <- pytest unit tests
│   └── evals/                     <- scenarios/ + runner.py + framework.py
├── frontend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── next.config.js
│   ├── app/                       <- Next.js App Router
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── api/copilotkit/route.ts  <- runtime endpoint
│   ├── components/
│   │   ├── CopilotProvider.tsx
│   │   ├── ChatPanel.tsx
│   │   └── actions/               <- example useCopilotAction registrations
│   └── lib/
│       └── readables.ts           <- example useCopilotReadable hooks
└── scripts/
    └── dev.ps1                    <- one-shot dev runner (Windows)
```

---

## Core concepts (1-minute primer)

- **Action** — A function the LLM can call from chat. Registered server-side via `ActionRegistry` or client-side via `useCopilotAction`. See [`docs/actions-and-readables.md`](docs/actions-and-readables.md).
- **Readable** — App state exposed to the LLM as context. Registered via `useCopilotReadable`. The LLM sees it; the user doesn't.
- **CoAgent** — A long-running agent (e.g. a LangGraph) whose state syncs to the UI in real time.
- **Generative UI** — The agent returns structured data; the frontend renders a React component for it.
- **Provider** — An adapter implementing the `LLMProvider` interface. Swap providers by changing one env var.

---

## Class index

Every class has a single responsibility and a dedicated spec doc. See [`docs/classes/INDEX.md`](docs/classes/INDEX.md) for the full map. Each spec includes:

- **Purpose** (one sentence)
- **Public surface** (methods + signatures)
- **Collaborators** (what it depends on / who depends on it)
- **Complexity** (Big-O for hot paths)
- **Test coverage** (which tests cover which methods)

---

## Status

This is the v0 scaffold. See [`CHANGELOG.md`](CHANGELOG.md) for what's done and what's next.

## License

MIT.
