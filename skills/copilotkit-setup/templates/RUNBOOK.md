# Runbook — execute in order

Numbered, sequential steps for getting this project from clean checkout to running, plus the canonical workflows for everyday changes. Each step has a **Goal**, the **Commands** to run, the **Expected** output, and an **If it fails** pointer.

If you're new to the repo, run **Phase A** (steps 1–8) once. After that, **Phase B** (steps 9–11) is your daily start; the rest are operations you reach for when needed.

> **Conventions in this doc**
> - Commands are PowerShell (Windows). For macOS/Linux, swap `\Scripts\Activate.ps1` → `bin/activate` and `pwsh` paths accordingly.
> - All paths are absolute from the repo root unless prefixed with `./`.
> - "On failure → 09-debugging-runbook.md#X" refers to [`skills/copilotkit-setup/09-debugging-runbook.md`](skills/copilotkit-setup/09-debugging-runbook.md).

---

## Phase A — First-time setup (one-time)

### Step 1 — Clone the repo

**Goal.** Get the source on disk.
**Commands.**
```powershell
git clone https://github.com/Chunkys0up7/CopilotKit.git
Set-Location CopilotKit
```
**Expected.** A `CopilotKit/` directory with `README.md`, `backend/`, `frontend/`, `docs/`, `skills/`.
**On failure.** Auth issue with GitHub — `gh auth login` or set up an SSH key.
**Time.** ~10s.

---

### Step 2 — Create your `.env`

**Goal.** Tell both processes how to talk to LLMs.
**Commands.**
```powershell
Copy-Item .env.example .env
```
**Expected.** A `.env` file at the repo root. Defaults to `LLM_PROVIDER=mock` (page loads, chat is a no-op until you add a real key — Step 13).
**Validation.**
```powershell
Get-Content .env | Select-String "LLM_PROVIDER"
```
Should print `LLM_PROVIDER=mock`.
**On failure.** No `.env.example` → you're on the wrong branch; `git checkout main`.
**Time.** ~5s.

---

### Step 3 — Create the Python virtualenv

**Goal.** Isolate backend deps from your global Python.
**Commands.**
```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version
```
**Expected.** Shell prompt now prefixed with `(.venv)`. `python --version` shows 3.11–3.13.
**On failure.**
- *"python: command not found"* → install Python 3.11+ from python.org.
- *PowerShell execution policy error* → run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once.
**Time.** ~15s.

---

### Step 4 — Install backend dependencies

**Goal.** Pull `fastapi`, `copilotkit`, `pydantic`, etc.
**Commands.**
```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
```
**Expected.** Last line: `Successfully installed copilotkit-0.1.88 ... pydantic-2.13.x ...`. Roughly 70 packages.
**On failure.**
- *"Could not find a version that satisfies the requirement copilotkit"* → see [`skills/copilotkit-setup/03-dependency-pinning.md#python--copilotkit-and-python-313`](skills/copilotkit-setup/03-dependency-pinning.md).
- *pydantic-core conflict* → same doc, same section.
**Time.** ~60–120s.

---

### Step 5 — Verify backend tests pass

**Goal.** Sanity-check the install before touching the frontend.
**Commands.**
```powershell
python -m pytest tests/ evals/ -q
```
**Expected.** `18 passed in <2s`.
**Validation criterion.** Exit code 0; "passed" count matches the number of test functions in `tests/` + scenarios in `evals/scenarios/`.
**On failure.**
- *Import errors* → reactivate the venv (`.\.venv\Scripts\Activate.ps1`), re-run.
- *Specific test fails* → that test's failure message points at the broken module; fix or `git status` to find local edits.
**Time.** ~3s.

---

### Step 6 — Install frontend dependencies

