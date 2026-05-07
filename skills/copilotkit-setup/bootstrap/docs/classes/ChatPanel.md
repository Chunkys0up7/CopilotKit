# `ChatPanel`

**File:** [`frontend/components/ChatPanel.tsx`](../../frontend/components/ChatPanel.tsx)

## Purpose
Show the user their todo list **and** expose that same list to the LLM via `useCopilotReadable` so the assistant always has fresh context.

## Public surface
- Props: `{ todos: Todo[] }`.
- Exports the `Todo` interface for re-use across the codebase.

## Hooks used
- `useCopilotReadable({ description, value })` — the LLM sees `description` (a sentence) plus a JSON-serialized `value` on every turn.

## Collaborators
- `@copilotkit/react-core`'s `useCopilotReadable`.
- Consumed by `<HomePage />`.

## Complexity
- Render: O(todos).
- Readable serialization is handled by CopilotKit; cost scales with todo size.

## Test coverage
- Indirect — covered by `useTodos` tests + e2e dev flow.
