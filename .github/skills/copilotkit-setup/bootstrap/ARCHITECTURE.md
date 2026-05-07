# Architecture

## High-level diagram

```
┌────────────────────────────────────────────────────────────┐
│  Browser                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Next.js page                                        │  │
│  │  ┌────────────────────┐                              │  │
│  │  │ <CopilotProvider>  │                              │  │
│  │  │  runtimeUrl=/api/copilotkit                       │  │
│  │  │  agents__unsafe_dev_only={ default: HttpAgent }   │  │
│  │  └────────┬─────────┬─┘                              │  │
│  └───────────┼─────────┼────────────────────────────────┘  │
└──────────────┼─────────┼───────────────────────────────────┘
   chat (AG-UI)│         │actions (HTTP)
               │         │
               ▼         ▼
┌────────────────────────────────────────────────────────────┐
│  FastAPI (Python)                                          │
│                                                            │
│  /agent/default          /copilotkit_remote                │
│  ag_ui_langgraph         CopilotKitRemoteEndpoint          │
│  endpoint                  - actions = [echo, weather…]    │
│    │                       - agents = []  (bypassed)       │
│    ▼                                                       │
│  CompiledStateGraph                                        │
│    chat_node ──► get_provider().generate(messages)         │
│                  │                                         │
│                  ▼                                         │
│       ┌──────────────────────┐                             │
│       │  LLMProvider (ABC)   │ ← LLM_PROVIDER env switch   │
│       ├──────────────────────┤                             │
│       │  MockProvider        │  default, no network        │
│       │  OpenAIProvider      │  needs OPENAI_API_KEY       │
│       │  AnthropicProvider   │  needs ANTHROPIC_API_KEY    │
│       └──────────────────────┘                             │
└────────────────────────────────────────────────────────────┘
```

## Where the LLM call happens

| Path | Where the LLM is called |
|---|---|
| Chat (this kickstarter) | **Python**, inside the `default` LangGraph CoAgent's `chat_node`. Uses `LLMProvider`. |
| Evals (`pytest`, `python -m evals.runner`) | **Python**, via the same `LLMProvider`. |
| Future custom agents | **Python**, drop a new `LangGraph` into `app/agents/`, mount via `add_langgraph_fastapi_endpoint`, register `HttpAgent` on the React side. |

The Next route's service adapter (`OpenAIAdapter` / `AnthropicAdapter` / `ExperimentalEmptyAdapter`) is configured but **not on the chat path** in this setup — chat is fully Python-side. The service adapter remains for non-agent flows that CopilotKit's runtime might use (suggestions, etc.).

## Request flow (chat message)

1. User types in `<CopilotSidebar />`.
2. `@copilotkit/react-core` looks up `useAgent("default")` → finds the `HttpAgent` registered via `agents__unsafe_dev_only`.
3. The `HttpAgent` POSTs the AG-UI request body to `<BACKEND>/agent/default`.
4. `ag_ui_langgraph` runs the compiled graph: `START → chat_node → END`.
5. `chat_node` calls `get_provider().generate(messages)` — this is the LLM call.
6. The provider's response streams back as SSE events to the browser.
7. If the LLM emitted a tool call for a server-side action, the React runtime relays it via `/api/copilotkit` → `/copilotkit_remote`, dispatched by `ActionRegistry`.
8. Client actions registered via `useCopilotAction` run in the browser the same way.

## Why two endpoints on the Python side?

The `copilotkit` Python SDK 0.1.88 ships `LangGraphAGUIAgent`, intended to fold a LangGraph agent into the standard `/copilotkit_remote` flow. It's broken in two ways (see `docs/classes/Runtime.md` and the debugging runbook). Until that's fixed upstream:

- Actions go through `CopilotKitRemoteEndpoint` (working).
- Agents go through `ag_ui_langgraph.add_langgraph_fastapi_endpoint` directly (working).

The React side bridges them: `runtimeUrl` for actions, `agents__unsafe_dev_only` for agents.

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