**Goal.** Pull `next`, `@copilotkit/*`, `react`, etc.
**Commands.**
```powershell
Set-Location ..\frontend
npm install
```
**Expected.** `added 1336 packages, ... in <3m`. May warn about deprecated `uuid@10` and `eslint@8.57.1` — both intentional, see Step 9 of the architecture decisions doc.
**On failure.**
- *ERESOLVE eslint v9 vs v8* → see [`skills/copilotkit-setup/03-dependency-pinning.md#frontend--eslint-config-next-rejects-eslint-v9`](skills/copilotkit-setup/03-dependency-pinning.md).
- *Cannot find module 'dotenv'* → `npm install dotenv`.
**Time.** ~3 minutes.

---

### Step 7 — Verify frontend type-checks

**Goal.** Catch TS errors before they hit you at runtime.
**Commands.**
```powershell
npm run typecheck
```
**Expected.** Exit code 0, no output (or "Found 0 errors").
**On failure.** Most likely a CopilotKit version mismatch — see [`skills/copilotkit-setup/09-debugging-runbook.md#module-copilotkitruntime-has-no-exported-member-openaiadapter`](skills/copilotkit-setup/09-debugging-runbook.md).
**Time.** ~10s.

---

### Step 8 — Confirm the bootstrap

**Goal.** Last gate before "ready to run".
**Validation.**
- [ ] `.env` exists at repo root with `LLM_PROVIDER=mock`.
- [ ] `backend/.venv/` exists with `copilotkit`, `fastapi`, `pydantic` installed.
- [ ] `frontend/node_modules/` exists with `@copilotkit/runtime`.
- [ ] `pytest` was green.
- [ ] `npm run typecheck` was green.

If all five check, you're done with Phase A. **Phase B** is the daily start.

---

## Phase B — Daily dev (recurring)

### Step 9 — Start the backend

**Goal.** Bring up FastAPI on port 8000.
**Terminal 1 (keep this open):**
```powershell
Set-Location C:\Users\camer\Projects\CopilotKit\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```
**Expected.** Log lines:
```
copilotkit.runtime.mount     provider=mock model=gpt-4o-mini actions=['echo', 'get_weather']
copilotkit.runtime.mounted   path=/copilotkit_remote
backend.startup              version=0.1.0 provider=mock
INFO:     Uvicorn running on http://127.0.0.1:8000
```
**Validation.**
```powershell
Invoke-RestMethod http://localhost:8000/health
```
returns `{ status = "ok"; version = "0.1.0"; provider = "mock" }`.
**On failure.**
- *Port 8000 in use* → see [`skills/copilotkit-setup/09-debugging-runbook.md#errno-10048`](skills/copilotkit-setup/09-debugging-runbook.md).
- *ImportError* → re-run Step 4.

---

### Step 10 — Start the frontend

**Goal.** Bring up Next.js on port 3000.
**Terminal 2 (keep this open):**
```powershell
Set-Location C:\Users\camer\Projects\CopilotKit\frontend
npm run dev
```
**Expected.** Log:
```
▲ Next.js 14.2.x
- Local:   http://localhost:3000
✓ Ready in <5s
```
First page request triggers a ~30s compile; subsequent requests are instant.
**On failure.**
- *Port 3000 in use* — kill the existing process or change the port: `npm run dev -- -p 3001`.
- *Cannot find module 'dotenv'* → `npm install dotenv`.

---

### Step 11 — Smoke-test the integration

**Goal.** Confirm browser → Next route → Python backend works end-to-end.
**Commands (third terminal or in your browser):**
```powershell
# 1. Backend reachable
curl http://localhost:8000/health

# 2. Backend exposes the action set
curl http://localhost:8000/copilotkit_remote/agents/info

# 3. Frontend serves
curl -I http://localhost:3000

# 4. Runtime route is wired (400 with JSON-RPC error = correctly receiving)
curl -Method POST -Uri http://localhost:3000/api/copilotkit -ContentType "application/json" -Body "{}"
```
**Expected.**
1. `{"status":"ok",...}`.
2. JSON listing actions including `echo` and `get_weather`.
3. `HTTP/1.1 200`.
4. JSON like `{"error":"invalid_request","message":"Missing method field"}` and HTTP 400 (means route is wired and just rejecting the empty body).
**Validation.** Open `http://localhost:3000` in a browser. You should see:
- "CopilotKit Kickstarter" header.
- Empty Todos panel.
- Right sidebar labelled "Kickstarter Copilot" with a chat input.
- **No red error overlay.**

