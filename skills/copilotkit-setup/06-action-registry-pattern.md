# 06 — Action registry pattern

Actions are how the LLM calls into your code. The kickstarter ships them as **typed Pydantic-validated handlers** behind a single dispatcher. This page is the playbook for designing them.

---

## The shape of an action

Three pieces, one wrapper:

```python
# 1. Typed parameters — Pydantic does validation + JSON-schema generation
class WeatherParams(BaseModel):
    city: str = Field(description="City name, e.g. 'London'.")
    units: str = Field(default="celsius", description="'celsius' or 'fahrenheit'.")

# 2. The async handler — receives a *validated* model instance, not raw dict
async def _weather(params: WeatherParams) -> dict:
    return {"city": params.city, "temp": 18.5, "units": params.units}

# 3. The Action wrapper — name, description, glue
weather_action: Action[WeatherParams] = Action(
    name="get_weather",
    description="Get the current weather for a city.",
    parameters=WeatherParams,
    handler=_weather,
)
```

That's the whole pattern. Add three lines to a registry, and the LLM sees it on the next turn.

---

## Why a wrapper instead of a decorator?

You'll see action libraries that use decorators:

```python
@action(name="get_weather", description="…")
async def weather(city: str, units: str = "celsius"): ...
```

The kickstarter avoids that for two reasons:

1. **Schema generation needs explicit types.** Decorators that introspect function signatures are fragile when params are nested models, optional, or have descriptions. Pydantic models are unambiguous.
2. **Multiple schema formats from one source.** `Action.openai_schema()`, `Action.anthropic_schema()`, `Action.copilotkit_schema()` all derive from the same Pydantic model. A decorator-based system means writing three.

The wrapper is ~30 lines of code. It pays back immediately.

---

## The `Action` class

```python
@dataclass(frozen=True, slots=True)
class Action(Generic[ParamsT]):
    name: str
    description: str
    parameters: type[ParamsT]
    handler: Callable[[ParamsT], Awaitable[Any]]

    def openai_schema(self) -> dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters.model_json_schema(),
            },
        }

    def anthropic_schema(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "input_schema": self.parameters.model_json_schema(),
        }

    def copilotkit_schema(self) -> dict[str, Any]:
        schema = self.parameters.model_json_schema()
        properties = schema.get("properties", {})
        required = set(schema.get("required", []))
        params = [
            {"name": n, "type": p.get("type", "string"),
             "description": p.get("description", ""), "required": n in required}
            for n, p in properties.items()
        ]
        return {"name": self.name, "description": self.description, "parameters": params}

    async def call(self, raw_args: dict[str, Any]) -> ActionResult:
        """Validate and run. Never raises — always returns ActionResult."""
        try:
            parsed = self.parameters.model_validate(raw_args)
        except ValidationError as exc:
            return ActionResult(ok=False, error=f"invalid arguments: {exc}")
        try:
            value = await self.handler(parsed)
        except Exception as exc:
            return ActionResult(ok=False, error=f"{type(exc).__name__}: {exc}")
        return ActionResult(ok=True, value=value)
```

**Key property: `call()` never raises.** The LLM gets a structured `ActionResult.error` instead of a 500. The runtime stays up; the LLM can apologize and try again.

---

## The `ActionRegistry` class

```python
class ActionRegistry:
    def __init__(self, actions: Iterable[Action] = ()) -> None:
        self._actions: dict[str, Action] = {}
        for a in actions:
            self.register(a)

    def register(self, action: Action) -> None:
        if action.name in self._actions:
            raise ValueError(f"Action {action.name!r} already registered.")
        self._actions[action.name] = action

    def names(self) -> list[str]: return sorted(self._actions)
    def get(self, name: str) -> Action | None: return self._actions.get(name)

    def openai_schemas(self) -> list[dict]: return [a.openai_schema() for a in self._actions.values()]
    def anthropic_schemas(self) -> list[dict]: return [a.anthropic_schema() for a in self._actions.values()]
    def copilotkit_schemas(self) -> list[dict]: return [a.copilotkit_schema() for a in self._actions.values()]

    async def dispatch(self, call: ToolCall) -> ActionResult:
        action = self.get(call.name)
        if action is None:
            return ActionResult(ok=False, error=f"unknown action: {call.name!r}")
        return await action.call(call.arguments)
```

Single dispatcher, one job. Same shape as `LLMProvider` — the kickstarter is consistent.

---

## Where each action lives

Decision tree:

```
Does this action touch local React state, the DOM, or browser APIs?
├── Yes → frontend (useCopilotAction in a registration component)
└── No  → backend
            ├── Talks to a database / ML model / Python lib? → Action in app/actions/
            ├── Talks to a third-party HTTP API? → Action in app/actions/
            └── Pure transformation of args → either side; prefer backend if reusable
```

Don't agonize. Wrong placement is a 5-minute move (paste the params + handler, swap the wrapper).

---

## Frontend actions: `useCopilotAction`

```tsx
useCopilotAction({
  name: "highlightSection",
  description: "Visually highlight a DOM section by id.",
  parameters: [
    { name: "id", type: "string", description: "DOM id.", required: true },
  ],
  handler: async ({ id }) => {
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    return { ok: true };
  },
});
```

**Pattern:** keep handlers thin. They validate-then-delegate to the actual mutator (passed in via props, fetched from a hook, etc.). The `<ExampleActions />` component returns `null` — it exists only to register actions.

---

## Server-side actions in CopilotKit's expected format

CopilotKit's Python SDK accepts a list of dicts:

```python
[
    {
        "name": "get_weather",
        "description": "...",
        "parameters": [
            {"name": "city", "type": "string", "description": "...", "required": True},
            {"name": "units", "type": "string", "description": "...", "required": False},
        ],
        "handler": <async function>,
    },
]
```

The kickstarter wraps this in `runtime.py`:

```python
def _action_to_copilotkit(action: Action) -> dict:
    schema = action.copilotkit_schema()
    async def _handler(**kwargs):
        result = await action.call(kwargs)
        return result.value if result.ok else {"error": result.error}
    return {**schema, "handler": _handler}

sdk_actions = [_action_to_copilotkit(a) for a in registry._actions.values()]
endpoint = CopilotKitRemoteEndpoint(actions=sdk_actions, agents=[])
```

Notice: the runtime adapter is the *only* place we touch the SDK shape. `Action` and `ActionRegistry` remain SDK-agnostic.

---

## Best practices

### Names
- `verb_noun` (`create_ticket`, `add_todo`, `get_weather`).
- The LLM picks them by name + description, so be specific. `get_weather` beats `weather`.

### Descriptions
- Write a sentence the LLM will read like documentation.
- Mention units, side-effects, idempotency: "Sends an email. Idempotent within a session via the `idempotency_key` parameter."

### Parameters
- Always add Pydantic `Field(description=...)` — the schema description guides the LLM.
- Use defaults aggressively. `units: str = Field(default="celsius")` means the LLM doesn't have to ask.
- For enums, use `Literal[...]` — Pydantic generates a JSON-schema `enum` array, which the LLM respects.

### Return shapes
- Always return a dict. Keys make the result self-describing.
- `{"ok": True, ...}` for success, `{"ok": False, "error": "..."}` for failure — even if the wrapper would've shown the error anyway.
- Don't return huge blobs (10K+ tokens). Truncate or reference by id.

### Error handling
- Don't `try / except` in the handler unless you're translating an exception into a clean LLM-readable error. The wrapper catches everything else.
- Pre-validate with Pydantic, not with manual `assert`s — the validator gives the LLM a usable error message.

### Testing
- Every action gets a unit test that calls `action.call({...})` directly.
- Every action gets an eval scenario (or shares one) that verifies the LLM picks it correctly given a prompt.

---

## Worked example: an action that calls the LLM

You can compose actions with the `LLMProvider`:

```python
class SummarizeParams(BaseModel):
    text: str
    max_words: int = 50

async def _summarize(params: SummarizeParams) -> dict:
    provider = get_provider()
    rsp = await provider.generate([
        LLMMessage(role="system", content=f"Summarize in <= {params.max_words} words."),
        LLMMessage(role="user", content=params.text),
    ])
    return {"summary": rsp.content}

summarize_action = Action(
    name="summarize",
    description="Summarize a long text concisely.",
    parameters=SummarizeParams,
    handler=_summarize,
)
```

This works whether `LLM_PROVIDER` is mock, openai, or anthropic — the action stays vendor-agnostic.

---

## What NOT to do

- **Don't put authentication in the handler.** Put it at the route layer (`/copilotkit_remote` middleware).
- **Don't return raw vendor objects** (e.g. an OpenAI `ChatCompletion`). Always return JSON-serializable dicts.
- **Don't share `Action` instances across registries** if registries have different states — the `Action` is stateless, but its handler may close over module-level state.
- **Don't make `Action.parameters` optional.** Even single-param actions should declare a model — future-you will thank you when adding a second param.
