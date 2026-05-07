# `Runtime` (FastAPI mount)

**File:** [`backend/app/runtime.py`](../../backend/app/runtime.py)

## Purpose
Mount **two** endpoints on a FastAPI app:

1. **`/copilotkit_remote`** — `CopilotKitRemoteEndpoint` carrying our `ActionRegistry`. The Next.js runtime uses this to discover and invoke server-side actions.
2. **`/agent/default`** — direct AG-UI LangGraph endpoint (via `ag_ui_langgraph.add_langgraph_fastapi_endpoint`) hosting the default chat agent.

This module is the only place that touches the `copilotkit` and `ag_ui_langgraph` SDKs.

## Why two endpoints?

CopilotKit Python SDK 0.1.88 ships a `LangGraphAGUIAgent` class that's supposed to bridge LangGraph agents into the SDK's agent flow — but it's broken in two ways:

1. `dict_repr()` calls `super().dict_repr()` on a parent that doesn't define it → `/info` returns 500.
2. `execute()` is required by the SDK's `execute_agent` flow but isn't defined on the class → `/agent/<name>` returns 500.

Until that's fixed upstream, the cleanest path is to skip the SDK bridge for agents and expose the LangGraph endpoint directly via `ag_ui_langgraph.add_langgraph_fastapi_endpoint`. The React side then registers an `HttpAgent` pointing at it via `agents__unsafe_dev_only`.

The actions side still uses the (working) `CopilotKitRemoteEndpoint` flow.

## Public surface

| Function | Signature |
|---|---|
| `mount(app: FastAPI, *, registry: ActionRegistry \| None = None) -> None` | Attaches both endpoints. |

## Internals
- `_action_to_copilotkit(action)` — wraps an `Action` in `copilotkit.Action` (the SDK now wants typed instances, not dicts).
- The action handler delegates back to `Action.call()` so validation + error wrapping stay in one place.

## Collaborators
- **Imports:** `copilotkit.Action`, `copilotkit.CopilotKitRemoteEndpoint`, `copilotkit.integrations.fastapi.add_fastapi_endpoint`, `ag_ui_langgraph.LangGraphAgent`, `ag_ui_langgraph.add_langgraph_fastapi_endpoint`, `app.actions`, `app.agents.build_default_graph`, `app.llm.get_provider`.
- **Imported by:** `app.main`.

## Complexity
- `mount`: O(N actions). Called once at startup.

## Failure modes
- Misconfigured `LLM_PROVIDER` → raised by `get_provider()` before mount.
- SDK import errors → only at app startup, not at module import elsewhere (lazy import).

## Test coverage
- `tests/test_health.py` (integration). Checks the app boots with both endpoints mounted.

## Restoring the canonical SDK flow

If a future copilotkit release fixes `LangGraphAGUIAgent`, the migration path is:
1. Replace the second mount block with `agents=[LangGraphAGUIAgent(...)]` in the `CopilotKitRemoteEndpoint` ctor.
2. Remove the `HttpAgent` registration from the React provider; the runtime sync will pick the agent up from `/info` automatically.

Until then, **don't simplify** — the dual-mount setup is doing real work.