If 1–4 pass and the page renders without overlay, the integration is live.

---

## Phase C — Operations (as needed)

Pick the operation you need; each is independent.

### Step 12 — Run the eval suite

**Goal.** Verify scenario-level behavior (prompt regressions, action-pipeline contracts).
**Commands (from `backend/`).**
```powershell
# Pretty CLI report
python -m evals.runner

# Or via pytest (CI-friendly)
python -m pytest evals/ -q
```
**Expected.** `Eval report: 2/2 passed` (greeting + weather_tool_call).
**When to run.** Before every commit that touches `app/llm/`, `app/actions/`, or any prompt.
**Adding a scenario.** See Step 17.

---

### Step 13 — Switch to a real LLM provider

**Goal.** Replace the mock with OpenAI or Anthropic so chat actually responds.
**Commands.**
```powershell
# Edit .env at repo root
notepad ..\.env
```
Set:
```dotenv
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
LLM_MODEL=gpt-4o-mini
```
(Or `anthropic` + `ANTHROPIC_API_KEY` + `claude-sonnet-4-6`.)

**Restart both servers** (env is read at startup):
- Terminal 1: `Ctrl+C`, then re-run `uvicorn ...`.
- Terminal 2: `Ctrl+C`, then re-run `npm run dev`.

**Validation.** Open `http://localhost:3000`, type "hello" in the sidebar — you should get a real response. Backend logs should show `provider=openai` (not `mock`).
**On failure.**
- *No response, console warns "OPENAI_API_KEY missing"* → key not loaded; check `.env` is at repo root (not `frontend/.env.local`); confirm `next.config.js` has the `dotenv` line.
- *401 from OpenAI* → bad key.

---

### Step 14 — Add a server-side action

**Goal.** Expose a new Python function to the LLM.
**Pattern.** Three additions, one place:

1. Define params + handler + `Action` in a new file under `backend/app/actions/`:
   ```python
   # backend/app/actions/my_thing.py
   from pydantic import BaseModel, Field
   from app.actions.base import Action

   class MyParams(BaseModel):
       q: str = Field(description="Search query.")

   async def _handler(params: MyParams) -> dict:
       return {"hits": [...]}  # your logic

   my_action = Action(name="my_thing", description="...",
                      parameters=MyParams, handler=_handler)
   ```
2. Register in `backend/app/actions/registry.py`:
   ```python
   from .my_thing import my_action
   def default_registry() -> ActionRegistry:
       return ActionRegistry(actions=[echo_action, weather_action, my_action])
   ```
3. Add a spec doc at `docs/classes/MyThingAction.md` (see template in [`skills/copilotkit-setup/04-class-design.md`](skills/copilotkit-setup/04-class-design.md)).

**Validation.**
```powershell
# Backend hot-reloads (uvicorn --reload). Confirm:
curl http://localhost:8000/copilotkit_remote/agents/info
# my_thing should appear in the action list

# Unit test it directly:
python -c "from app.actions import default_registry; import asyncio; \
  print(asyncio.run(default_registry().get('my_thing').call({'q':'test'})))"
```

**Time.** 5–15 minutes.

---

### Step 15 — Add a client-side action

**Goal.** Let the LLM call into React state / DOM / browser APIs.
**Pattern.** Add a `useCopilotAction` registration. Lives in a registration component (returns `null`).

