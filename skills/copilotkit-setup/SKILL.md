---
name: copilotkit-setup
description: |
  Use when scaffolding a new in-app AI copilot project with CopilotKit (chat sidebar, generative UI,
  CoAgents) on top of Next.js + FastAPI, when adding CopilotKit to an existing app, or when
  debugging install / runtime errors with @copilotkit/* packages or the copilotkit PyPI SDK.
  Triggers on phrases like: "add a copilot to my app", "build a chat sidebar with actions",
  "wire up CopilotKit", "set up @copilotkit/react-core", "build a CoAgent", "useAgent: Agent X
  not found", "ExperimentalEmptyAdapter", "copilotkit Python 3.13 install fails", "scaffold an
  AI copilot project". Also use when the user asks for an "AI assistant in my UI", "in-app AI
  agent", or "agentic chat with tool use" and the stack is React/Next.js + Python.
---

# CopilotKit setup playbook

A spec-driven, repeatable way to bootstrap a CopilotKit project that **works on first install** and stays maintainable. Distilled from a real build that hit (and survived) every trap you'd otherwise hit on day one.

## When this skill applies

- Greenfield: "give me a CopilotKit kickstarter"
- Brownfield: "add a copilot sidebar to this Next.js app"
- Debugging: install fails, page shows `useAgent: Agent X not found`, port collisions, version conflicts
- Architecture decisions: where does the LLM call live? What's a CoAgent vs a service adapter?

## When NOT to use this skill

- The user wants pure backend agents with no UI → use plain LangGraph / CrewAI without CopilotKit.
- The user is working in a non-React stack (Vue, Svelte, native mobile) → CopilotKit's React-only.
- The user wants Streamlit / Gradio / Chainlit — those are different products with their own playbooks.

---

## The 10-second mental model

```
browser  ──►  /api/copilotkit  ──┬─►  service adapter  ←─ where the LLM call lives
   (React UI)  (Next route)      │                         for STANDARD CHAT
                                 └─►  Python /copilotkit_remote
                                      (server-side actions)
                                      (LangGraph CoAgents — optional)
```

**Two LLM-call locations**. Pick before you start:
- **Standard chat**: LLM runs in the Next route via `OpenAIAdapter` / `AnthropicAdapter`. Easy default. Use unless you need LangGraph features.
- **CoAgent mode**: LLM runs in Python inside a LangGraph. Required when you want streaming agent state (`useCoAgentStateRender`), checkpoints, or human-in-the-loop interrupts.

**Don't mix and match.** Picking up `agent="<name>"` on the React provider commits you to CoAgent mode. If no real agent is registered server-side, you'll get `useAgent: Agent X not found` on page load — see [`08-debugging-runbook.md`](./08-debugging-runbook.md#useagent-error).

---

## The playbook (in order)

When you start a CopilotKit setup, work through these in sequence. Each numbered step links to a reference file with the deep dive:

1. **Decide the architecture** → [`01-architecture-decisions.md`](./01-architecture-decisions.md)
   - Standard chat or CoAgent?
   - Single-stack (Next-only) or full monorepo (Next + FastAPI)?
   - Mock-first eval strategy: yes/no.

2. **Lay out the monorepo** → [`02-monorepo-layout.md`](./02-monorepo-layout.md)
   - Directory tree, `.env` strategy, dev runner script.
   - Single source of truth for env vars.

3. **Pin dependencies that actually install** → [`03-dependency-pinning.md`](./03-dependency-pinning.md)
   - Real gotchas: `copilotkit` 0.1.40–0.1.87 blocks Python 3.13; `eslint-config-next 14` rejects eslint v9; `pydantic-core>=2.35` requirement.
   - Use compatible ranges, not exact pins, for the kickstarter; lockfile for production.

4. **Design every class single-purpose** → [`04-class-design.md`](./04-class-design.md)
   - One file = one class = one job.
   - Spec doc per class; PRs that change the class change the spec.

5. **Build the LLM provider abstraction** → [`05-llm-provider-pattern.md`](./05-llm-provider-pattern.md)
   - `LLMProvider` ABC + `MockProvider` (default) + real adapters (lazy-imported).
   - Symmetric across both layers: same `LLM_PROVIDER` env var picks the Next adapter and the Python provider.

6. **Build the action registry** → [`06-action-registry-pattern.md`](./06-action-registry-pattern.md)
   - `Action` wraps a typed Pydantic-validated handler.
   - One source of truth emits the OpenAI / Anthropic / CopilotKit JSON schemas.
   - `ActionRegistry.dispatch()` is the only entry point.

7. **Wire CopilotKit into both processes** → [`07-runtime-wiring.md`](./07-runtime-wiring.md)
   - Next route: `CopilotRuntime` + service adapter + `remoteEndpoints`.
   - FastAPI: `CopilotKitRemoteEndpoint` + `add_fastapi_endpoint`.
   - The two are the only files that touch the SDKs.

8. **Add the eval harness** → [`08-eval-framework.md`](./08-eval-framework.md)
   - Declarative YAML scenarios + pytest runner.
   - Mock provider keeps CI deterministic.

9. **Verify end-to-end** → [`09-debugging-runbook.md`](./09-debugging-runbook.md)
   - The bootstrap checklist (every box must check).
   - Common errors with one-line fixes.

10. **Document everything as you go** → [`10-docs-pattern.md`](./10-docs-pattern.md)
    - README + ARCHITECTURE + per-class specs.
    - Source-of-truth rule: docs and code change in the same commit.

---

## Boilerplate templates

Direct copy-paste files lives in [`templates/`](./templates/):

- `templates/backend-llm-base.py` — the `LLMProvider` ABC.
- `templates/backend-mock-provider.py` — deterministic mock.
- `templates/backend-action-base.py` — `Action` + `ActionResult`.
- `templates/backend-action-registry.py` — the registry.
- `templates/backend-runtime-mount.py` — FastAPI wiring.
- `templates/frontend-runtime-route.ts` — Next route with adapter selection.
- `templates/frontend-copilot-provider.tsx` — React `<CopilotProvider>`.
- `templates/eval-framework.py` — scenario runner.
- `templates/eval-scenario-template.yaml` — YAML scenario shape.
- `templates/env-example` — full `.env.example`.

These are **the actual files that ship in the kickstarter** — copying one into your project is a one-step bootstrap of that capability. Each has comments at the top explaining what to change.

---

## Hard rules (don't break these)

1. **One LLM-call location per project.** Either Next-side (standard chat) or Python-side (CoAgent), never both for the same conversation.
2. **One `.env` file** at the repo root. Both Next and FastAPI read it. Wire `dotenv` into `next.config.js` to make this work.
3. **Single-purpose classes**, named after the noun they own. `LLMProvider`, `ActionRegistry`, `EvalRunner` — not `Manager`, `Helper`, `Util`.
4. **Lazy-import vendor SDKs** in adapters. Keep the kickstarter unit-testable without `openai` / `anthropic` / `copilotkit` installed.
5. **Mock-first by default.** `LLM_PROVIDER=mock` must produce a working page and a working test suite without any keys.
6. **Provider-agnostic everywhere except the adapter file.** Never write `if provider == "openai"` outside the provider class.
7. **Spec doc per class.** A PR that adds a class adds a spec doc. A PR that changes a class's public surface updates the spec. CI can lint this if you wire it.
8. **Pin in `requirements.txt` / `package.json` with compatible ranges; lock for production.** Exact pins in `requirements.txt` are brittle when transitive deps shift (we hit copilotkit ↔ pydantic-core directly).
9. **Frequent, small commits with full messages.** Group by capability (backend, frontend, evals, docs) — not by file count.
10. **Document the architectural decision before writing code.** The first commit on a new repo is `README.md + ARCHITECTURE.md`, not source files.

---

## Quick bootstrap (zero-to-running)

The skill ships a complete project in [`bootstrap/`](./bootstrap/) and two scripts that copy it into a target directory. **No GitHub access required** — everything lives on your machine after the skill is installed.

### Windows (PowerShell)
```powershell
# 1. Scaffold
$target = "C:\path\to\my-new-app"
pwsh "$HOME\.claude\skills\copilotkit-setup\bootstrap.ps1" -Target $target
Set-Location $target

# 2. Backend (Terminal 1)
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# 3. Frontend (Terminal 2)
Set-Location $target\frontend
npm install
npm run dev

# 4. Open http://localhost:3000
```

### macOS / Linux
```bash
target=~/projects/my-new-app
bash "$HOME/.claude/skills/copilotkit-setup/bootstrap.sh" "$target"
cd "$target"

# Backend (Terminal 1)
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Frontend (Terminal 2)
cd "$target/frontend"
npm install
npm run dev
```

**What you get.** A 78-file project with:
- A working LangGraph CoAgent (`/agent/default`) that uses our `LLMProvider`.
- An action registry exposing `echo` + `get_weather` example actions.
- 17/17 unit tests passing (the 18th is `test_health` — needs the venv installed).
- Spec docs for every class.
- A working dev runner script.

**Total time on a clean machine.** ~5 minutes plus `npm install` (~3 min).

### What if I don't have the skill installed?

Then you can't bootstrap from this skill — but the bundled `bootstrap/` directory IS the entire project layout. If anyone on your team has it (or has a working copy of the kickstarter project), copy `skills/copilotkit-setup/bootstrap/*` into your new directory and start from RUNBOOK.md Step 2. See `RUNBOOK.md` "Appendix: Installing the skill" for full options.

### Templates (for piecewise adoption)

Direct copy-paste files for adding capabilities to an existing app live in [`templates/`](./templates/). Use these when you don't want a full kickstarter — just a single piece (an `LLMProvider`, an `ActionRegistry`, etc.):

- `templates/backend-llm-base.py` — the `LLMProvider` ABC.
- `templates/backend-mock-provider.py` — deterministic mock.
- `templates/backend-action-base.py` — `Action` + `ActionResult`.
- `templates/backend-action-registry.py` — the registry.
- `templates/backend-runtime-mount.py` — FastAPI wiring.
- `templates/backend-default-agent.py` — minimal LangGraph CoAgent.
- `templates/frontend-runtime-route.ts` — Next route with adapter selection.
- `templates/frontend-copilot-provider.tsx` — React `<CopilotProvider>`.
- `templates/eval-framework.py` — scenario runner.
- `templates/eval-scenario-template.yaml` — YAML scenario shape.
- `templates/env-example` — full `.env.example`.

---

## What "done" looks like

A finished CopilotKit setup is:

- [ ] Page loads with the chat sidebar (no `useAgent` red overlay).
- [ ] `LLM_PROVIDER=mock` works without any API keys.
- [ ] `LLM_PROVIDER=openai` + key produces real responses, no other code change required.
- [ ] At least one client action and one server action are registered and demonstrably callable from chat.
- [ ] At least one `useCopilotReadable` exposes app state to the LLM.
- [ ] `pytest` runs unit tests + eval scenarios green.
- [ ] `README.md`, `ARCHITECTURE.md`, and per-class specs exist and match the code.
- [ ] First commit is the doc set; subsequent commits are capability-grouped.

If any box is unchecked, see the corresponding reference file.
