# `Action`

**File:** [`backend/app/actions/base.py`](../../backend/app/actions/base.py)

## Purpose
Wrap one async Python callable as a typed, schema-emitting tool the LLM can invoke.

## Public surface

| Member | Signature |
|---|---|
| `name` | `str` — symbol the LLM uses. |
| `description` | `str` — sentence describing what it does. |
| `parameters` | `type[BaseModel]` — Pydantic model defining args. |
| `handler` | `Callable[[BaseModel], Awaitable[Any]]` |
| `openai_schema()` | `-> dict` |
| `anthropic_schema()` | `-> dict` |
| `copilotkit_schema()` | `-> dict` |
| `call(raw_args)` | `-> ActionResult` (validates, runs, never raises) |

`ActionResult` is a frozen dataclass with `ok`, `value`, `error`, `to_message()`.

## Why a wrapper instead of a bare function?
So the same object emits the OpenAI / Anthropic / CopilotKit JSON schemas without an extra adapter layer. Adding a new vendor schema is a new method on this class, not a new module.

## Collaborators
- **Imports:** `pydantic.BaseModel`, `pydantic.ValidationError`.
- **Imported by:** `app.actions.{registry,examples}`, `app.runtime`.

## Complexity
- `call`: O(args) for Pydantic validation + O(handler).
- Schema methods: O(params) — small, called once per request.

## Test coverage
- `tests/test_actions.py::test_echo_action_runs`
- `tests/test_actions.py::test_action_validates_arguments`
- `tests/test_actions.py::test_action_wraps_handler_exceptions`
- `tests/test_actions.py::test_*_schema_shape`