```tsx
// frontend/components/actions/MyClientAction.tsx
"use client";
import { useCopilotAction } from "@copilotkit/react-core";

export function MyClientAction({ doSomething }: { doSomething: (x: string) => void }) {
  useCopilotAction({
    name: "doSomething",
    description: "Sentence the LLM will read.",
    parameters: [
      { name: "x", type: "string", description: "...", required: true },
    ],
    handler: async ({ x }: { x: string }) => {
      doSomething(x);
      return { ok: true };
    },
  });
  return null;
}
```

Mount it on the page next to your other client actions. The frontend hot-reloads — no restart needed.

**Validation.** Open dev tools console, type a prompt that should trigger it, watch for the action call.

**Time.** ~5 minutes.

---

### Step 16 — Add a readable (app state visible to the LLM)

**Goal.** Give the LLM context about what's on screen.
```tsx
useCopilotReadable({
  description: "The currently-open document.",
  value: { docId, cursor },
});
```
**Rules.** Keep `value` small (every readable costs context tokens). Update lives — `value` re-evaluates each render and the new state is sent on the next turn.

**Validation.** Ask the chat about the readable's content; if the LLM responds with current values, it's wired.

---

### Step 17 — Add an eval scenario

**Goal.** Lock in a behavior you care about (regression test).
**Commands.**
```powershell
# 1. Copy the template
Copy-Item skills/copilotkit-setup/templates/eval-scenario-template.yaml `
          backend/evals/scenarios/03_my_check.yaml
notepad backend\evals\scenarios\03_my_check.yaml
```
Edit `name`, `description`, `messages`, `expect`. See [`08-eval-framework.md`](skills/copilotkit-setup/08-eval-framework.md) for fields.

**Validation.**
```powershell
Set-Location backend
python -m evals.runner       # should pick up your new scenario
python -m pytest evals/ -q   # should include it in the parametrized run
```

---

### Step 18 — Add a new LLM provider

**Goal.** Add a vendor (e.g. Groq, Gemini) to both layers.
**Steps.**
1. Backend: copy `backend/app/llm/openai_provider.py` to `<name>_provider.py`, swap the SDK calls, register in `app/llm/__init__.py`'s `_REGISTRY`.
2. Backend: add the provider name to `app/config.py:ProviderName` literal union.
3. Backend: pin the SDK in `backend/requirements.txt`.
4. Frontend: add a branch in `buildServiceAdapter()` in `frontend/app/api/copilotkit/route.ts`.
5. Docs: add `docs/classes/<Name>Provider.md`. Update `docs/llm-providers.md` table.

See [`05-llm-provider-pattern.md`](skills/copilotkit-setup/05-llm-provider-pattern.md) for the deep dive.

**Validation.** `LLM_PROVIDER=<name>` in `.env`, restart, eyeball chat works.

---

### Step 19 — Run before-commit checks

**Goal.** Don't ship broken code.
**Commands.**
```powershell
# Backend
Set-Location backend
.\.venv\Scripts\Activate.ps1
ruff check .                    # lint
mypy app/                       # type-check
python -m pytest tests/ evals/ -q

# Frontend
Set-Location ..\frontend
npm run lint
npm run typecheck
npm test                        # vitest
```
**All four** must exit 0. Any fail blocks the commit.
**On failure.** Fix the specific error and re-run.

---

### Step 20 — Commit and push

**Goal.** Land a coherent change with a useful message.
**Commands.**
```powershell
Set-Location ..             # repo root
git status                  # eyeball: only intended files
git add <specific-files>    # avoid `git add .` to keep secrets out
git commit -m "Capability: short headline

Why this change. What it enables. What it doesn't change.

Verified: <how you checked> = <result>.

