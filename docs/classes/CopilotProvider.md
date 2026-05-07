# `CopilotProvider`

**File:** [`frontend/components/CopilotProvider.tsx`](../../frontend/components/CopilotProvider.tsx)

## Purpose
Wrap the app in a single `<CopilotKit>` context that wires:
1. **Actions runtime** at `/api/copilotkit` (Next route → Python backend).
2. **A default `HttpAgent`** registered via `agents__unsafe_dev_only`, pointing at the Python backend's `/agent/default` AG-UI endpoint.

## Public surface
- `<CopilotProvider>{children}</CopilotProvider>` — React component.

## Constants
- `RUNTIME_URL = "/api/copilotkit"` — the Next route handler.
- `BACKEND_URL` — read from `NEXT_PUBLIC_BACKEND_URL` env, defaults to `http://localhost:8000`.

## Why `agents__unsafe_dev_only` instead of letting the runtime sync agents?

CopilotKit 1.57+ requires at least one agent registered (the standard chat surface internally calls `useAgent("default")`). The expected path is for the Python backend to advertise agents via `/info`, but the copilotkit Python SDK 0.1.88's `LangGraphAGUIAgent` bridge is broken (see `docs/classes/Runtime.md`).

`agents__unsafe_dev_only` is CopilotKit's escape hatch: a `Record<string, AbstractAgent>` that's merged with the runtime sync result. We register a `default` `HttpAgent` pointing at our Python `/agent/default` endpoint (mounted via `ag_ui_langgraph.add_langgraph_fastapi_endpoint`). This satisfies the lookup AND wires chat to the working endpoint — the broken SDK bridge stays bypassed.

The "unsafe_dev_only" naming is CopilotKit's nudge that a real production setup should use the runtime's `/info` endpoint. We do too — once upstream is fixed.

## Why `useMemo` for the `agents` object?

Re-creating `HttpAgent` on every render would reset its connection state (and re-mount tool subscriptions). `useMemo([])` ensures one instance per component lifetime.

## Collaborators
- `@copilotkit/react-core`'s `<CopilotKit />`.
- `@ag-ui/client`'s `HttpAgent`.
- `<RootLayout />` consumes it.

## Complexity
- Renders once per app mount.

## Adding auth
Pass `headers` and/or `properties` to `<CopilotKit />`. For the agent endpoint, pass headers to `HttpAgent`'s constructor:

```tsx
new HttpAgent({
  url: `${BACKEND_URL}/agent/default`,
  headers: { Authorization: `Bearer ${token}` },
})
```

## Adding more agents

Add another entry to the memoized record:

```tsx
const agents = useMemo(() => ({
  default: new HttpAgent({ url: `${BACKEND_URL}/agent/default` }),
  research: new HttpAgent({ url: `${BACKEND_URL}/agent/research` }),
}), []);
```

…and mount the matching `add_langgraph_fastapi_endpoint(app, ..., "/agent/research")` on the Python side. The `<CopilotChat agentId="research">` prop selects which agent the chat uses.

## Test coverage
- Indirect via the home page render.
