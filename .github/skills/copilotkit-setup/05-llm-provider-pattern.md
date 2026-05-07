# 05 — LLM provider abstraction pattern

The kickstarter has **two LLM-call locations** that share one `LLM_PROVIDER` env var:

1. **Next.js service adapter** — handles standard chat (the `/api/copilotkit` route).
2. **Python `LLMProvider`** — used by evals and any future LangGraph CoAgent.

Both layers are picked at runtime from the same env. This page explains the pattern and how to extend it.

---

## The contract (Python)

```python
# app/llm/base.py
class LLMProvider(ABC):
    @classmethod
    @abstractmethod
    def from_settings(cls, settings: Settings) -> Self: ...

    @abstractmethod
    async def generate(
        self,
        messages: list[LLMMessage],
        tools: list[dict[str, Any]] | None = None,
    ) -> LLMResponse: ...

    @abstractmethod
    def stream(
        self,
        messages: list[LLMMessage],
        tools: list[dict[str, Any]] | None = None,
    ) -> AsyncIterator[LLMChunk]: ...
```

Plus four DTOs:

```python
@dataclass(frozen=True, slots=True)
class LLMMessage:
    role: Literal["system", "user", "assistant", "tool"]
    content: str
    name: str | None = None
    tool_call_id: str | None = None

@dataclass(frozen=True, slots=True)
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any]

@dataclass(frozen=True, slots=True)
class LLMResponse:
    content: str
    tool_calls: tuple[ToolCall, ...] = ()
    finish_reason: str = "stop"
    raw: dict[str, Any] = field(default_factory=dict)

@dataclass(frozen=True, slots=True)
class LLMChunk:
    text_delta: str = ""
    tool_call: ToolCall | None = None
    done: bool = False
```

**Why DTOs and not vendor types directly?** Because then *every* downstream consumer (registry, evals, CoAgents) speaks the same language. Vendor JSON dies at the adapter boundary.

---

## The factory

```python
# app/llm/__init__.py
_REGISTRY: dict[str, type[LLMProvider]] = {
    "mock": MockProvider,
    "openai": OpenAIProvider,
    "anthropic": AnthropicProvider,
}

def get_provider(settings: Settings | None = None) -> LLMProvider:
    settings = settings or get_settings()
    cls = _REGISTRY.get(settings.llm_provider)
    if cls is None:
        raise ValueError(f"Unknown LLM_PROVIDER={settings.llm_provider!r}")
    return cls.from_settings(settings)
```

**Adding a new provider is a one-line change here** — register the class.

---

## Concrete adapters

Three patterns to follow. Lazy-import the SDK so users without that vendor's library can still run the rest.

### MockProvider — never network

```python
# app/llm/mock_provider.py
class MockProvider(LLMProvider):
    name = "mock"

    @classmethod
    def from_settings(cls, settings: Settings) -> Self:
        return cls(model=settings.llm_model or "mock-1")

    async def generate(self, messages, tools=None) -> LLMResponse:
        user = self._last_user(messages)
        if tool := self._maybe_tool_call(user):
            return LLMResponse("", tool_calls=(tool,), finish_reason="tool_calls")
        return LLMResponse(f"[mock] {user or '(empty)'}", finish_reason="stop")
```

`/tool <name> <json>` directives in user messages produce structured `ToolCall` outputs — perfect for testing the action pipeline without an LLM.

### OpenAIProvider — real adapter

```python
# app/llm/openai_provider.py
class OpenAIProvider(LLMProvider):
    name = "openai"

    def __init__(self, model: str, api_key: str) -> None:
        super().__init__(model=model)
        if not api_key:
            raise ValueError("OPENAI_API_KEY is required when LLM_PROVIDER='openai'.")
        from openai import AsyncOpenAI  # noqa: PLC0415  — lazy
        self._client = AsyncOpenAI(api_key=api_key)
```

**Lazy import is non-negotiable**. It keeps `openai` truly optional — eval scenarios that use `provider: mock` still run on a machine without `openai` installed.

### AnthropicProvider — handle the role mismatch

Anthropic uses `system` as a top-level kwarg, not a message role. Extract and concatenate:

```python
@staticmethod
def _split(messages: list[LLMMessage]) -> tuple[str, list[dict]]:
    system_parts, chat = [], []
    for m in messages:
        if m.role == "system":
            system_parts.append(m.content)
        else:
            role = "user" if m.role in ("user", "tool") else "assistant"
            chat.append({"role": role, "content": m.content})
    return "\n\n".join(system_parts), chat
```

Tool calls come back as `content` blocks of `type="tool_use"` — flatten them:

