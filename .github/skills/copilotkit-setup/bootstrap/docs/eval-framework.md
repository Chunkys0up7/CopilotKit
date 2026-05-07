# Eval framework

## TL;DR

```bash
cd backend
pytest -m eval                          # run every scenario via pytest
python -m evals.runner                  # standalone CLI: pretty report, exit code
```

Scenarios live in `backend/evals/scenarios/*.yaml`. Each is a YAML file that loads into an `EvalCase` (see [`docs/classes/EvalRunner.md`](classes/EvalRunner.md)).

## Why declarative YAML?

- **Non-engineers can write tests.** Product, support, and design can add a scenario without touching Python.
- **Language-agnostic.** Same YAML can drive future Node/TS or Go runners.
- **Diffable.** Pull request reviewers can spot expectation changes line-by-line.

## What can be asserted

| Field | Asserts |
|---|---|
| `expect.tool_calls[]` | The model emitted at least one `ToolCall` whose `name` matches and whose `arguments` contain the listed key-values. |
| `expect.content_contains[]` | Each substring is present in the response text. |
| `expect.content_matches` | A regex matches the response text. |

This intentionally stays simple. For richer rubrics (LLM-as-judge, embedding similarity, exact JSON shape), add a new optional field on `EvalExpectation` and one helper in `EvalRunner._check`.

## Provider selection

- Default: whatever `LLM_PROVIDER` is set to at process start.
- Override per-scenario via `provider: <name>` at the top of the YAML.
- For deterministic CI, write scenarios against `provider: mock`.
- For "real" smoke tests, drop the `provider` line and run with `LLM_PROVIDER=openai` / `anthropic` locally.

## How CI uses it

`pytest` discovers `evals/test_scenarios.py`, parametrizes it over every YAML, and fails the build on any non-passing case. Scenarios are marked `eval` so devs can opt out:

```bash
pytest -m "not eval"          # skip evals (faster local run)
pytest evals/                 # run only evals
```

## Patterns

- **One scenario per behavior.** "When the user asks X, the model emits Y." Don't bundle multiple turns into one expectation.
- **Use `provider: mock` plus `/tool` directives** for action-pipeline coverage. They run instantly and don't drift.
- **Use the real provider** for prompt-quality regression tests — but expect flakiness, and budget for it.
- **Add a scenario whenever you fix a bug.** The bug becomes a regression test for free.
