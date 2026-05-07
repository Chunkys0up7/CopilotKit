# 02 — Monorepo layout

The exact tree the kickstarter uses. Copy it; don't reinvent.

```
myapp/
├── README.md                      <- project overview, quickstart
├── ARCHITECTURE.md                <- system design, request flow
├── CHANGELOG.md                   <- Keep-a-Changelog format
├── .env.example                   <- documented env vars
├── .env                           <- (gitignored) actual values
├── .gitignore                     <- Python + Node + IDE patterns
│
├── docs/
│   ├── classes/
│   │   ├── INDEX.md               <- map of every class to its spec
│   │   ├── <ClassName>.md         <- one per class (template below)
│   │   └── …
│   ├── ui-capabilities.md         <- which CopilotKit components shipped
│   ├── actions-and-readables.md   <- how to add new actions/readables
│   ├── llm-providers.md           <- how to add a new provider
│   ├── eval-framework.md          <- how scenarios run
│   └── complexity.md              <- Big-O for hot paths
│
├── backend/
│   ├── pyproject.toml             <- semver, ruff, mypy, pytest config
│   ├── requirements.txt           <- compatible-range pins
│   ├── .venv/                     <- (gitignored)
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                <- FastAPI entrypoint
│   │   ├── config.py              <- pydantic-settings
│   │   ├── logging_config.py      <- structlog wiring
│   │   ├── runtime.py             <- mount() — only file that imports copilotkit SDK
│   │   ├── llm/
│   │   │   ├── __init__.py        <- get_provider() factory + _REGISTRY
│   │   │   ├── base.py            <- LLMProvider ABC + DTOs
│   │   │   ├── mock_provider.py
│   │   │   ├── openai_provider.py
│   │   │   └── anthropic_provider.py
│   │   ├── actions/
│   │   │   ├── __init__.py
│   │   │   ├── base.py            <- Action + ActionResult
│   │   │   ├── registry.py        <- ActionRegistry + default_registry()
│   │   │   └── examples.py        <- echo, get_weather (delete + add your own)
│   │   └── agents/
│   │       ├── __init__.py
│   │       └── demo_agent.py      <- LangGraph-shaped placeholder
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py
│   │   ├── test_llm_providers.py
│   │   ├── test_actions.py
│   │   └── test_health.py
│   └── evals/
│       ├── __init__.py
│       ├── framework.py           <- EvalCase / EvalRunner / EvalReport
│       ├── runner.py              <- python -m evals.runner
│       ├── test_scenarios.py      <- pytest entrypoint (parametrized)
│       └── scenarios/
│           ├── 01_greeting.yaml
│           └── 02_tool_call.yaml
│
├── frontend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── next.config.js             <- loads repo-root .env via dotenv
│   ├── next-env.d.ts
│   ├── vitest.config.ts
│   ├── vitest.setup.ts
│   ├── node_modules/              <- (gitignored)
│   ├── .next/                     <- (gitignored)
│   ├── app/                       <- App Router
│   │   ├── layout.tsx             <- wraps in <CopilotProvider>
│   │   ├── page.tsx               <- demo home page
│   │   ├── globals.css
│   │   └── api/
│   │       └── copilotkit/
│   │           └── route.ts       <- service adapter + remoteEndpoints
│   ├── components/
│   │   ├── CopilotProvider.tsx
│   │   ├── ChatPanel.tsx          <- example useCopilotReadable
│   │   └── actions/
│   │       └── ExampleActions.tsx <- example useCopilotAction
│   ├── lib/
│   │   └── readables.ts           <- example local state hook
│   └── __tests__/
│       └── readables.test.ts
│
└── scripts/
    └── dev.ps1                    <- one-shot dev runner (Windows)
```

---

## Key invariants

### One `.env` for both processes

Don't have two env files (one per process). Wire the Next side via `dotenv` in `next.config.js`:

```js
// frontend/next.config.js
const path = require("node:path");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
```

The Python side reads it via `pydantic-settings` pointed at `<repo-root>/.env`.

