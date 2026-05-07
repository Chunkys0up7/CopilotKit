# `ExampleActions` (backend)

**File:** [`backend/app/actions/examples.py`](../../backend/app/actions/examples.py)

## Purpose
Two reference actions (`echo`, `get_weather`) demonstrating the canonical 3-step pattern: Pydantic params → async handler → `Action` wrapper. Copy this file to scaffold new actions.

## Exported

| Symbol | Type | Description |
|---|---|---|
| `EchoParams` | `BaseModel` | `{ text: str }` |
| `echo_action` | `Action[EchoParams]` | Echoes text back. |
| `WeatherParams` | `BaseModel` | `{ city: str, units: "celsius"\|"fahrenheit" = "celsius" }` |
| `weather_action` | `Action[WeatherParams]` | **Stub** — replace with a real provider. |

## Collaborators
- **Imported by:** `app.actions.registry.default_registry`.

## Complexity
- O(1) for both handlers (no I/O).

## Test coverage
- `tests/test_actions.py::test_echo_action_runs`
- Eval scenarios: `evals/scenarios/02_tool_call.yaml` covers `get_weather` dispatch shape.

## Replacing the weather stub
Wire any HTTP weather API in `_weather`. Keep the function signature `(WeatherParams) -> dict` so the `Action` wrapper is unchanged.
