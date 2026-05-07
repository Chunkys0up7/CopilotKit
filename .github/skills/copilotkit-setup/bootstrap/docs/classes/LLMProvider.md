# `LLMProvider` (ABC)

**File:** [`backend/app/llm/base.py`](../../backend/app/llm/base.py)

## Purpose
Define the contract every concrete LLM adapter satisfies so the rest of the backend never depends on a specific vendor SDK.

## Public surface

### DTOs

| Type | Fields |
|---|---|
| `LLMMessage` | `role`, `content`, `name?`, `tool_call_id?` |
| `ToolCall` | `id`, `name`, `arguments: dict[str, Any]` |
| `LLMResponse` | `content`, `tool_calls`, `finish_reason`, `raw` |
| `LLMChunk` | `text_delta`, `tool_call?`, `done` |

### Abstract methods

| Method | Signature |
|---|---|
| `from_settings` | `classmethod (Settings) -> Self` |
| `generate` | `async (messages, tools=None) -> LLMResponse` |
| `stream` | `async iterator (messages, tools=None) -> LLMChunk` |
| `describe` | `() -> dict[str, str]` |

## Collaborators
- **Imported by:** `app.llm.{mock,openai,anthropic}_provider`, `app.runtime`, `app.agents.demo_agent`, `evals.framework`.

## Complexity
- `generate` / `stream`: O(tokens). Network-bound; latency dominates.

## Test coverage
- `tests/test_llm_providers.py` covers every method on `MockProvider`. The OpenAI/Anthropic providers are tested by contract (they implement the same interface) and at runtime via `LLM_PROVIDER=...`.

## Adding a new provider
1. Create `app/llm/<name>_provider.py` subclassing `LLMProvider`.
2. Implement `from_settings`, `generate`, `stream`.
3. Register in `_REGISTRY` inside [`app/llm/__init__.py`](../../backend/app/llm/__init__.py).
4. Add a one-line spec doc following this template.
