# `DefaultAgent` (LangGraph)

**File:** [`backend/app/agents/default_agent.py`](../../backend/app/agents/default_agent.py)

## Purpose
Minimal one-node LangGraph CoAgent registered as `"default"`. Required so CopilotKit 1.57+'s `useAgent("default")` lookup succeeds on page load; doubles as a working chat handler that uses our `LLMProvider`.

## Public surface

| Member | Signature | Notes |
|---|---|---|
| `_to_llm_message` | `(BaseMessage) -> LLMMessage` | LangChain → our normalized DTO. |
| `_chat_node` | `async (MessagesState) -> dict` | One LLM call via `get_provider()`. |
| `build_default_graph` | `() -> CompiledStateGraph` | Compiles START → chat → END. |

## Collaborators
- **Imports:** `langchain_core.messages.*`, `langgraph.graph.*`, `app.llm.get_provider`.
- **Imported by:** `app.agents.__init__`, `app.runtime`.

## Why a real LangGraph and not a stub?
CopilotKit 1.57+'s React side calls `useAgent("default")` internally for the standard chat surface (`<CopilotChat>` / `<CopilotSidebar>`). The runtime's `/info` endpoint must return at least one agent OR the React provider must register one via `agents__unsafe_dev_only`. We do both for safety: the agent is mounted at `/agent/default` on the Python side and a matching `HttpAgent` is registered on the React side.

## Replacing this with your real agent

The graph is intentionally trivial — one chat node. To upgrade:

```python
def build_my_graph() -> CompiledStateGraph:
    graph = StateGraph(MessagesState)
    graph.add_node("plan",   plan_node)
    graph.add_node("execute", execute_node)
    graph.add_node("review",  review_node)
    graph.add_edge(START, "plan")
    graph.add_conditional_edges("plan", lambda s: "execute" if s["plan"] else END)
    graph.add_edge("execute", "review")
    graph.add_edge("review", END)
    return graph.compile()
```

Then in `runtime.py`, swap `build_default_graph()` for your `build_my_graph()`. No other change needed — the agent's URL stays `/agent/default` and the React side keeps working.

## Complexity
- `_chat_node`: O(LLM call). Streaming-ready when you swap `generate` for `stream`.
- `build_default_graph`: O(1). Called once at startup.

## Test coverage
- `tests/test_health.py` (integration; verifies the FastAPI app boots with the agent mounted).
- The `LLMProvider` it delegates to is fully covered by `tests/test_llm_providers.py` and `evals/`.

## Failure modes
- Missing `OPENAI_API_KEY` with `LLM_PROVIDER=openai` → `OpenAIProvider.__init__` raises before the graph runs (clear error at startup).
- Mock provider doesn't see `tools=[]` from CopilotKit's request — it just echoes. Real providers (OpenAI/Anthropic) DO see the tool schemas via the AG-UI request body and can call actions.
