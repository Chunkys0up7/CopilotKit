# `useTodos`

**File:** [`frontend/lib/readables.ts`](../../frontend/lib/readables.ts)

## Purpose
Local in-memory todo store. Trivial state hook used by the demo page; isolated from CopilotKit so swapping for a real persistent store (Zustand, Redux, server actions) is one drop-in change.

## Public surface

```ts
function useTodos(initial?: Todo[]): {
  todos: Todo[];
  addTodo: (text: string) => void;
  removeTodo: (id: string) => void;
  toggleTodo: (id: string) => void;
};
```

## Collaborators
- `<HomePage />`, `<ChatPanel />`, `<ExampleActions />`.

## Complexity
- All mutators: O(N) — array filter/map (fine for a demo; swap for a Map if you need O(1)).

## Test coverage
- `frontend/__tests__/readables.test.ts` covers add/remove/toggle.

## Replacing
Swap for any state library. Keep the `Todo` interface and the same 3 mutators and consumers won't notice.
