# Complexity reference

Big-O for every hot path. Updated whenever a class changes.

## Backend

| Operation | Class | Complexity | Notes |
|---|---|---|---|
| `Settings()` (startup) | `Settings` | O(env vars) | Once per process. |
| `get_settings()` | `Settings` | O(1) | Cached singleton. |
| `LLMProvider.generate(messages)` | every provider | O(input + output tokens) | Network-bound. |
| `LLMProvider.stream(messages)` | every provider | O(output tokens) per chunk | Streaming. |
| `MockProvider._maybe_tool_call` | `MockProvider` | O(message length) | Pure parse. |
| `Action.call(args)` | `Action` | O(args) for validation + O(handler) | |
| `Action.openai_schema()` etc. | `Action` | O(params) | Cheap, called once per request. |
| `ActionRegistry.get(name)` | `ActionRegistry` | O(1) | Dict lookup. |
| `ActionRegistry.dispatch(call)` | `ActionRegistry` | O(1) + O(handler) | |
| `ActionRegistry.<vendor>_schemas()` | `ActionRegistry` | O(N actions × M params) | |
| `DemoAgent.run(msg)` | `DemoAgent` | O(2 snapshots × LLM call) | |
| `runtime.mount(app)` | `Runtime` | O(N actions) | Once per process. |
| `EvalRunner.run_one(case)` | `EvalRunner` | O(1 LLM call) | |
| `EvalRunner.run_all(cases)` | `EvalRunner` | O(N) sequential | Parallelization is opt-in. |
| `load_scenarios(dir)` | (module) | O(N files × file size) | Once per run. |

## Frontend

| Operation | Class | Complexity | Notes |
|---|---|---|---|
| `<HomePage />` render | `HomePage` | O(todos) | |
| `useTodos.addTodo` | `useTodos` | O(N) | Array spread. |
| `useTodos.removeTodo` | `useTodos` | O(N) | Filter. |
| `useTodos.toggleTodo` | `useTodos` | O(N) | Map. |
| `useCopilotReadable` push | (CopilotKit) | O(value size) | Token cost on every turn. |
| `useCopilotAction` registration | (CopilotKit) | O(1) per action | |
| `/api/copilotkit` POST | `RuntimeRoute` | O(streamed bytes) | SSE relay. |

## Whole-system characteristics

- **Latency floor** = network RTT to the chosen LLM provider.
- **Throughput** = single FastAPI worker is fine for dev. Add `uvicorn --workers N` for prod; the runtime is stateless within a request.
- **Memory** = bounded by max conversation length × ~4 bytes/token. A thousand active conversations of 8K tokens each ≈ 32 MB.
- **CPU** = negligible — almost everything is I/O.
