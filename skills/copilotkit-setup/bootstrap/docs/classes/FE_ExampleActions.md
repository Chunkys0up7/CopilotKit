# `ExampleActions` (frontend)

**File:** [`frontend/components/actions/ExampleActions.tsx`](../../frontend/components/actions/ExampleActions.tsx)

## Purpose
Register two example client-side actions (`addTodo`, `removeTodo`) the LLM may invoke, and demonstrate the `useCopilotAction` pattern.

## Public surface
- Props: `{ todos, addTodo, removeTodo }`.
- Returns `null` — pure registration component (no DOM output).

## Hooks used
- `useCopilotAction({ name, description, parameters, handler })`.

## Pattern
- Keep handlers thin: validate-then-delegate to the actual mutator passed in via props.
- Each handler returns `{ ok, message }` so the LLM can confirm/explain to the user.

## Collaborators
- `@copilotkit/react-core`'s `useCopilotAction`.
- `<HomePage />` (consumer); `useTodos` (provides mutators).

## Complexity
- Each registration is O(1).

## Test coverage
- Behavior is exercised end-to-end via the dev flow.
- Future: vitest tests using `<CopilotKit>` provider mocks.
