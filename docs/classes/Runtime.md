# `Runtime` (FastAPI mount)

**File:** [`backend/app/runtime.py`](../../backend/app/runtime.py)

## Purpose
Build a `CopilotKitRemoteEndpoint` populated with the `ActionRegistry` and mount it onto a FastAPI app at `/copilotkit_remote`. This is the **only** module that imports the `copilotkit` SDK — the rest of the backend stays SDK-agnostic.

## What this endpoint exposes today
- **Server-side actions** (`echo`, `get_weather`, plus whatever you add).
- An empty `agents=[]` placeholder. When you build a real LangGraph CoAgent, instantiate it here and pass it in `agents=[...]`.

The LLM call for **standard chat** does **not** go through this endpoint — it happens in the Next route's service adapter. This endpoint is for actions and (later) CoAgents only.

## Public surface

| Function | Signature |
|---|---|
| `mount(app: FastAPI, *, registry: ActionRegistry \| None = None) -> None` | Attaches the endpoint to the app. |

## Internals
- `_action_to_copilotkit(action)` — wraps one `Action` in the SDK's expected dict (`name`, `description`, `parameters` list, `handler`).
- The handler delegates back to `Action.call()` so validation + error wrapping stay in one place.

## Collaborators
- **Imports:** `copilotkit.CopilotKitRemoteEndpoint`, `copilotkit.integrations.fastapi.add_fastapi_endpoint`, `app.actions`, `app.llm`.
- **Imported by:** `app.main`.

## Complexity
- `mount`: O(N actions). Called once at startup.

## Failure modes
- Misconfigured `LLM_PROVIDER` → raised by `get_provider()` before mount.
- SDK import error → only triggers at app startup, not at module import elsewhere (it's lazy here).

## Test coverage
- `tests/test_health.py` (integration; skipped when SDK absent).
