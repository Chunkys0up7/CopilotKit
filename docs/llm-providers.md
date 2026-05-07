# LLM providers

## What ships

| Provider | Module | Activation |
|---|---|---|
| `mock` (default) | `app/llm/mock_provider.py` | `LLM_PROVIDER=mock` |
| `openai` | `app/llm/openai_provider.py` | `LLM_PROVIDER=openai` + `OPENAI_API_KEY` |
| `anthropic` | `app/llm/anthropic_provider.py` | `LLM_PROVIDER=anthropic` + `ANTHROPIC_API_KEY` |

All three implement the same `LLMProvider` interface (see [`docs/classes/LLMProvider.md`](classes/LLMProvider.md)). Everything downstream — actions, agents, evals, the FastAPI mount — is provider-agnostic. Swapping providers is a `.env` change.

## Adding a new provider

1. **Create** `backend/app/llm/<name>_provider.py`. Subclass `LLMProvider`, implement `from_settings`, `generate`, `stream`. Lazy-import the SDK.
2. **Register** in `_REGISTRY` inside [`backend/app/llm/__init__.py`](../backend/app/llm/__init__.py).
3. **Spec doc** — copy `OpenAIProvider.md` as a template; commit it under `docs/classes/`.
4. **Pin** the SDK in `backend/requirements.txt`.
5. **Tests** — add the provider name to `Literal[...]` in `app/config.py:ProviderName` so the type checker enforces the union.
6. **Eval scenario** — optional; one YAML with `provider: <name>` confirms the wiring.

## Mapping cheat-sheet

CopilotKit's runtime ultimately doesn't care which provider runs the model — the FastAPI backend handles that. So the *only* place vendor-specific logic lives is the provider class itself. Keep it that way:

- **Don't** sprinkle `if provider == "openai"` checks anywhere else.
- **Don't** add provider-specific retry policies in `app.runtime` — implement a `RetryingProvider` decorator that wraps any `LLMProvider`.
- **Do** normalize tool calls to our `ToolCall` shape; the rest of the app shouldn't see vendor JSON.

## Cost & latency

The kickstarter doesn't ship cost tracking. When you need it, wrap providers with a `MeteredProvider` that records `usage` from `LLMResponse.raw` to your metrics sink. Same pattern works for tracing (OpenTelemetry spans around `generate` / `stream`).
