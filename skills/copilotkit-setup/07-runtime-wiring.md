# 07 — Runtime wiring (Next + FastAPI)

Two files do all the SDK plumbing. Everything else is SDK-agnostic.

---

## File 1 — Next.js `app/api/copilotkit/route.ts`

The job: receive POSTs from the browser; route them to (a) the LLM service adapter and (b) the Python remote endpoint; stream the result back.

```ts
import {
  AnthropicAdapter,
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  OpenAIAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
  type CopilotServiceAdapter,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

const runtime = new CopilotRuntime({
  remoteEndpoints: [{ url: `${BACKEND_URL}/copilotkit_remote` }],
});

function buildServiceAdapter(): CopilotServiceAdapter {
  const provider = (process.env.LLM_PROVIDER || "mock").toLowerCase();
  const model = process.env.LLM_MODEL;

  if (provider === "openai" && process.env.OPENAI_API_KEY) {
    return new OpenAIAdapter({ model: model || "gpt-4o-mini" });
  }
  if (provider === "anthropic" && process.env.ANTHROPIC_API_KEY) {
    return new AnthropicAdapter({ model: model || "claude-sonnet-4-6" });
  }
  // mock or missing key — page loads, chat is a no-op.
  return new ExperimentalEmptyAdapter();
}

export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter: buildServiceAdapter(),
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
```

### Why rebuild the adapter per request?

- Hot-reloading `.env` changes during dev without restarting Next.
- Negligible cost (constructor only).
- Lets you add per-request auth headers later (read from `req`, pass to the adapter).

### Why `EmptyAdapter` for mock?

CopilotKit doesn't ship a "MockServiceAdapter". `ExperimentalEmptyAdapter` lets the page load without an LLM call — chat won't return a response, but server-side actions still work and you can exercise the rest of the app.