Co-Authored-By: ...
"
git push origin main
```
**Rules from the design principles.**
- Group commits by capability, not by file count.
- Include a "Verified:" line citing the test you ran.
- Spec doc updates land in the same commit as the code change.
**On failure.** `git push` rejected → someone else pushed; `git pull --rebase`, re-run Step 19.

---

## Phase D — Production prep (when you're ready)

### Step 21 — Generate lockfiles

**Goal.** Reproducible builds.
**Commands.**
```powershell
# Python lockfile
Set-Location backend
.\.venv\Scripts\Activate.ps1
pip freeze | Sort-Object > requirements.lock

# Node lockfile already exists at frontend/package-lock.json — commit it.
```
**Validation.** Both lockfiles are committed. Production installs use `pip install -r requirements.lock` and `npm ci` (not `install`).

---

### Step 22 — Frontend production build

**Goal.** Confirm the app builds for prod.
**Commands.**
```powershell
Set-Location frontend
npm run build
```
**Expected.** A `.next/` directory with the optimized output, no errors.
**On failure.** Almost always a TS or environment issue caught at build time but not at typecheck — read the error.

---

### Step 23 — Backend production process

**Goal.** Run uvicorn with multiple workers (no `--reload`).
**Commands.**
```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```
**Validation.** All four worker PIDs log `backend.startup` and `Uvicorn running`.

---

### Step 24 — Production smoke

**Goal.** Confirm the deployed pair behaves like local.
**Commands.**
```powershell
curl https://your-prod.example.com/health
curl -I https://your-prod.example.com         # frontend
```
**Validation.** Both 200. Tail logs for one minute — no unexpected errors.

---

## Phase E — Recovery (when something breaks)

### Step 25 — Cold restart

**Goal.** Eliminate stale state.
**Commands.**
```powershell
# Kill anything on the dev ports
Get-Process | Where-Object { $_.Id -in @((Get-NetTCPConnection -LocalPort 3000,8000 -ErrorAction SilentlyContinue).OwningProcess) } | Stop-Process -Force

# Re-run Steps 9 + 10
```
**Validation.** Step 11 smoke passes.

---

### Step 26 — Reinstall from scratch

**Goal.** Recover from a corrupt env.
**Commands.**
```powershell
# Backend
Set-Location backend
Remove-Item -Recurse -Force .venv
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Frontend
Set-Location ..\frontend
Remove-Item -Recurse -Force node_modules, .next, package-lock.json
npm install
```
**Validation.** Re-run Step 5 (`pytest`) and Step 7 (`npm run typecheck`).

---

### Step 27 — Hit a bug not covered here?

1. Check [`skills/copilotkit-setup/09-debugging-runbook.md`](skills/copilotkit-setup/09-debugging-runbook.md) — the symptom-to-fix table.
2. Read the actual log output, not the summary.
3. If genuinely new, add to the debugging runbook in the same PR as your fix.

---

## Quick reference — one-shot bootstrap

For a colleague who just wants commands to copy-paste:

```powershell
git clone https://github.com/Chunkys0up7/CopilotKit.git
Set-Location CopilotKit
Copy-Item .env.example .env

# Backend (Terminal 1)
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m pytest -q
uvicorn app.main:app --reload --port 8000

# Frontend (Terminal 2)
Set-Location frontend
npm install
npm run dev

# Browser
Start-Process http://localhost:3000
```

Total elapsed: ~5 minutes (excluding `npm install`'s 3-minute download).

---

## Checklists

### Before starting work
- [ ] `git pull origin main`
- [ ] `git status` → clean
- [ ] Both servers up (Steps 9+10)
- [ ] Step 11 smoke green

### Before committing
- [ ] Step 19 — all four checks pass.
- [ ] Spec doc updated if class surface changed (rule from [`10-docs-pattern.md`](skills/copilotkit-setup/10-docs-pattern.md)).
- [ ] CHANGELOG entry added if user-visible behavior changed.

### Before merging to main
- [ ] CI green (when wired).
- [ ] At least one new eval scenario for the new behavior.
- [ ] No secrets in the diff (`git diff --staged | grep -i 'key\|secret\|token'`).
