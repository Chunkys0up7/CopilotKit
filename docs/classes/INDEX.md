# Class spec index

Each spec follows the same template:

1. **Purpose** — one sentence.
2. **Public surface** — methods/props with signatures.
3. **Collaborators** — who it imports / who imports it.
4. **Complexity** — Big-O for hot paths.
5. **Test coverage** — which test files exercise it.

| Class / Module | File | Spec |
|---|---|---|
| `Settings` | [backend/app/config.py](../../backend/app/config.py) | [Settings.md](Settings.md) |
| `LoggingConfig` | [backend/app/logging_config.py](../../backend/app/logging_config.py) | [LoggingConfig.md](LoggingConfig.md) |
| `LLMProvider` | [backend/app/llm/base.py](../../backend/app/llm/base.py) | [LLMProvider.md](LLMProvider.md) |
| `MockProvider` | [backend/app/llm/mock_provider.py](../../backend/app/llm/mock_provider.py) | [MockProvider.md](MockProvider.md) |
| `OpenAIProvider` | [backend/app/llm/openai_provider.py](../../backend/app/llm/openai_provider.py) | [OpenAIProvider.md](OpenAIProvider.md) |
| `AnthropicProvider` | [backend/app/llm/anthropic_provider.py](../../backend/app/llm/anthropic_provider.py) | [AnthropicProvider.md](AnthropicProvider.md) |
| `Action` | [backend/app/actions/base.py](../../backend/app/actions/base.py) | [Action.md](Action.md) |
| `ActionRegistry` | [backend/app/actions/registry.py](../../backend/app/actions/registry.py) | [ActionRegistry.md](ActionRegistry.md) |
| `ExampleActions` (BE) | [backend/app/actions/examples.py](../../backend/app/actions/examples.py) | [ExampleActions.md](ExampleActions.md) |
| `DemoAgent` | [backend/app/agents/demo_agent.py](../../backend/app/agents/demo_agent.py) | [DemoAgent.md](DemoAgent.md) |
| `Runtime (FastAPI)` | [backend/app/runtime.py](../../backend/app/runtime.py) | [Runtime.md](Runtime.md) |
| `EvalRunner` | [backend/evals/framework.py](../../backend/evals/framework.py) | [EvalRunner.md](EvalRunner.md) |
| `RootLayout` | [frontend/app/layout.tsx](../../frontend/app/layout.tsx) | [RootLayout.md](RootLayout.md) |
| `HomePage` | [frontend/app/page.tsx](../../frontend/app/page.tsx) | [HomePage.md](HomePage.md) |
| `RuntimeRoute` | [frontend/app/api/copilotkit/route.ts](../../frontend/app/api/copilotkit/route.ts) | [RuntimeRoute.md](RuntimeRoute.md) |
| `CopilotProvider` | [frontend/components/CopilotProvider.tsx](../../frontend/components/CopilotProvider.tsx) | [CopilotProvider.md](CopilotProvider.md) |
| `ChatPanel` | [frontend/components/ChatPanel.tsx](../../frontend/components/ChatPanel.tsx) | [ChatPanel.md](ChatPanel.md) |
| `ExampleActions` (FE) | [frontend/components/actions/ExampleActions.tsx](../../frontend/components/actions/ExampleActions.tsx) | [FE_ExampleActions.md](FE_ExampleActions.md) |
| `useTodos` | [frontend/lib/readables.ts](../../frontend/lib/readables.ts) | [useTodos.md](useTodos.md) |

> **Rule.** A PR that adds, removes, or changes the public surface of a
> class must also update its spec doc. CI checks this with the doc
> linter (TODO — see `docs/extending/spec-lint.md`).
