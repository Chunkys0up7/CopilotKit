# `CopilotProvider`

**File:** [`frontend/components/CopilotProvider.tsx`](../../frontend/components/CopilotProvider.tsx)

## Purpose
Wrap the app in a single `<CopilotKit />` context with the runtime URL and agent name. The one place to inject auth headers, change the backend URL, or swap agents.

## Public surface
- `<CopilotProvider>{children}</CopilotProvider>` — React component.

## Constants
- `RUNTIME_URL = "/api/copilotkit"` — points at the Next route handler.
- `AGENT_NAME = "demo"` — must match `build_demo_agent().name` in the backend.

## Collaborators
- `@copilotkit/react-core`'s `<CopilotKit />`.
- `<RootLayout />` consumes it.

## Complexity
- Renders once per app mount.

## Adding auth
Pass `headers` and/or `properties` to `<CopilotKit />`. Keep this isolation — no other component should know about auth wiring.

## Test coverage
- Indirect via the home page render.
