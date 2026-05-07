# 09 — Debugging runbook

Every error we hit, what it means, and the one-line fix. When something breaks, find your symptom here first.

---

## The bootstrap checklist

Run these in order. Each must pass before the next will work.

```bash
# 1. Python deps installed
cd backend && .venv/Scripts/python.exe -c "import copilotkit, fastapi, pydantic; print('ok')"

# 2. Backend tests pass (without SDK-dependent integration test)
.venv/Scripts/python.exe -m pytest tests/ evals/ -m "not integration" -q

# 3. Backend tests pass (with SDK)
.venv/Scripts/python.exe -m pytest tests/ evals/ -q

# 4. Backend boots
.venv/Scripts/python.exe -m uvicorn app.main:app --port 8000 &
curl http://localhost:8000/health    # → {"status":"ok",...}

# 5. Backend remote endpoint exposes actions
curl http://localhost:8000/copilotkit_remote/agents/info    # → JSON with action names

# 6. Frontend deps installed
cd ../frontend && node -e "require('@copilotkit/runtime'); require('next')"

# 7. Frontend builds (catches type errors)
npm run typecheck     # or: tsc --noEmit

# 8. Frontend boots
npm run dev &
curl -I http://localhost:3000     # → HTTP/1.1 200

# 9. Browser smoke
# Open http://localhost:3000 — sidebar visible, no red error overlay
```

If you get past step 9, the wiring is correct. Failures at each step have specific fixes below.

---

## Errors and fixes

### `useAgent: Agent 'demo' not found after runtime sync`

**Cause:** The React provider has `agent="demo"` but no real agent is registered server-side. Passing metadata-only dicts (`{name: "demo", description: "..."}`) to `CopilotKitRemoteEndpoint(agents=...)` doesn't count — the SDK expects actual agent instances.

**Fix:** One of two paths:

1. **Drop CoAgent mode** (use standard chat):
   ```tsx
   // frontend/components/CopilotProvider.tsx
   <CopilotKit runtimeUrl="/api/copilotkit">  // no `agent` prop
     {children}
   </CopilotKit>
   ```
   And pass `agents=[]` server-side.

2. **Build a real LangGraph agent:**
   ```python
   from copilotkit import LangGraphAgent
   from langgraph.graph import StateGraph

   graph = StateGraph(MyState).compile()
   demo_agent = LangGraphAgent(name="demo", description="...", graph=graph)
   endpoint = CopilotKitRemoteEndpoint(actions=[...], agents=[demo_agent])
   ```

The kickstarter ships option 1 by default. See [`01-architecture-decisions.md`](./01-architecture-decisions.md).

---

### `ERESOLVE unable to resolve dependency tree` with `eslint`

**Symptom:**
```
peer eslint@"^7.23.0 || ^8.0.0" from eslint-config-next@14.2.35
Found: eslint@9.x
```

**Fix:** With Next 14, downgrade ESLint to v8:
```json
"eslint": "^8.57.1"
```
With Next 15+, ESLint v9 is fine.

---

### `Could not find a version that satisfies the requirement copilotkit==0.1.X`

**Symptom (Python 3.13):**
```
ERROR: Ignored the following versions that require a different python version:
  0.1.40 Requires-Python >=3.10,<3.13;
  ...
ERROR: No matching distribution found for copilotkit==0.1.49
```

**Cause:** Versions 0.1.40–0.1.87 of `copilotkit` actively block Python 3.13.

