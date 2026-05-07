# `RuntimeRoute` (Next.js API)

**File:** [`frontend/app/api/copilotkit/route.ts`](../../frontend/app/api/copilotkit/route.ts)

## Purpose
Bridge the browser's `/api/copilotkit` POST to the Python FastAPI backend's `/copilotkit_remote`. Handles streaming and CORS-by-design (same origin).

## Public surface
- `POST` handler: `(req: NextRequest) => Response`.

## Why `ExperimentalEmptyAdapter`?
The actual LLM call is made by the Python backend through its `LLMProvider`. The Next route is a **pure relay** — no model logic in JS. The empty adapter tells `@copilotkit/runtime` "don't try to call an LLM here; just forward to the remote endpoint."

## Configuration
- `NEXT_PUBLIC_BACKEND_URL` (default `http://localhost:8000`).

## Collaborators
- `@copilotkit/runtime` (`CopilotRuntime`, `copilotRuntimeNextJSAppRouterEndpoint`, `ExperimentalEmptyAdapter`).
- FastAPI service exposing `/copilotkit_remote` (built by `app.runtime.mount`).

## Complexity
- Per-request: O(streamed bytes). Streams SSE end-to-end.

## Test coverage
- Functional smoke via the local `npm run dev` flow + backend health check.
- (TODO: a vitest mocking the backend with MSW would round this out.)