```python
for block in rsp.content:
    if block.type == "text":
        text_parts.append(block.text)
    elif block.type == "tool_use":
        tool_calls.append(ToolCall(id=block.id, name=block.name, arguments=dict(block.input)))
```

---

## The Next side mirror

```ts
// frontend/app/api/copilotkit/route.ts
function buildServiceAdapter(): CopilotServiceAdapter {
  const provider = (process.env.LLM_PROVIDER || "mock").toLowerCase();
  const model = process.env.LLM_MODEL;

  if (provider === "openai") {
    if (!process.env.OPENAI_API_KEY) {
      console.warn("[copilotkit] LLM_PROVIDER=openai but OPENAI_API_KEY missing.");
      return new ExperimentalEmptyAdapter();
    }
    return new OpenAIAdapter({ model: model || "gpt-4o-mini" });
  }
  if (provider === "anthropic") {
    if (!process.env.ANTHROPIC_API_KEY) return new ExperimentalEmptyAdapter();
    return new AnthropicAdapter({ model: model || "claude-sonnet-4-6" });
  }
  return new ExperimentalEmptyAdapter();  // mock / unset
}
```

**Why `EmptyAdapter` for mock?** Because the Next-side service adapter interface is opinionated — there's no "MockServiceAdapter" out of the box. The empty adapter lets the page load; chat just won't return a model response in mock mode. For deterministic chat, write a tiny custom adapter (see "Custom adapter" below).

---

## Adding a new provider

You'll typically add it to **both** layers (so the symmetry holds).

### Backend
1. Create `backend/app/llm/<name>_provider.py`. Subclass `LLMProvider`. Lazy-import the SDK.
2. Register in `_REGISTRY` inside `app/llm/__init__.py`.
3. Add the provider name to `Literal[...]` in `app/config.py:ProviderName`.
4. Pin the SDK in `backend/requirements.txt`.
5. Add a spec doc under `docs/classes/`.
6. (Optional) Add an eval scenario with `provider: <name>` to verify wiring.

### Frontend
1. Add a branch in `buildServiceAdapter()` in `frontend/app/api/copilotkit/route.ts`.
2. Update `.env.example` with the new key requirements.
3. Update `docs/classes/RuntimeRoute.md` with the new row.

That's it. Both layers stay in lockstep with the env var.

---

## Custom Service Adapter (advanced)

If you want **chat to work without any API keys** in mock mode, write a `MockServiceAdapter` on the Next side. The interface lives in `@copilotkit/runtime`:

```ts
import type { CopilotServiceAdapter } from "@copilotkit/runtime";

class MockServiceAdapter implements CopilotServiceAdapter {
  async process(request) {
    // request.messages[].content is the conversation
    // Return an SSE-compatible response or a streaming generator
    // See @copilotkit/runtime source for the exact shape.
  }
}
```

This is an optional polish — the kickstarter doesn't ship it because most users will set a key once chat is interesting.

---

## Wrappers (decorator pattern)

Add cross-cutting concerns by wrapping any provider:

```python
class RetryingProvider(LLMProvider):
    """Decorator: retry generate() on transient failures."""
    def __init__(self, inner: LLMProvider, max_retries: int = 3): ...

class MeteredProvider(LLMProvider):
    """Decorator: record token usage from LLMResponse.raw."""
```

Compose: `RetryingProvider(MeteredProvider(OpenAIProvider(...)))`. Single-purpose all the way down.

---

## Test coverage

Every provider needs:

1. **Contract test** — every method on the ABC works (covered for `MockProvider`).
2. **Unit test for vendor-specific mapping** — e.g. AnthropicProvider's `_split` extracts system messages correctly.
3. **Eval scenario** — at least one YAML using `provider: <name>` to verify end-to-end.

Don't put real-network tests in CI. Use `pytest -m "not integration"` for default runs; gate live tests behind a marker or env flag.

---

## Common questions

**"Why have a Python `LLMProvider` if Next handles chat?"**
Three reasons:
1. **Evals.** Run a deterministic regression suite without involving the Next runtime.
2. **CoAgents.** The day you build a real LangGraph agent, it uses this abstraction.
3. **Server-side actions** that need an LLM — e.g. an `Action` whose handler calls `get_provider().generate(...)`.

**"Can I drop the Next adapter and run everything through Python?"**
Yes — but only in CoAgent mode (set `agent="<name>"` and ship a real LangGraph agent). The standard chat path goes through Next.

**"Does the user need to set both `OPENAI_API_KEY` for Next *and* the Python side?"**
Yes (one variable, both layers read it). The same `.env` is loaded by both processes — that's why `next.config.js` does `dotenv.config({ path: ... })`.