### `.gitignore` essentials

```gitignore
# Python
__pycache__/
*.py[cod]
.venv/
.pytest_cache/
.mypy_cache/
.coverage

# Node
node_modules/
.next/
out/
*.tsbuildinfo
next-env.d.ts

# Env
.env
.env.local
*.pem
*.key

# IDE / OS
.vscode/
.idea/
.DS_Store
Thumbs.db
*.log

# Eval artifacts
evals/runs/
evals/.cache/
```

### Why `backend/` and `frontend/` are siblings (not nested)

- Both run independently with their own toolchain.
- Lockfiles (`package-lock.json`, optionally `requirements.lock`) live next to the manifest they lock.
- A future PNPM/Turborepo workspace setup can adopt this layout unchanged.
- Docker builds can target one or the other without confusing context.

### Why `evals/` is *inside* `backend/`

- Evals exercise the Python `LLMProvider` abstraction — they're Python code.
- Pytest discovers them in the same run as unit tests.
- They can import `app.*` directly without packaging gymnastics.

If you keep evals language-agnostic (e.g. a YAML lib used from multiple languages), pull `evals/scenarios/` to the repo root with separate runners per language. **Don't do this preemptively.**

---

## What goes in `docs/classes/`

One Markdown file per class, named `<ClassName>.md` (or `<MyHook>.md` for hooks). Use this template:

```markdown
# `<ClassName>`

**File:** [`path/to/file.py`](../../path/to/file.py)

## Purpose
One sentence.

## Public surface

| Member | Signature | Notes |
|---|---|---|

## Collaborators
- **Imports:** …
- **Imported by:** …

## Complexity
- O(…) for hot path X.

## Test coverage
- `tests/test_foo.py::test_bar`

## Failure modes
- What fails, how it surfaces.
```

Keep `docs/classes/INDEX.md` updated. CI can lint that every class has a spec — see [`10-docs-pattern.md`](./10-docs-pattern.md).

---

## Bootstrap commands (verified)

These are the exact commands that work, in order. Each is fast (<1 min except `npm install`).

```bash
# 1. Init
cd myapp && git init && touch README.md ARCHITECTURE.md CHANGELOG.md .env.example
# (paste from skill templates)

# 2. Backend
mkdir -p backend/app/{llm,actions,agents} backend/tests backend/evals/scenarios
cd backend
python -m venv .venv && . .venv/Scripts/activate    # macOS/Linux: . .venv/bin/activate
# Copy templates/requirements.txt to ./requirements.txt
pip install -r requirements.txt
# Copy templates/backend-*.py into app/
touch app/__init__.py app/llm/__init__.py app/actions/__init__.py app/agents/__init__.py
touch tests/__init__.py evals/__init__.py
pytest tests/ -q                                    # should pass

# 3. Frontend
cd ../frontend
# Two options:
#   (a) npx copilotkit@latest init --next-app-router . — interactive
#   (b) npm init -y && manually populate from templates/frontend-*
npm install                                         # see 03-dependency-pinning.md
npm run dev                                         # http://localhost:3000

# 4. Wire the Python remote endpoint
# (uvicorn app.main:app --reload --port 8000 in another terminal)

# 5. Smoke
curl http://localhost:8000/health
curl -I http://localhost:3000

# 6. Eval scaffold
cd ../backend
python -m evals.runner                              # 0/0 passed (until you add scenarios)
```

---

## Working in another project

To add CopilotKit to an existing app:

1. **Don't restructure the app** to match this monorepo. Adapt:
   - Drop `backend/` next to your existing backend, or merge into it.
   - Drop the `app/api/copilotkit/route.ts` into your existing Next app.
2. **Copy `.env.example` deltas** — don't replace your env file.
3. **Use the templates piecewise** — `LLMProvider` + `Action` + `ActionRegistry` are independent additions.
4. **Run the bootstrap checklist** in [`09-debugging-runbook.md`](./09-debugging-runbook.md) once everything's in place.
