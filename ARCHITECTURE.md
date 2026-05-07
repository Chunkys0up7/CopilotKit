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
│  │  - @copilotkit/runtime                               │  │
│  │  - Forwards to Python backend                        │  │
│  └────────────┬─────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────┘
                │ HTTP
                ▼
┌────────────────────────────────────────────────────────────┐
│  FastAPI (Python)                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  /copilotkit_remote   (CopilotKitRemoteEndpoint)     │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│       ┌───────┴────────┐                                   │
│       ▼                ▼                                   │
│  ┌──────────┐   ┌──────────────┐                           │
│  │ Actions  │   │  CoAgents    │                           │
│  │ Registry │   │ (LangGraph)  │                           │
│  └────┬─────┘   └──────┬───────┘                           │
│       │                │                                   │
│       └────────┬───────┘                                   │
│                ▼                                           │
│       ┌───────────────────┐                                │
│       │  LLMProvider ABC  │  ← swap via env (LLM_PROVIDER) │
│       ├───────────────────┤                                │
│       │ MockProvider      │  ← default, deterministic      │
│       │ OpenAIProvider    │  ← needs OPENAI_API_KEY        │
│       │ AnthropicProvider │  ← needs ANTHROPIC_API_KEY     │
│       └───────────────────┘                                │
└────────────────────────────────────────────────────────────┘
```

## Request flow (chat message)

1. User types a message in `<CopilotSidebar />`.
2. `@copilotkit/react-core` POSTs to `/api/copilotkit` with the conversation, the registered client actions, and any `useCopilotReadable` context.
3. The Next.js route handler hands off to `@copilotkit/runtime`, which calls the Python backend over HTTP.
4. `CopilotKitRemoteEndpoint` resolves the action set (server actions + agents).
5. The configured `LLMProvider` is invoked; its streaming response (text + tool calls) is sent back as SSE.
6. If the LLM calls a server action, `ActionRegistry.dispatch()` runs the handler and returns the result; the LLM may iterate.
7. If the LLM calls a *client* action, the runtime relays the call to the browser; `useCopilotAction`'s handler runs there.
8. Tokens stream back to the chat UI.

## Design principles

| Principle | What it means here |
|---|---|
| **Single-purpose classes** | One file = one class = one job. `LLMProvider` only generates; `ActionRegistry` only dispatches. |
| **Boundary-only validation** | Pydantic at the HTTP edge; trust internal calls. |
| **Provider-agnostic** | Swap `LLM_PROVIDER=mock|openai|anthropic` and nothing else changes. |
| **Spec-first** | Every class has a spec in `docs/classes/`. PRs that change a class update its spec. |
| **Tests are part of the package** | `pytest` runs unit + eval scenarios in CI. |
| **No premature abstraction** | New providers/actions are 1-file additions, not framework changes. |

## What's *intentionally* not here yet

- Persistent conversation storage (in-memory only — wire Redis or Postgres when you need it).
- Auth (the runtime is unauthenticated by default — gate `/api/copilotkit` with your auth provider).
- Multi-tenant isolation (single-process scaffold).
- Production observability (structured logging is in; OpenTelemetry hooks are placeholders).

Each of these is one file and a few lines away. See the `docs/extending/` notes when you reach for one.

## Versioning

- Backend: semver in `backend/pyproject.toml`.
- Frontend: semver in `frontend/package.json`.
- This kickstarter pins **CopilotKit ^1.10** and tracks the AG-UI protocol contract. Bumping CopilotKit is a coordinated FE+BE change.
