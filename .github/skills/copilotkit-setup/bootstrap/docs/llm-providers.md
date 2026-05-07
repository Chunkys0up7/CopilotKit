# LLM providers

The kickstarter has **two complementary provider layers** that share one `LLM_PROVIDER` env var.

| Layer | Where | What it powers | Adapter / class |
|---|---|---|---|
| **Frontend service adapter** | Next route `/api/copilotkit` | Standard chat (the LLM call for messages typed into the sidebar). | `OpenAIAdapter`, `AnthropicAdapter`, `ExperimentalEmptyAdapter` from `@copilotkit/runtime`. |
| **Backend `LLMProvider`** | Python `app/llm/*_provider.py` | Evals, custom server-side actions that need an LLM, future LangGraph CoAgents. | `MockProvider`, `OpenAIProvider`, `AnthropicProvider`. |

Both layers read the same `.env` (the Next side via `dotenv` in `next.config.js`). Setting `LLM_PROVIDER=openai` plus `OPENAI_API_KEY=…` enables both at once.

## What ships (Python `LLMProvider`)

| Provider | Module | Activation |
|---|---|---|
| `mock` (default) | `app/llm/mock_provider.py` | `LLM_PROVIDER=mock` |
| `openai` | `app/llm/openai_provider.py` | `LLM_PROVIDER=openai` + `OPENAI_API_KEY` |
| `anthropic` | `app/llm/anthropic_provider.py` | `LLM_PROVIDER=anthropic` + `ANTHROPIC_API_KEY` |

All three implement the same `LLMProvider` interface (see [`docs/classes/LLMProvider.md`](classes/LLMProvider.md)). Swapping providers is a `.env` change.

## What ships (Next service adapter)

| `LLM_PROVIDER` | Adapter | Required env |
|---|---|---|
| `openai` | `OpenAIAdapter` | `OPENAI_API_KEY` |
| `anthropic` | `AnthropicAdapter` | `ANTHROPIC_API_KEY` |
| `mock` *(default)* | `ExperimentalEmptyAdapter` | none — chat won't return a model response |

See [`docs/classes/RuntimeRoute.md`](classes/RuntimeRoute.md) for the full adapter selection logic.

## Adding a new provider

You'll typically add it to **both** layers so the kickstarter stays symmetrical.

### Backend `LLMProvider`
1. Create `backend/app/llm/<name>_provider.py`. Subclass `LLMProvider`, implement `from_settings`, `generate`, `stream`. Lazy-import the SDK.
2. Register in `_REGISTRY` inside [`backend/app/llm/__init__.py`](../backend/app/llm/__init__.py).
3. Add the provider name to `Literal[...]` in [`backend/app/config.py:ProviderName`](../backend/app/config.py).
4. Pin the SDK in `backend/requirements.txt`.
5. Spec doc — copy `OpenAIProvider.md` as a template.
6. Eval scenario — optional; one YAML with `provider: <name>`.

### Frontend service adapter
1. Add a branch in `buildServiceAdapter()` in [`frontend/app/api/copilotkit/route.ts`](../frontend/app/api/copilotkit/route.ts) keyed by your new `LLM_PROVIDER` value.
2. Document the key requirements in `.env.example`.

## Mapping cheat-sheet

- **Don't** sprinkle `if provider == "openai"` checks anywhere outside the provider class itself or the route's `buildServiceAdapter()`.
- **Don't** add provider-specific retry policies in `app.runtime` — implement a `RetryingProvider` decorator that wraps any `LLMProvider`.
- **Do** normalize tool calls to our `ToolCall` shape on the Python side; the rest of the app shouldn't see vendor JSON.

## Cost & latency

The kickstarter doesn't ship cost tracking. When you need it, wrap providers with a `MeteredProvider` that records `usage` from `LLMResponse.raw` to your metrics sink. Same pattern works for tracing (OpenTelemetry spans around `generate` / `stream`).
