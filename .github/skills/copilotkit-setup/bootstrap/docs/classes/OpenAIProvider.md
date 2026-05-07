# `OpenAIProvider`

**File:** [`backend/app/llm/openai_provider.py`](../../backend/app/llm/openai_provider.py)

## Purpose
Adapter mapping the unified `LLMProvider` interface onto the OpenAI Chat Completions SDK.

## Activation
Set in `.env`:

```
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
OPENAI_API_KEY=sk-...
```

## Public surface
Inherits `LLMProvider`. Constructor signature: `OpenAIProvider(model: str, api_key: str)`.

## Mapping notes
- `LLMMessage.role` maps 1-to-1 with OpenAI message roles.
- `LLMMessage.tool_call_id` is included when role=`tool`.
- Streaming: tool-call deltas arrive as fragments per index — we accumulate into `partial[index]` and emit on stream end.

## Collaborators
- **Imports:** `openai.AsyncOpenAI` (lazy).
- **Imported by:** `app.llm` factory.

## Complexity
- `generate`: 1 round-trip; cost dominated by tokens.
- `stream`: same, with chunk accumulation O(tool-call args).

## Test coverage
- Contract tests via `tests/test_llm_providers.py` (provider-agnostic shape checks).
- Live tests are intentionally not in CI — set `LLM_PROVIDER=openai` and run the eval runner manually for smoke-checks.

## Failure modes
- Missing `OPENAI_API_KEY` → `ValueError` at instantiation.
- Network / rate-limit errors propagate unchanged so callers can apply their own retry policy.
