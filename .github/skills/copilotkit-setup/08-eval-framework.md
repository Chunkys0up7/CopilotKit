# 08 — Eval framework

CopilotKit doesn't ship evals. The kickstarter does, because **untested copilots regress silently** — a prompt change that breaks tool selection looks identical to "the LLM is just being weird today".

This is a 200-line, declarative, deterministic-by-default scenario runner. Add scenarios as YAML files, run with pytest or a CLI.

---

## What this gives you

- **Declarative YAML scenarios** — non-engineers can write tests.
- **Deterministic runs via the mock provider** — CI doesn't pay rate-limit costs.
- **Pytest integration** — failing scenarios fail the build.
- **CLI runner with a pretty report** — fast feedback during development.
- **Real-LLM mode** — set `LLM_PROVIDER=openai` and the same scenarios run against the real model for prompt-quality regressions.

---

## Anatomy of a scenario

```yaml
# evals/scenarios/01_greeting.yaml
name: greeting
description: Plain greeting; expect the mock provider to echo it back.
provider: mock                     # optional override; defaults to LLM_PROVIDER
messages:
  - role: user
    content: "hello copilot"
expect:
  content_contains:
    - "hello copilot"
  content_matches: "^\\[mock\\]"
```

```yaml
# evals/scenarios/02_tool_call.yaml
name: weather_tool_call
description: User asks for weather; expect a structured tool call.
provider: mock
messages:
  - role: user
    content: '/tool get_weather {"city": "London", "units": "celsius"}'
expect:
  tool_calls:
    - name: get_weather
      arguments_contains:
        city: London
        units: celsius
```

The `/tool <name> <json>` directive is parsed by `MockProvider` to emit a deterministic `ToolCall` — perfect for testing the action pipeline without a live LLM.

---

## What the framework asserts

| YAML field | Assertion |
|---|---|
| `expect.tool_calls[]` | The model emitted at least one `ToolCall` whose `name` matches and whose `arguments` contain the listed key-values. |
| `expect.content_contains[]` | Each substring is present in the response text. |
| `expect.content_matches` | A regex matches the response text. |

This is intentionally minimal. For richer rubrics, extend `EvalExpectation` with a new field and one helper in `EvalRunner._check`.

### Possible extensions (when you need them)

- **LLM-as-judge:** `expect.judge_passes: "Did the response politely decline?"` — a second LLM call rates the response.
- **Embedding similarity:** `expect.semantic_similarity: { reference: "...", min: 0.85 }`.
- **Exact JSON shape:** `expect.json_shape: { keys: [...], types: {...} }`.

Don't add these until you have a use-case. Three rubrics covers ~90% of useful cases.

---

## The runner classes

```python
@dataclass(frozen=True, slots=True)
class EvalCase:
    name: str
    description: str
    messages: list[LLMMessage]
    expect: EvalExpectation
    provider_override: str | None = None

@dataclass(frozen=True, slots=True)
class EvalResult:
    case: EvalCase
    passed: bool
    failures: tuple[str, ...]
    response: LLMResponse

@dataclass(frozen=True, slots=True)
class EvalReport:
    results: tuple[EvalResult, ...]
    @property
    def total(self) -> int: return len(self.results)
    @property
    def passed(self) -> int: return sum(1 for r in self.results if r.passed)
    @property
    def failed(self) -> int: return self.total - self.passed
    def render(self) -> str:
        lines = [f"Eval report: {self.passed}/{self.total} passed"]
        for r in self.results:
            lines.append(f"  [{r.status}] {r.case.name} — {r.case.description}")
            for f in r.failures:
                lines.append(f"      ! {f}")
        return "\n".join(lines)

class EvalRunner:
    def __init__(self, provider: LLMProvider | None = None) -> None:
        self._default_provider = provider or get_provider()
        self._settings = get_settings()

    async def run_one(self, case: EvalCase) -> EvalResult:
        provider = self._resolve_provider(case.provider_override)
        rsp = await provider.generate(case.messages)
        failures = list(self._check(case.expect, rsp))
        return EvalResult(case=case, passed=not failures,
                          failures=tuple(failures), response=rsp)

    async def run_all(self, cases: Iterable[EvalCase]) -> EvalReport:
        results = [await self.run_one(c) for c in cases]
        return EvalReport(results=tuple(results))
```

