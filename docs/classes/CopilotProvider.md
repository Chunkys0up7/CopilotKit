# `CopilotProvider`

**File:** [`frontend/components/CopilotProvider.tsx`](../../frontend/components/CopilotProvider.tsx)

## Purpose
Wrap the app in a single `<CopilotKit />` context with the runtime URL. The one place to inject auth headers, change the backend URL, or opt into CoAgent mode.

## Public surface
- `<CopilotProvider>{children}</CopilotProvider>` — React component.

## Constants
- `RUNTIME_URL = "/api/copilotkit"` — points at the Next route handler.

## Why no `agent` prop?
Setting `agent="<name>"` puts CopilotKit into **CoAgent mode**: every chat is routed through a named agent in the backend's `/info`. We don't ship a real LangGraph CoAgent in v0, so the prop is omitted and chat goes through the standard service-adapter path (LLM call in the Next route).

When you build a real CoAgent:
1. Create / register a `LangGraphAgent` in `app/runtime.py:mount`.
2. Add `agent="<name>"` to the `<CopilotKit />` invocation here.
3. The LLM call moves from the Next service adapter to your Python agent.

## Collaborators
- `@copilotkit/react-core`'s `<CopilotKit />`.
- `<RootLayout />` consumes it.

## Complexity
- Renders once per app mount.

## Adding auth
Pass `headers` and/or `properties` to `<CopilotKit />`. Keep this isolation — no other component should know about auth wiring.

## Test coverage
- Indirect via the home page render.
