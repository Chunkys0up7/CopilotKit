# Architecture

## High-level diagram

```
┌────────────────────────────────────────────────────────────┐
│  Browser                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Next.js page                                        │  │
│  │  ┌────────────────────┐    ┌──────────────────────┐  │  │
│  │  │ <CopilotProvider>  │───▶│ <CopilotSidebar />   │  │  │
│  │  │  - useCopilotAction│    │ <CopilotChat />      │  │  │
│  │  │  - useCopilotReadable                          │  │  │
│  │  └─────────┬──────────┘    └──────────────────────┘  │  │
│  └────────────┼─────────────────────────────────────────┘  │
│               │ HTTP/SSE (AG-UI protocol)                  │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  /api/copilotkit  (Next.js route)                    │  │
│  │  - CopilotRuntime                                    │  │
│  │  - service adapter ──► LLM call (OpenAI/Anthropic)   │  │
│  │  - remoteEndpoints ──► Python backend (actions)      │  │
│  └────────────┬─────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────┘
                │ HTTP
                ▼
┌────────────────────────────────────────────────────────────┐
│  FastAPI (Python)                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  /copilotkit_remote   (CopilotKitRemoteEndpoint)     │  │
│  │  - hosts server-side actions                         │  │
│  │  - (future) hosts LangGraph CoAgents                 │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│       ┌──────────────────┐                                 │
│       │  ActionRegistry  │  ← echo, get_weather, …         │
│       └──────────────────┘                                 │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  LLMProvider ABC  ← used by evals + future CoAgents  │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  MockProvider      ← default, deterministic          │  │
│  │  OpenAIProvider    ← needs OPENAI_API_KEY            │  │
│  │  AnthropicProvider ← needs ANTHROPIC_API_KEY         │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## Where the LLM call happens

| Path | Where the LLM is called |
|---|---|
| Standard chat (no `agent` prop) | **Next route**, via the service adapter selected by `LLM_PROVIDER`. |
| CoAgent mode (`agent="…"` prop set) | **Python backend**, inside the LangGraph agent (uses `LLMProvider`). |
| Evals (`pytest`, `python -m evals.runner`) | **Python**, via the same `LLMProvider`. |

This kickstarter ships **standard chat only**. The Python `LLMProvider` is wired for evals today and ready for a real CoAgent tomorrow — drop a compiled LangGraph into `app/agents/`, pass it as `agents=[...]` in `app/runtime.py`, set `agent="<name>"` on the React provider, and the LLM call moves to Python.

## Request flow (standard chat message)

1. User types a message in `<CopilotSidebar />`.
2. `@copilotkit/react-core` POSTs to `/api/copilotkit` with the conversation, registered client actions, and any `useCopilotReadable` context.
3. The Next route's `CopilotRuntime` calls the Python backend at `/copilotkit_remote` to fetch its action schemas and merges them with client actions.
4. The selected service adapter (`OpenAIAdapter`, `AnthropicAdapter`, or `ExperimentalEmptyAdapter`) calls the LLM with the merged tool set.
5. If the LLM calls a *server* action, `CopilotRuntime` proxies the call to the Python backend; `ActionRegistry.dispatch()` runs the handler.
6. If the LLM calls a *client* action, the runtime relays the call to the browser; `useCopilotAction`'s handler runs there.
7. Tokens stream back to the chat UI as SSE.

## Design principles

| Principle | What it means here |
|---|---|
| **Single-purpose classes** | One file = one class = one job. `LLMProvider` only generates; `ActionRegistry` only dispatches. |
| **Boundary-only validation** | Pydantic at the HTTP edge; trust internal calls. |
| **Provider-agnostic, both sides** | One `LLM_PROVIDER` env var maps to a Next-side adapter and a Python-side `LLMProvider`. Same `.env` drives both. |
| **Spec-first** | Every class has a spec in `docs/classes/`. PRs that change a class update its spec. |
| **Tests are part of the package** | `pytest` runs unit + eval scenarios in CI. |
| **No premature abstraction** | New providers/actions are 1-file additions, not framework changes. |

## What's *intentionally* not here yet

- A real LangGraph CoAgent (the `DemoAgent` is shaped for it but doesn't run as a CoAgent yet).
- Persistent conversation storage (in-memory only — wire Redis or Postgres when you need it).
- Auth (the runtime is unauthenticated by default — gate `/api/copilotkit` with your auth provider).
- Multi-tenant isolation (single-process scaffold).
- Production observability (structured logging is in; OpenTelemetry hooks are placeholders).

Each of these is one file and a few lines away. See the `docs/extending/` notes when you reach for one.

## Versioning

- Backend: semver in `backend/pyproject.toml`.
- Frontend: semver in `frontend/package.json`.
- This kickstarter pins **CopilotKit ^1.10** and tracks the AG-UI protocol contract. Bumping CopilotKit is a coordinated FE+BE change.
