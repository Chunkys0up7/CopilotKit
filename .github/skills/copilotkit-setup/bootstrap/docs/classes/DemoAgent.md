# `DemoAgent`

**File:** [`backend/app/agents/demo_agent.py`](../../backend/app/agents/demo_agent.py)

## Purpose
A minimal "agent" — one LLM call wrapped to expose state snapshots — shaped to be a drop-in for a real LangGraph `StateGraph` later.

## Public surface

| Symbol | Signature | Description |
|---|---|---|
| `AgentState` | `dataclass(status, messages, last_output)` | Mirrored to the UI via `useCoAgentStateRender`. |
| `DemoAgent.run` | `async (user_message: str) -> AsyncIterator[AgentState]` | Yields `thinking` then `done`. |
| `build_demo_agent(provider) -> DemoAgent` | factory | Used by `app.runtime.mount`. |

## Why this shape?
LangGraph's streaming API also yields state snapshots over time — keeping that shape now means swapping in a real graph is a one-file change. The frontend's `useCoAgentStateRender` doesn't need to know the difference.

## Collaborators
- **Imports:** `LLMProvider`, `LLMMessage` (from `app.llm`).
- **Imported by:** `app.runtime`.

## Complexity
- `run`: O(2) state snapshots × O(LLM call).

## Test coverage
- Indirect: any eval scenario that hits the runtime end-to-end.
- (TODO: direct unit test once a streaming counterpart of `MockProvider.generate` is exposed at the agent boundary.)

## Upgrading to real LangGraph
1. Replace `_run_step` with a `StateGraph(...).compile()`.
2. Stream snapshots from `graph.astream(state)` instead of yielding manually.
3. Update `frontend/components/CopilotProvider.tsx`'s `agent` prop if you rename it.
