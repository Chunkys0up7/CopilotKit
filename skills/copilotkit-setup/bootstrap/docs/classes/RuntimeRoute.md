# `RuntimeRoute` (Next.js API)

**File:** [`frontend/app/api/copilotkit/route.ts`](../../frontend/app/api/copilotkit/route.ts)

## Purpose
Bridge the browser's `/api/copilotkit` POST to:
1. **The LLM**, via a service adapter selected by the `LLM_PROVIDER` env var.
2. **The Python backend** at `/copilotkit_remote`, for server-side actions and (future) CoAgents.

Handles streaming and CORS-by-design (same origin).

## Public surface
- `POST` handler: `(req: NextRequest) => Response`.

## Service adapter selection

| `LLM_PROVIDER` | Adapter | Required env | Behavior |
|---|---|---|---|
| `openai` | `OpenAIAdapter` | `OPENAI_API_KEY` | Real chat. |
| `anthropic` | `AnthropicAdapter` | `ANTHROPIC_API_KEY` | Real chat. |
| `mock` *(default)* | `ExperimentalEmptyAdapter` | none | Page loads; chat does not produce a model response. Server-side actions still work. |
| missing key | `ExperimentalEmptyAdapter` (with `console.warn`) | — | Defensive fallback so the page never crashes from a typo'd env. |

## Configuration sources
- The repo-root `.env` is loaded by `next.config.js` via `dotenv` so the same file drives both this route and the Python backend.
- `NEXT_PUBLIC_BACKEND_URL` (defaults to `http://localhost:8000`) is the Python backend URL used by `remoteEndpoints`.

## Collaborators
- `@copilotkit/runtime` (`CopilotRuntime`, `OpenAIAdapter`, `AnthropicAdapter`, `ExperimentalEmptyAdapter`, `copilotRuntimeNextJSAppRouterEndpoint`).
- FastAPI service exposing `/copilotkit_remote` (built by `app.runtime.mount`).

## Complexity
- Per-request: O(streamed bytes). Streams SSE end-to-end.
- Adapter is rebuilt on every request — cheap and lets env changes take effect on hot reload.

## Test coverage
- Smoke via `npm run dev` + manual chat.
- (TODO: Vitest + MSW mocking the backend remote endpoint would round this out.)

## Adding a new adapter
1. Import it from `@copilotkit/runtime` (e.g. `GroqAdapter`, `GoogleGenerativeAIAdapter`).
2. Add a branch in `buildServiceAdapter()` keyed by your new `LLM_PROVIDER` value.
3. Update `app/config.py:ProviderName` (Python side) so the type union matches.
4. Document the key requirements in `.env.example` and `docs/llm-providers.md`.
