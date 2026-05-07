# Runbook — execute in order

Numbered, sequential steps for getting this project from a fresh empty directory to running, plus the canonical workflows for everyday changes. Each step has a **Goal**, the **Commands** to run, the **Expected** output, and an **If it fails** pointer.

**This runbook does not depend on cloning a git repo.** Bootstrap scaffolds the project from a locally-bundled skill at `.github/skills/copilotkit-setup/` (or `~/.claude/skills/copilotkit-setup/` if you've installed it user-wide). If the skill isn't available yet, see the appendix at the bottom of this file.

If you're new, run **Phase A** (Steps 1–8) once. After that, **Phase B** (Steps 9–11) is your daily start; the rest are operations you reach for when needed.

> **Conventions in this doc**
> - Commands are **bash** (Linux container / macOS / Codespaces / WSL). PowerShell variants are listed where they differ meaningfully.
> - Default workspace path is `/workspace`. Replace with your container's mount point if it's something else.
> - "On failure → 09-debugging-runbook.md#X" refers to [`.github/skills/copilotkit-setup/09-debugging-runbook.md`](.github/skills/copilotkit-setup/09-debugging-runbook.md).

---

## Phase A — First-time setup (one-time)

### Step 1 — Scaffold the project from the skill

**Goal.** Create a fresh project directory with the complete layout. **No GitHub access required** — everything comes from the skill bundled on disk.

**Commands (bash):**
```bash
# Pick a target directory. The bootstrap will create it.
target=/workspace/my-new-app

# Run the skill's bootstrap from wherever the skill is installed.
bash .github/skills/copilotkit-setup/bootstrap.sh "$target"
#   - in another project? bash $OTHER/.github/skills/copilotkit-setup/bootstrap.sh ...
#   - user-wide install?  bash ~/.claude/skills/copilotkit-setup/bootstrap.sh ...

cd "$target"
```

**Commands (PowerShell):**
```powershell
$target = "C:\workspace\my-new-app"
pwsh .github\skills\copilotkit-setup\bootstrap.ps1 -Target $target
Set-Location $target
```

**Expected.** A new directory containing `README.md`, `RUNBOOK.md`, `ARCHITECTURE.md`, `backend/`, `frontend/`, `docs/`, `scripts/`, plus a fresh `git init` + initial commit. The bootstrap also copies `.env.example` → `.env` automatically.

**Flags.**
- `--force` (`-Force`): allow overwriting a non-empty target.
- `--no-git` (`-NoGit`): skip `git init` + initial commit.

**On failure.**
- *"bootstrap source not found"* → the skill isn't installed. See the **Appendix** at the bottom of this file for three install paths.
- *"Target is not empty"* → use `--force` or pick a fresh path.

**Time.** ~3s.

---

### Step 2 — Confirm the layout

**Goal.** Sanity-check before installing dependencies.

**Commands (bash):**
```bash
find . -type f -not -path "./.git/*" | wc -l        # ~75 files
test -f .env && test -d backend && test -d frontend && echo OK
grep '^LLM_PROVIDER=' .env                          # LLM_PROVIDER=mock
```

**Expected.** ~75 source files. `OK` printed. Defaults to `LLM_PROVIDER=mock` (page loads, chat returns `[mock] <message>` until you wire a real key — Step 13).

**On failure.** Missing files → re-run Step 1 with `--force`.

**Time.** ~5s.

---

### Step 3 — Create the Python virtualenv

**Goal.** Isolate backend deps from the system Python.

**Commands (bash):**
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
python --version
```

**Commands (PowerShell):**
```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version
```

**Expected.** Shell prompt now prefixed with `(.venv)`. `python --version` shows 3.11–3.13.

**On failure.**
- *"python: command not found"* → install Python 3.11+ (in Codespaces / dev containers, ensure the python feature is enabled in `devcontainer.json`).
- *PowerShell execution policy error* (Windows only) → run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once.

**Time.** ~15s.

---

### Step 4 — Install backend dependencies

**Goal.** Pull `fastapi`, `copilotkit`, `pydantic`, etc.

**Commands:**
```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

**Expected.** `Successfully installed copilotkit-0.1.88 ... pydantic-2.13.x ...`. Roughly 70 packages.

**On failure.**
- *"Could not find a version that satisfies the requirement copilotkit"* → see [`.github/skills/copilotkit-setup/03-dependency-pinning.md`](.github/skills/copilotkit-setup/03-dependency-pinning.md).
- *pydantic-core conflict* → same doc.

**Time.** ~60–120s.

---

### Step 5 — Verify backend tests pass

**Goal.** Sanity-check the install before touching the frontend.

**Commands:**
```bash
python -m pytest tests/ evals/ -q
```

**Expected.** `18 passed in <2s`.

**On failure.**
- *Import errors* → re-activate the venv (`source .venv/bin/activate`).
- *Specific test fails* → that test's failure message points at the broken module.

**Time.** ~3s.

---

### Step 6 — Install frontend dependencies

**Goal.** Pull `next`, `@copilotkit/*`, `react`, etc.

**Commands:**
```bash
cd ../frontend
npm install
```

**Expected.** `added 1336 packages` (varies by exact resolution).

**On failure.**
- *ERESOLVE eslint v9 vs v8* → see [`.github/skills/copilotkit-setup/03-dependency-pinning.md`](.github/skills/copilotkit-setup/03-dependency-pinning.md).
- *Cannot find module 'dotenv'* → `npm install dotenv`.

**Time.** ~3 minutes.

---

### Step 7 — Verify frontend type-checks

**Goal.** Catch TS errors before runtime.

**Commands:**
```bash
npm run typecheck
```

**Expected.** Exit code 0.

**Time.** ~10s.

---

### Step 8 — Confirm bootstrap

**Validation.**
- [ ] `.env` exists at repo root with `LLM_PROVIDER=mock`.
- [ ] `backend/.venv/` exists with `copilotkit`, `fastapi`, `pydantic` installed.
- [ ] `frontend/node_modules/` exists with `@copilotkit/runtime`.
- [ ] `pytest` was green (Step 5).
- [ ] `npm run typecheck` was green (Step 7).

If all five check, you're done with Phase A. **Phase B** is the daily start.

---

## Phase B — Daily dev (recurring)

### Step 9 — Start the backend

**Terminal 1 (keep open):**
```bash
cd /workspace/my-new-app/backend
source .venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

**Expected log:**
```
copilotkit.runtime.mount     provider=mock model=gpt-4o-mini actions=['echo', 'get_weather']
copilotkit.runtime.mounted   path=/copilotkit_remote
copilotkit.agent.mounted     path=/agent/default agent=default
backend.startup              version=0.1.0 provider=mock
INFO:     Uvicorn running on http://127.0.0.1:8000
```

**Validation:**
```bash
curl -s http://localhost:8000/health
```
returns `{"status":"ok","version":"0.1.0","provider":"mock"}`.

**On failure.**
- *Port 8000 in use* → see [`.github/skills/copilotkit-setup/09-debugging-runbook.md#errno-10048`](.github/skills/copilotkit-setup/09-debugging-runbook.md).
- *ImportError* → re-run Step 4.

---

### Step 10 — Start the frontend

**Terminal 2 (keep open):**
```bash
cd /workspace/my-new-app/frontend
npm run dev
```

**Expected:**
```
▲ Next.js 14.2.x
- Local:   http://localhost:3000
✓ Ready in <5s
```

First page request triggers a ~30s compile; subsequent requests are instant.

**On failure.**
- *Port 3000 in use* — kill the existing process or change port: `npm run dev -- -p 3001`.

---

### Step 11 — Smoke-test the integration

**Goal.** Confirm browser → Next route → Python backend works end-to-end.

**Commands (third terminal):**
```bash
# 1. Backend reachable
curl -s http://localhost:8000/health

# 2. Backend exposes the action set
curl -s -X POST http://localhost:8000/copilotkit_remote/info \
     -H 'Content-Type: application/json' -d '{"properties":{}}'

# 3. Backend's agent endpoint healthy
curl -s http://localhost:8000/agent/default/health

# 4. Frontend serves
curl -s -I http://localhost:3000 | head -1

# 5. Runtime route is wired (400 with JSON-RPC error = correctly receiving)
curl -s -X POST http://localhost:3000/api/copilotkit \
     -H 'Content-Type: application/json' -d '{}'
```

**Expected.**
1. `{"status":"ok",...}`
2. JSON listing actions including `echo` and `get_weather`.
3. `{"status":"ok","agent":{"name":"default"}}`
4. `HTTP/1.1 200`
5. JSON like `{"error":"invalid_request","message":"Missing method field"}` — means the route is wired.

**Validation in browser.** Open `http://localhost:3000` in a browser. You should see:
- "CopilotKit Kickstarter" header.
- Empty Todos panel.
- Right sidebar labelled "Kickstarter Copilot".
- **No red error overlay.**

If 1–5 pass and the page renders without overlay, the integration is live.

---

## Phase C — Operations (as needed)

### Step 12 — Run the eval suite

**Goal.** Verify scenario-level behavior.

**Commands (from `backend/`):**
```bash
# Pretty CLI report
python -m evals.runner

# Or via pytest (CI-friendly)
python -m pytest evals/ -q
```

**Expected.** `Eval report: 2/2 passed`.

**When to run.** Before every commit that touches `app/llm/`, `app/actions/`, or any prompt.

---

### Step 13 — Switch to a real LLM provider

**Goal.** Replace the mock with OpenAI or Anthropic so chat actually responds.

**Commands.** Edit `.env` at the repo root:
```dotenv
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
LLM_MODEL=gpt-4o-mini
```

**Restart both servers** (env is read at startup):
- Terminal 1: `Ctrl+C`, then re-run `uvicorn ...`.
- Terminal 2: `Ctrl+C`, then re-run `npm run dev`.

**Validation.** Open `http://localhost:3000`, type "hello" — you should get a real response. Backend logs show `provider=openai` (not `mock`).

**On failure.** No response → check `.env` is at repo root and Next was restarted.

---

### Step 14 — Add a server-side action

**Pattern.** Three additions, one place:

1. New file under `backend/app/actions/`:
   ```python
   # backend/app/actions/my_thing.py
   from pydantic import BaseModel, Field
   from app.actions.base import Action

   class MyParams(BaseModel):
       q: str = Field(description="Search query.")

   async def _handler(params: MyParams) -> dict:
       return {"hits": [...]}

   my_action = Action(name="my_thing", description="...",
                      parameters=MyParams, handler=_handler)
   ```
2. Register in `backend/app/actions/registry.py`:
   ```python
   from .my_thing import my_action
   def default_registry() -> ActionRegistry:
       return ActionRegistry(actions=[echo_action, weather_action, my_action])
   ```
3. Add a spec doc at `docs/classes/MyThingAction.md`.

**Validation:**
```bash
curl -s -X POST http://localhost:8000/copilotkit_remote/info \
     -H 'Content-Type: application/json' -d '{"properties":{}}' | grep my_thing
```

---

### Step 15 — Add a client-side action

```tsx
// frontend/components/actions/MyClientAction.tsx
"use client";
import { useCopilotAction } from "@copilotkit/react-core";

export function MyClientAction({ doSomething }: { doSomething: (x: string) => void }) {
  useCopilotAction({
    name: "doSomething",
    description: "...",
    parameters: [{ name: "x", type: "string", description: "...", required: true }],
    handler: async ({ x }: { x: string }) => {
      doSomething(x);
      return { ok: true };
    },
  });
  return null;
}
```

Mount it on the page next to other client actions. Frontend hot-reloads — no restart.

---

### Step 16 — Add a readable

```tsx
useCopilotReadable({
  description: "The currently-open document.",
  value: { docId, cursor },
});
```

**Rules.** Keep `value` small (every readable costs context tokens). Updates re-render and send the new state on the next turn.

---

### Step 17 — Add an eval scenario

```bash
cp .github/skills/copilotkit-setup/templates/eval-scenario-template.yaml \
   backend/evals/scenarios/03_my_check.yaml
$EDITOR backend/evals/scenarios/03_my_check.yaml
```

Edit `name`, `description`, `messages`, `expect`. See [`.github/skills/copilotkit-setup/08-eval-framework.md`](.github/skills/copilotkit-setup/08-eval-framework.md).

**Validation:**
```bash
cd backend
python -m evals.runner       # picks up the new scenario
python -m pytest evals/ -q   # parametrized run
```

---

### Step 18 — Add a new LLM provider

1. Backend: copy `backend/app/llm/openai_provider.py` → `<name>_provider.py`, swap SDK calls, register in `app/llm/__init__.py`'s `_REGISTRY`.
2. Backend: add the name to `app/config.py:ProviderName`.
3. Backend: pin the SDK in `backend/requirements.txt`.
4. Frontend: add a branch in `buildServiceAdapter()` in `frontend/app/api/copilotkit/route.ts`.
5. Docs: add `docs/classes/<Name>Provider.md`. Update `docs/llm-providers.md`.

See [`.github/skills/copilotkit-setup/05-llm-provider-pattern.md`](.github/skills/copilotkit-setup/05-llm-provider-pattern.md).

---

### Step 19 — Run before-commit checks

```bash
# Backend
cd backend
source .venv/bin/activate
ruff check .
mypy app/
python -m pytest tests/ evals/ -q

# Frontend
cd ../frontend
npm run lint
npm run typecheck
npm test
```

**All four must exit 0.** Any fail blocks the commit.

---

### Step 20 — Commit and push

```bash
cd ..             # repo root
git status        # eyeball: only intended files
git add <specific-files>   # avoid `git add .` to keep secrets out
git commit -m "Capability: short headline

Why this change. What it enables. What it doesn't change.

Verified: <how you checked> = <result>.
"
git push origin main
```

**Rules.**
- Group commits by capability, not file count.
- Include a "Verified:" line.
- Spec doc updates land in the same commit as the code change.

---

## Phase D — Production prep

### Step 21 — Generate lockfiles

```bash
# Python
cd backend
source .venv/bin/activate
pip freeze | sort > requirements.lock

# Node lockfile (frontend/package-lock.json) — already exists; commit it.
```

Production installs use `pip install -r requirements.lock` and `npm ci` (not `install`).

---

### Step 22 — Frontend production build

```bash
cd frontend
npm run build
```

**Expected.** A `.next/` directory with optimized output, no errors.

---

### Step 23 — Backend production process

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

**Validation.** All four worker PIDs log `backend.startup`.

---

### Step 24 — Production smoke

```bash
curl https://your-prod.example.com/health
curl -I https://your-prod.example.com
```

Both 200. Tail logs for one minute — no unexpected errors.

---

## Phase E — Recovery

### Step 25 — Cold restart

```bash
# Kill anything on the dev ports
fuser -k 8000/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

# Re-run Steps 9 + 10
```

**Validation.** Step 11 smoke passes.

---

### Step 26 — Reinstall from scratch

```bash
# Backend
cd backend
rm -rf .venv
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Frontend
cd ../frontend
rm -rf node_modules .next package-lock.json
npm install
```

**Validation.** Re-run Step 5 (`pytest`) and Step 7 (`npm run typecheck`).

---

### Step 27 — Hit a bug not covered here?

1. Check [`.github/skills/copilotkit-setup/09-debugging-runbook.md`](.github/skills/copilotkit-setup/09-debugging-runbook.md) — symptom-to-fix table.
2. Read the actual log output, not the summary.
3. If genuinely new, add to the debugging runbook in the same PR as your fix.

---

## Quick reference — one-shot bootstrap

For a colleague who just wants commands to copy-paste:

```bash
# 1. Scaffold from the locally-bundled skill (no GitHub access required)
target=/workspace/my-new-app
bash .github/skills/copilotkit-setup/bootstrap.sh "$target"
cd "$target"

# 2. Backend (Terminal 1)
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m pytest -q
uvicorn app.main:app --reload --port 8000

# 3. Frontend (Terminal 2)
cd "$target/frontend"
npm install
npm run dev

# 4. Browser
xdg-open http://localhost:3000   # or `open` on macOS
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
- [ ] Spec doc updated if class surface changed (rule from [`10-docs-pattern.md`](.github/skills/copilotkit-setup/10-docs-pattern.md)).
- [ ] CHANGELOG entry added if user-visible behavior changed.

### Before merging to main
- [ ] CI green (when wired).
- [ ] At least one new eval scenario for the new behavior.
- [ ] No secrets in the diff (`git diff --staged | grep -iE 'key|secret|token'`).

---

## Appendix — Installing the `copilotkit-setup` skill

Step 1 of this runbook expects the skill at `.github/skills/copilotkit-setup/` (project-relative) or `~/.claude/skills/copilotkit-setup/` (user-wide). If you don't have it yet:

### Option A — Vendor into the repo (recommended for teams)

Copy the skill from any project that already has it:

```bash
src=/path/to/existing-project/.github/skills/copilotkit-setup
mkdir -p .github/skills
cp -a "$src" .github/skills/copilotkit-setup
git add .github/skills/copilotkit-setup
git commit -m "Adopt copilotkit-setup skill"
```

### Option B — Install user-wide (one machine, many projects)

```bash
src=/path/to/existing-project/.github/skills/copilotkit-setup
mkdir -p ~/.claude/skills
cp -a "$src" ~/.claude/skills/copilotkit-setup
```

Once installed, every project on this machine can call:
```bash
bash ~/.claude/skills/copilotkit-setup/bootstrap.sh /workspace/new-project
```

### Option C — Run in-place from a checkout

If you have the kickstarter project cloned anywhere on disk, skip the install entirely and run the bootstrap from there:

```bash
bash /path/to/kickstarter/.github/skills/copilotkit-setup/bootstrap.sh /workspace/new-project
```

### Verify the install

```bash
test -f .github/skills/copilotkit-setup/SKILL.md         && echo OK
test -f .github/skills/copilotkit-setup/bootstrap.sh     && echo OK
test -d .github/skills/copilotkit-setup/bootstrap        && echo OK
test -f .github/skills/copilotkit-setup/bootstrap/README.md && echo OK
```

All four must print `OK`. Once installed, **return to Step 1 of this runbook**.
