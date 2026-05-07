# `AnthropicProvider`

**File:** [`backend/app/llm/anthropic_provider.py`](../../backend/app/llm/anthropic_provider.py)

## Purpose
Adapter mapping the unified `LLMProvider` interface onto the Anthropic Messages API.

## Activation

```
LLM_PROVIDER=anthropic
LLM_MODEL=claude-sonnet-4-6
ANTHROPIC_API_KEY=sk-ant-...
```

## Mapping notes
- Anthropic takes `system` as a top-level argument — we extract any `system`-role messages and concatenate them.
- `messages` accepts only `user` and `assistant`. Our `tool` role is folded into `user` (you'll usually emit a fresh user-turn carrying the tool result anyway).
- Tool calls come back as `content` blocks of type `tool_use`; we flatten them into `ToolCall`.

## Public surface
Inherits `LLMProvider`. Constructor: `AnthropicProvider(model: str, api_key: str)`.

## Collaborators
- **Imports:** `anthropic.AsyncAnthropic` (lazy).
- **Imported by:** `app.llm` factory.

## Complexity
- `generate`: 1 round-trip.
- `stream`: text streamed via `stream.text_stream`; tool-uses materialized at end via `get_final_message`.

## Test coverage
- Contract tests via `tests/test_llm_providers.py`.
- Live behavior tested manually with `LLM_PROVIDER=anthropic` + valid key.

## Failure modes
- Missing key → `ValueError`.
- API errors propagate.
