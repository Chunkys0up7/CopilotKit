# `MockProvider`

**File:** [`backend/app/llm/mock_provider.py`](../../backend/app/llm/mock_provider.py)

## Purpose
Deterministic, network-free `LLMProvider` for tests, evals, and offline dev.

## Public surface
Inherits from `LLMProvider`. Adds no new public methods.

## Behavior
- `generate` / `stream` return `[mock] <last user message>`.
- A user message starting with `/tool <name> <json-args>` produces a single matching `ToolCall` instead — useful for exercising the action pipeline without a real LLM.
- `stream` yields one word per chunk plus a terminal `done=True`.

## Collaborators
- **Imported by:** `app.llm` (`get_provider` factory), `tests/test_llm_providers.py`, eval scenarios with `provider: mock`.

## Complexity
- `generate`: O(message length).
- `stream`: O(words in reply); cooperatively yields between words.

## Test coverage
- `tests/test_llm_providers.py::test_mock_generate_*`
- `tests/test_llm_providers.py::test_mock_stream_yields_words_then_done`
- All YAML scenarios under `evals/scenarios/`.

## Why it's in the same package as real providers
So eval/test code paths match production wiring exactly — `get_provider()` with `LLM_PROVIDER=mock` returns this without any conditional imports or test-only paths in the runtime.