For deterministic chat without API keys, write a custom `MockServiceAdapter` (see [`05-llm-provider-pattern.md`](./05-llm-provider-pattern.md#custom-service-adapter-advanced)).

---

## File 2 — FastAPI `app/runtime.py`

Two endpoints, both mounted here:

1. **`/copilotkit_remote`** — `CopilotKitRemoteEndpoint` carrying our `ActionRegistry`. Server-side actions live here. `agents=[]` because the SDK's `LangGraphAGUIAgent` bridge is broken in 0.1.88 (see `09-debugging-runbook.md`).
2. **`/agent/default`** — direct AG-UI LangGraph endpoint via `ag_ui_langgraph.add_langgraph_fastapi_endpoint`. The chat agent lives here.

```python
def mount(app: FastAPI, *, registry: ActionRegistry | None = None) -> None:
    registry = registry or default_registry()
    provider = get_provider()  # used by evals + the agent's chat_node
    log.info("copilotkit.runtime.mount",
             provider=provider.name, model=provider.model, actions=registry.names())

    # Lazy imports keep the SDKs truly optional for unit tests.
    from copilotkit import CopilotKitRemoteEndpoint
    from copilotkit.integrations.fastapi import add_fastapi_endpoint
    from ag_ui_langgraph import LangGraphAgent, add_langgraph_fastapi_endpoint

    # 1. Actions endpoint
    sdk_actions = [
        _action_to_copilotkit(a)
        for a in (registry.get(n) for n in registry.names())
        if a
    ]
    endpoint = CopilotKitRemoteEndpoint(actions=sdk_actions, agents=[])
    add_fastapi_endpoint(app, endpoint, "/copilotkit_remote")

    # 2. Agent endpoint (bypasses broken copilotkit.LangGraphAGUIAgent)
    agent = LangGraphAgent(
        name="default",
        graph=build_default_graph(),  # your CompiledStateGraph
        description="...",
    )
    add_langgraph_fastapi_endpoint(app, agent, "/agent/default")


def _action_to_copilotkit(action: Action):
    """Wrap our Action in copilotkit.Action (typed instances ≥ 0.1.88)."""
    from copilotkit import Action as CKAction
    schema = action.copilotkit_schema()
    async def _handler(**kwargs):
        result = await action.call(kwargs)
        return result.value if result.ok else {"error": result.error}
    return CKAction(
        name=schema["name"],
        description=schema["description"],
        parameters=schema.get("parameters", []),
        handler=_handler,
    )
```

Mounted from `app/main.py`:

```python
runtime.mount(app)  # last line of main.py
```

### Why two endpoints?

The `copilotkit` Python SDK 0.1.88 has two unfixed bugs in `LangGraphAGUIAgent`:
1. `dict_repr()` calls `super().dict_repr()` on a parent without that method → `/info` 500.
2. `execute()` is required by the SDK's flow but isn't implemented → `/agent/<name>` 500.

Until those are fixed upstream, mounting `ag_ui_langgraph` directly is the cleanest path — you get a working agent endpoint, you keep a working actions endpoint, and the React side bridges them via `runtimeUrl` + `agents__unsafe_dev_only`.

When the SDK is fixed, switch to the canonical pattern by passing `agents=[LangGraphAGUIAgent(...)]` to `CopilotKitRemoteEndpoint` and dropping the `ag_ui_langgraph` mount.

### Why lazy-import the SDK?

So `pytest tests/` works without `copilotkit` installed. Tests for `LLMProvider`, `Action`, `ActionRegistry` shouldn't pull in the SDK — that's reserved for `tests/test_health.py` (marked `integration`).

---

## The wiring on the React side

Two files cooperate:

### `frontend/components/CopilotProvider.tsx`

```tsx
"use client";
import { CopilotKit } from "@copilotkit/react-core";
import { HttpAgent } from "@ag-ui/client";
import { useMemo, type ReactNode } from "react";

const RUNTIME_URL = "/api/copilotkit";
const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export function CopilotProvider({ children }: { children: ReactNode }) {
  const agents = useMemo(() => ({
    default: new HttpAgent({ url: `${BACKEND_URL}/agent/default` }),
  }), []);

  return (
    <CopilotKit runtimeUrl={RUNTIME_URL} agents__unsafe_dev_only={agents}>
      {children}
    </CopilotKit>
  );
}
```

The `HttpAgent` registered via `agents__unsafe_dev_only` is what makes `useAgent("default")` resolve. It points at the Python `/agent/default` endpoint — chat goes there, actions still go through `runtimeUrl`.

**`useMemo([])`** is required: re-creating `HttpAgent` every render resets connection state.

### `frontend/app/layout.tsx`

```tsx
import "@copilotkit/react-ui/styles.css";
import "./globals.css";
import { CopilotProvider } from "@/components/CopilotProvider";

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <CopilotProvider>{children}</CopilotProvider>
      </body>
    </html>
  );
}
```

The stylesheet import is required — without it the chat UI has no styles.

---

## Loading the repo-root `.env` into Next

By default Next reads `frontend/.env.local`. We want **one `.env` for both processes**:

```js
// frontend/next.config.js
const path = require("node:path");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
```

Add `dotenv` to dependencies (not devDependencies — it's used at runtime).

---

## How the request flows end-to-end

```
1. User types "what's the weather in London"
2. <CopilotChat /> POSTs to /api/copilotkit with the conversation
3. Next route's CopilotRuntime fetches action schemas from
     http://localhost:8000/copilotkit_remote/agents/info
   (this returns the merged action set: client + server)
4. The selected service adapter calls the LLM with the merged tools
5. LLM emits tool_call: get_weather(city="London")
6. CopilotRuntime sees it's a server action → POSTs to
     http://localhost:8000/copilotkit_remote/agents/<id>/tool
7. Python: ActionRegistry.dispatch(ToolCall(name="get_weather", arguments={"city":"London"}))
8. Result {"city":"London","temp":18.5} flows back to the LLM
9. LLM emits final text: "It's 18.5°C in London."
10. Tokens stream as SSE to the browser
```

The kickstarter's two adapter files are the only places the SDK protocol matters.

---

## Common runtime config tweaks

### Allow larger payloads

```js
// next.config.js
experimental: {
  serverActions: { bodySizeLimit: "2mb" },
},
```

### Custom CORS for the FastAPI side

```python
# app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,  # from .env
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Per-request properties (for auth, multi-tenant context)

```tsx
<CopilotKit
  runtimeUrl="/api/copilotkit"
  properties={{ userId: session.user.id, role: session.user.role }}
>
```

These are passed through to action handlers via the request context — see CopilotKit docs.

---

## Sanity tests after wiring

1. **Backend health:** `curl http://localhost:8000/health` → `{"status":"ok"}`.
2. **Frontend page:** `curl -I http://localhost:3000` → `HTTP/1.1 200`.
3. **Runtime endpoint exists:** `curl -X POST http://localhost:3000/api/copilotkit -d '{}' -H 'Content-Type: application/json'` → 400 with a JSON-RPC error (means the route is wired; just rejecting an invalid body).
4. **Backend remote endpoint exists:** `curl http://localhost:8000/copilotkit_remote/agents/info` → JSON with action names.

If all four pass, the wiring is correct.
