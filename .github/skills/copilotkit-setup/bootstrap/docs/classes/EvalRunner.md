# `EvalRunner` & framework

**File:** [`backend/evals/framework.py`](../../backend/evals/framework.py)

## Purpose
Run declarative YAML scenarios through any `LLMProvider` and report pass/fail.

## Public surface

| Symbol | Signature / fields |
|---|---|
| `EvalCase` | `name, description, messages, expect, provider_override` |
| `EvalExpectation` | `tool_calls`, `content_contains`, `content_matches` |
| `EvalResult` | `case, passed, failures, response, status` |
| `EvalReport` | `results, total, passed, failed, render()` |
| `load_scenarios(directory)` | Loads every `*.yaml`. |
| `EvalRunner.run_one(case)` | `async -> EvalResult` |
| `EvalRunner.run_all(cases)` | `async -> EvalReport` |

## Scenario YAML

```yaml
name: weather_lookup
description: Asks for weather; expects a tool call.
provider: mock                   # optional
messages:
  - role: user
    content: "/tool get_weather {\"city\": \"London\"}"
expect:
  tool_calls:
    - name: get_weather
      arguments_contains:
        city: London
  content_contains: []           # optional
  content_matches: null          # optional regex
```

## Collaborators
- **Imports:** `app.config.Settings`, `app.llm` (`LLMProvider`, `get_provider`), `pyyaml`.
- **Imported by:** `evals/runner.py` (CLI), `evals/test_scenarios.py` (pytest), and any custom CI script.

## Complexity
- `run_one`: O(provider call) — usually 1 LLM round-trip per scenario.
- `run_all`: O(N) sequential by default. Parallelization is opt-in (TODO when N grows).

## Test coverage
- All YAML in `evals/scenarios/` runs via `pytest -m eval`.
- The framework is exercised by `evals/test_scenarios.py`.

## Adding a scenario
Drop a new YAML in `evals/scenarios/`. CI picks it up automatically.
