# `HomePage`

**File:** [`frontend/app/page.tsx`](../../frontend/app/page.tsx)

## Purpose
Demo surface that wires the chat sidebar, an example readable, and example client actions onto a single page.

## Public surface
Default-exported React component. Marked `"use client"` because Copilot hooks need browser context.

## What it shows
- `<CopilotSidebar />` from `@copilotkit/react-ui` with custom labels.
- `<ChatPanel />` (uses `useCopilotReadable` to expose the todo list to the LLM).
- `<ExampleActions />` (registers `addTodo` / `removeTodo` via `useCopilotAction`).

## Collaborators
- `useTodos()` — local state.
- `<CopilotSidebar />`, `<ChatPanel />`, `<ExampleActions />`.

## Complexity
- Negligible — pure layout.

## Test coverage
- Indirect: `useTodos` is unit-tested in `frontend/__tests__/readables.test.ts`.
