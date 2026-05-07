# `ActionRegistry`

**File:** [`backend/app/actions/registry.py`](../../backend/app/actions/registry.py)

## Purpose
Hold `Action` objects keyed by name and dispatch incoming `ToolCall`s to the matching handler.

## Public surface

| Method | Signature | Notes |
|---|---|---|
| `__init__` | `(actions: Iterable[Action] = ())` | |
| `register` | `(action) -> None` | Raises `ValueError` on duplicate. |
| `__len__`, `__contains__` | container protocol | |
| `names` | `() -> list[str]` | sorted |
| `get` | `(name) -> Action \| None` | |
| `openai_schemas` / `anthropic_schemas` / `copilotkit_schemas` | `() -> list[dict]` | |
| `dispatch` | `async (ToolCall) -> ActionResult` | Returns `ok=False` on unknown action, never raises. |

`default_registry()` → returns one pre-populated with the example actions. Production code replaces this with its own factory.

## Collaborators
- **Imports:** `Action`, `ActionResult`, example actions, `ToolCall` (from `app.llm.base`).
- **Imported by:** `app.runtime`.

## Complexity
- `register` / `get` / `dispatch`: O(1) average — dict lookups.
- Schema emission: O(N actions × M params).

## Test coverage
- `tests/test_actions.py::test_default_registry_has_examples`
- `tests/test_actions.py::test_registry_rejects_duplicates`
- `tests/test_actions.py::test_registry_dispatch_unknown_action`
- `tests/test_actions.py::test_registry_dispatch_runs_handler`