**Fix:** Use `copilotkit>=0.1.88,<0.2`. See [`03-dependency-pinning.md`](./03-dependency-pinning.md#python--copilotkit-and-python-313).

---

### `pydantic-core` version conflict with `copilotkit`

**Symptom:**
```
copilotkit 0.1.88 depends on pydantic-core>=2.35.0
pydantic 2.10.4 depends on pydantic-core==2.27.2
```

**Fix:** Bump pydantic to ≥2.11:
```txt
pydantic>=2.11,<3
```

---

### `Cannot find module 'dotenv'`

**Cause:** `next.config.js` does `require("dotenv")` but `dotenv` isn't installed.

**Fix:**
```bash
npm install dotenv
```
Make sure it's a `dependencies`, not `devDependencies` (it runs at build/start time).

---

### `[Errno 10048] only one usage of each socket address (protocol/network address/port) is normally permitted`

**Cause:** Port 8000 is already in use.

**Fix (Windows):**
```powershell
netstat -ano | Select-String "LISTENING" | Select-String ":8000"
# find the PID
taskkill /PID <pid> /F
```

**Fix (macOS/Linux):**
```bash
lsof -i :8000
kill <pid>
```

Or pick a different port: `--port 8001` and update `NEXT_PUBLIC_BACKEND_URL` to match.

---

### `localhost refused to connect` (ERR_CONNECTION_REFUSED)

**Most common cause:** Dev server crashed or never started.

**Diagnose:**
```bash
# Is anything listening?
netstat -ano | grep "LISTENING" | grep -E ":3000|:8000"

# What does the dev server log say?
tail -30 <wherever-you-redirected-stdout>
```

**Less common cause:** Firewall blocking localhost (rare on dev machines but happens). Check Windows Defender / corporate VPN settings.

---

### Chat sidebar opens but no response when typing

**Cause:** Service adapter is `ExperimentalEmptyAdapter` (no LLM call) — that's the default in mock mode.

**Fix:** Set a real provider in `.env`:
```dotenv
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
```
Restart `npm run dev`.

---

### `[copilotkit] LLM_PROVIDER=openai but OPENAI_API_KEY is not set`

**Cause:** Console warning from the route's defensive fallback.

**Fix:** Set the key in `.env`. If you set it but still see the warning, check that:
1. `next.config.js` is loading the repo-root `.env` (not just `frontend/.env.local`).
2. You restarted `npm run dev` after editing `.env` (Next caches env at startup).

---

### `Module '"@copilotkit/runtime"' has no exported member 'OpenAIAdapter'`

**Cause:** Outdated `@copilotkit/runtime`. The 1.4 → 1.10 → 1.57 series moved exports around.

**Fix:**
```bash
cd frontend
npm install @copilotkit/runtime@latest @copilotkit/react-core@latest @copilotkit/react-ui@latest
```

Pin to a `^1.x` range, not an exact version, so npm pulls the latest compatible.

---

### TypeScript: `JSX element class does not support attributes`

Or: a CopilotKit hook returning `unknown` instead of the expected type.

**Cause:** TypeScript version mismatch with the React types.

**Fix:**
```json
"typescript": "^5.7.2",
"@types/react": "^18.3.18",
"@types/react-dom": "^18.3.5",
"react": "^18.3.1"
```

Ensure `tsconfig.json` has `"jsx": "preserve"` and `"strict": true`.

---

### Action handler succeeds but the LLM response says "I couldn't find that action"

**Cause:** Action name mismatch. The LLM called `getWeather` but you registered `get_weather`.

**Diagnose:** Look at the backend logs — the dispatch returns "unknown action" with the called name.

**Fix:** Names must match **exactly**. Convention: `snake_case` for backend, but match exactly across frontend and backend if you have the same action in both.

---

### Pydantic validation errors on action calls

**Symptom:** Action returns `{"error": "invalid arguments: 1 validation error for ..."}` even when the LLM seems to call it correctly.

**Cause:** Schema mismatch — the LLM passes a field the model doesn't have, or omits a required field.

**Fix:**
1. Make optional fields explicitly optional with defaults: `units: str = Field(default="celsius")`.
2. Add descriptions so the LLM understands the schema: `Field(description="...")`.
3. For tolerant input, use `model_config = ConfigDict(extra="ignore")`.

---

### `LangChainPendingDeprecationWarning: The default value of allowed_objects will change`

**Cause:** Internal langgraph warning, not actionable.

**Fix:** Suppress with a pytest filter:
```toml
# pyproject.toml
[tool.pytest.ini_options]
filterwarnings = [
  "ignore::langchain_core._api.beta_decorator.LangChainPendingDeprecationWarning",
]
```

---

## "It's not working" general protocol

When you can't even narrow down the symptom:

1. **`git status`** — uncommitted changes? Stash, retry on a clean tree.
2. **Read the actual log lines, not the summary** — Next dev errors are often three screens up from the prompt.
3. **Confirm the env values are loaded:**
   ```python
   from app.config import get_settings
   print(get_settings().model_dump())
   ```
   ```ts
   console.log({
     LLM_PROVIDER: process.env.LLM_PROVIDER,
     hasOpenAIKey: !!process.env.OPENAI_API_KEY,
   });
   ```
4. **Curl the endpoints directly** — bypass the UI to isolate front/back.
5. **Restart both servers from scratch.** Hot reload occasionally caches stale state, especially after editing `next.config.js` or `requirements.txt`.
6. **Compare to the kickstarter.** If your project diverged from the canonical layout, the divergence is usually the bug.

---

## Background-process gotchas

If you're running dev servers via tooling that backgrounds processes:

- **Servers can be killed between turns** — use a real terminal for sustained work.
- **Port collisions cascade** — killing PID X might free port 8000 *and* terminate the next-started backend if both wrote to the same temp file.
- **Hot reload != restart** — `next.config.js`, `requirements.txt`, and Python source changes (without `--reload`) need a full restart.

The cleanest fix is "two terminals, two processes, you in control." The kickstarter ships `scripts/dev.ps1` for Windows that opens both in child shells.
