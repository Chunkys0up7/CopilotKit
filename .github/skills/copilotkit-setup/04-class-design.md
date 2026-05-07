# 04 — Small, single-purpose classes

The kickstarter is built on one rule: **one file, one class, one job**. Apply it to your project and the codebase stays diffable, teachable, and testable.

---

## The rule

For every class:

1. **One purpose.** A sentence describes what it does. If you need "and" or "also", split it.
2. **One file.** Named `<class_name>.py` (Python) or `<ClassName>.tsx` (React). The file is the class.
3. **One spec.** A Markdown doc at `docs/classes/<ClassName>.md` describes purpose, public surface, collaborators, complexity, test coverage.
4. **Public surface ≤ 7 methods.** If you need more, extract a collaborator.
5. **Imports tell the story.** A reader can predict what the class does from its imports alone.

This is **not** "tiny classes everywhere" — it's "classes that earn their name". A 200-line `LLMProvider` ABC is fine if it has one job.

---

## Anti-patterns to avoid

- **`Manager`, `Helper`, `Util`, `Service`, `Handler` suffixes.** These names mean "I couldn't think of what this is". Find the real noun.
- **Mixed concerns.** A class that fetches *and* validates *and* renders is three classes wearing one hat.
- **Hidden side effects in `__init__`.** Constructors should be cheap and predictable.
- **God objects.** If `from .core import App` and `App` has the database, the LLM, and the cache, you've lost the structure.
- **Defensive over-abstraction.** Don't introduce `IFooFactoryProvider` until you've shipped at least two implementations.

---

## How the kickstarter applies the rule

| Class | One-sentence purpose | Public surface |
|---|---|---|
| `Settings` (pydantic-settings) | Single, validated source of runtime configuration loaded from env. | Field accessors + `get_settings()` factory. |
| `LLMProvider` (ABC) | Contract every concrete LLM adapter satisfies. | `from_settings`, `generate`, `stream`, `describe`. |
| `MockProvider` | Deterministic, network-free `LLMProvider` for tests/evals. | (inherits) |
| `OpenAIProvider` | Adapter mapping `LLMProvider` onto OpenAI Chat Completions. | (inherits) |
| `Action[ParamsT]` | One callable the LLM can invoke, with typed params. | `openai_schema`, `anthropic_schema`, `copilotkit_schema`, `call`. |
| `ActionRegistry` | Holds `Action`s by name and dispatches `ToolCall`s. | `register`, `get`, `dispatch`, `*_schemas`, `names`. |
| `EvalRunner` | Runs `EvalCase`s through an `LLMProvider` and reports pass/fail. | `run_one`, `run_all`. |
| `<CopilotProvider />` (React) | Wraps the app in `<CopilotKit>` context. | One component. |

Each fits in one file, has its own spec, and depends on only what it needs.

---

## Where to put what (Python)

```
app/
├── llm/
│   ├── base.py          # LLMProvider ABC + DTOs (no concrete logic)
│   ├── mock_provider.py # MockProvider only
│   ├── openai_provider.py
│   └── anthropic_provider.py
└── actions/
    ├── base.py          # Action + ActionResult (no registry logic)
    ├── registry.py      # ActionRegistry only
    └── examples.py      # Concrete actions (not the framework)
```

**Rule of thumb:** if you find yourself adding a third class to a file, split.

---

## Where to put what (React/TS)

```
components/
├── CopilotProvider.tsx          # one component, ~10 lines
├── ChatPanel.tsx                # one component, uses one hook
└── actions/
    └── ExampleActions.tsx       # registers actions, renders nothing
lib/
└── readables.ts                 # one hook, one concern
```

`useTodos` hook doesn't go in `ChatPanel` because it's reusable state, not chat UI. The hook is its own file with its own spec.

---

## Spec doc template

Every class gets one of these. Keep it short — the code is the truth, the spec is the contract.

```markdown
# `MyClass`

**File:** [`path/to/my_class.py`](../../path/to/my_class.py)

## Purpose
A one-sentence description of what this class is for.

## Public surface

| Member | Signature | Notes |
|---|---|---|
| `do_thing` | `async (x: int) -> Result` | Raises `FooError` on …. |
| `state` | `property -> str` | |

## Collaborators
- **Imports:** `Other`, `pydantic.BaseModel`.
- **Imported by:** `app.runtime`, `tests.test_my_class`.

## Complexity
- `do_thing`: O(n) where n = len(x).

## Test coverage
- `tests/test_my_class.py::test_do_thing_basic`
- `tests/test_my_class.py::test_do_thing_validates`

## Failure modes
- Bad input → `pydantic.ValidationError`.
- Network error in `do_thing` → propagates unchanged.
```

---

## Naming guide

Pick names that **describe the responsibility**, not the type:

| Bad | Better | Why |
|---|---|---|
| `LLMService` | `LLMProvider` | "Provider" implies the contract; "service" is meaningless. |
| `ActionManager` | `ActionRegistry` | A registry holds; a manager… does what? |
| `ChatHandler` | `ChatPanel` (component) / `EvalRunner` (executor) | "Handler" hides the verb. |
| `Utils.format_user` | `UserFormatter` (if it earns a class) or just a function | A bag of unrelated functions isn't a class. |
| `ICopilotProvider` | `LLMProvider` (no `I` prefix) | Python ABCs aren't named with Hungarian prefixes. |

---

## When to break the rule

Sometimes you genuinely need a 30-line file with two tiny dataclasses. That's fine — single-purpose isn't single-class. The constraint is **one *concept* per file**:

- ✅ `EvalCase`, `EvalExpectation`, `EvalResult`, `EvalReport` all in `framework.py` — they form one cohesive concept (the eval run).
- ❌ `LLMProvider`, `Action`, `ActionRegistry` in one file — three separate concepts.

When in doubt, split. Merging is easier than splitting later.

---

## How this scales

By commit 50 the codebase has grown — but every new capability is **a new file, not a bigger file**. New developer onboarding looks like "here's the registry, here's the provider, here's the runtime wiring" — and they read 30 lines of each instead of skimming a 2000-line `core.py`.

The spec docs become the index. `docs/classes/INDEX.md` is the table of contents to the codebase.

---

## Code review checklist

For PRs that add a class:

- [ ] File is named after the class.
- [ ] One sentence in the docstring describes the purpose.
- [ ] Public surface is ≤ 7 methods or fields.
- [ ] No `Manager`/`Helper`/`Util` suffix.
- [ ] Imports don't reach across unrelated layers (e.g. action handler doesn't import the LLM provider).
- [ ] Spec doc added under `docs/classes/`.
- [ ] At least one unit test references the class by name.

For PRs that change a class:

- [ ] Public surface change → spec doc updated in the same commit.
- [ ] If a method is removed/renamed → callers updated, deprecation period if external.