Single-purpose: load, run, check, report.

---

## Two ways to run

### Pytest (CI default)

```python
# evals/test_scenarios.py
@pytest.mark.eval
@pytest.mark.parametrize("case", load_scenarios(SCENARIOS_DIR), ids=lambda c: c.name)
async def test_scenario(case: EvalCase) -> None:
    runner = EvalRunner()
    result = await runner.run_one(case)
    assert result.passed, "\n".join(result.failures) or "scenario failed"
```

```bash
pytest evals/                      # only scenarios
pytest -m "not eval"               # skip them (faster)
pytest                             # everything
```

### CLI (developer ergonomics)

```bash
python -m evals.runner
# → Eval report: 2/2 passed
#     [PASS] greeting — Plain greeting...
#     [PASS] weather_tool_call — User asks for weather...
```

Exit code: 0 if all pass, 1 if any fail. Drop into a CI step.

---

## Provider override per scenario

Three modes:

```yaml
# 1. Use the env's LLM_PROVIDER (no override)
name: my_scenario
messages: [...]

# 2. Force mock — useful for action-pipeline tests in CI
name: my_scenario
provider: mock
messages: [...]

# 3. Force a real provider — useful for prompt-quality regression tests
name: my_scenario
provider: openai
messages: [...]
```

Real-provider scenarios should be tagged `@pytest.mark.live` and gated behind an env flag so CI can opt out:

```python
@pytest.mark.live
@pytest.mark.skipif(not os.getenv("RUN_LIVE_EVALS"), reason="live LLM required")
async def test_live_scenarios(): ...
```

---

## Patterns

### One scenario per behavior

"When the user asks X, the model emits Y." Don't bundle multiple turns into one expectation.

### Use `provider: mock` plus `/tool` directives for action coverage

Fast, free, reliable. Tests that the dispatch logic works, not that the LLM is smart.

### Bug-fix → scenario

Whenever you fix a copilot bug, add a scenario that would have caught it. Free regression coverage.

### Multi-turn conversations

```yaml
name: clarification
provider: mock
messages:
  - role: user
    content: "set up my account"
  - role: assistant
    content: "What's your email?"
  - role: user
    content: "alice@example.com"
expect:
  content_contains:
    - "alice@example.com"
```

The framework feeds the entire `messages` array to `provider.generate()`. The mock provider only sees the last user message; real providers see the full history.

### System prompts

```yaml
name: tone_check
messages:
  - role: system
    content: "Always respond in haiku."
  - role: user
    content: "What is the weather?"
expect:
  content_matches: "^.{,40}\\n.{,40}\\n.{,40}$"   # 3 short lines
```

---

## What NOT to do

- **Don't write rubric checks by string-matching every word.** Use `content_matches` regex sparingly — it gets brittle.
- **Don't run live LLMs in your default `pytest` invocation.** Cost, flakiness, secret-leakage risk in CI.
- **Don't share state across scenarios.** Each `EvalCase` is independent.
- **Don't skip the mock provider** — it's the only thing that makes evals fast and free.

---

## Beyond the basics

When your eval suite grows past ~50 scenarios:

- **Parallelize:** run scenarios concurrently with `asyncio.gather` (the kickstarter runs sequentially for clarity).
- **Cache LLM responses:** key by `hash(messages + provider + model)`, store under `evals/.cache/`. Iterate prompts without burning tokens.
- **Aggregate metrics:** track pass rate, latency p50/p95, token usage per scenario. Add to the `EvalReport`.
- **Diff reports:** record JSON of last-good results; CI fails if pass rate drops.

These are easy add-ons because the core types stay the same.

---

## Comparison to other tools

| Tool | What | When to reach for it |
|---|---|---|
| **This kickstarter's evals** | Action-pipeline + prompt regression. | First 100 scenarios. Always. |
| **LangSmith / LangFuse** | Observability + evals SaaS. | When you want dashboards and team review. |
| **Ragas** | RAG-specific metrics (faithfulness, context precision). | RAG-heavy projects. |
| **DeepEval / Promptfoo** | Heavier rubric DSL, LLM-as-judge built in. | When you need 10+ rubric types. |

The kickstarter's framework is intentionally tiny — it covers the case "did the right tool get called with the right args." Reach for the heavier tools when you've outgrown that.
