# 03 — Dependency pinning gotchas

Real install failures from a real build. Learn from these — they will hit you otherwise.

---

## Python — `copilotkit` and Python 3.13

**Symptom (pip):**

```
ERROR: Ignored the following versions that require a different python version:
  0.1.40 Requires-Python >=3.10,<3.13;
  0.1.41 Requires-Python >=3.10,<3.13;
  ... (continues through 0.1.87)
ERROR: Could not find a version that satisfies the requirement copilotkit==0.1.49
```

**Cause:** Versions **0.1.40 through 0.1.87** of `copilotkit` actively block Python 3.13. Versions ≤0.1.39 and ≥0.1.88 work.

**Fix:** Use `copilotkit>=0.1.88,<0.2`. Don't pin an exact version unless you've verified it against your Python.

Add a comment in `requirements.txt` so future-you knows why:

```txt
# 0.1.40–0.1.87 pinned Python <3.13. 0.1.88+ supports 3.13 again.
copilotkit>=0.1.88,<0.2
```

---

## Python — `copilotkit` ↔ `pydantic-core` version conflict

**Symptom (pip):**

```
ERROR: Cannot install -r requirements.txt because these package versions have conflicting dependencies.
The conflict is caused by:
    pydantic 2.10.4 depends on pydantic-core==2.27.2
    copilotkit 0.1.88 depends on pydantic-core>=2.35.0
```

**Cause:** `copilotkit 0.1.88` requires a newer `pydantic-core` than `pydantic 2.10.x` provides.

**Fix:** Bump `pydantic` to ≥2.11. Use a range so it stays solvable:

```txt
pydantic>=2.11,<3
pydantic-settings>=2.7,<3
```

**General rule:** Don't pin `pydantic` to a patch version unless your code uses an internal API. The 2.x line is API-stable for typical use.

---

## Frontend — `eslint-config-next` rejects ESLint v9

**Symptom (`npm install`):**

```
npm error code ERESOLVE
npm error Found: eslint@9.17.0
npm error Could not resolve dependency:
npm error peer eslint@"^7.23.0 || ^8.0.0" from eslint-config-next@14.2.35
```

**Cause:** Next 14's `eslint-config-next` peer-depends on ESLint 7 or 8 only. Next 15 supports ESLint 9.

**Fix (Next 14):** Pin ESLint to v8.

```json
"eslint": "^8.57.1",
"eslint-config-next": "^14.2.18"
```

**Fix (Next 15+):** ESLint 9 is fine; bump both.

**Don't use `--legacy-peer-deps` to "solve" it** — it suppresses the check but real incompatibilities can hit you at lint time.

---

## Frontend — `dotenv` not bundled by default

**Symptom (Next dev):**

```
Error: Cannot find module 'dotenv'
```

After adding `require("dotenv")` in `next.config.js` to load the repo-root `.env`.

**Fix:** Add `dotenv` as a runtime dependency (not devDependency):

```json
"dependencies": {
  "dotenv": "^16.4.7",
  ...
}
```

Then `npm install`.

---

## Frontend — CopilotKit version range

**Symptom:** `npm install` succeeds but TypeScript errors in `route.ts` like `Module '"@copilotkit/runtime"' has no exported member 'OpenAIAdapter'`.

**Cause:** You pinned an old version. `@copilotkit/*` 1.4 → 1.10 → 1.57 changed exports.

**Fix:** Use a `^1.x` range that resolves to a recent version, then verify:

```bash
npm view @copilotkit/runtime version    # check latest
```

```json
"@copilotkit/react-core": "^1.10.0",
"@copilotkit/react-ui": "^1.10.0",
"@copilotkit/runtime": "^1.10.0",
```

Caret semantics let npm pick anything `>=1.10 <2`, which currently resolves to 1.57.x.

---

## General principle: ranges in `requirements.txt`, exact in lock

For a kickstarter / starter scaffold:

| File | Style | Reason |
|---|---|---|
| `requirements.txt` | Compatible ranges (`>=X,<Y`) | Survives transitive shifts. Easy first-install. |
| `requirements.lock` (optional) | Exact via `pip freeze` | Production reproducibility. Generated, not edited. |
| `package.json` | Caret ranges (`^X.Y.Z`) | npm convention. |
| `package-lock.json` | Exact via npm | Production reproducibility. **Always commit this.** |

**Don't skip `package-lock.json`** — it's the only thing that makes "two devs ran `npm install` a week apart and got the same packages" actually true.

---

## How to debug a failing install

1. **Read the full error.** Pip's "ERROR:" lines are usually clear about which version constraint failed.
2. **Check Python version compatibility** explicitly: `python --version` and the package's PyPI page.
3. **Try the upper bound:** if you pinned `pkg==X`, try `pkg>=X` to see if a newer version fixes it.
4. **Use `pip-compile`** (from `pip-tools`) when the dependency tree gets gnarly. It explains conflicts better than `pip install`.
5. **For `npm`:** read the peerDependencies in the failing package's npmjs.com page.

---

## Verified known-good versions (as of 2026-05)

```
# Python 3.13 + Node 20+
fastapi>=0.115,<1
uvicorn[standard]>=0.32,<1
copilotkit>=0.1.88,<0.2
pydantic>=2.11,<3
pydantic-settings>=2.7,<3
openai>=1.59,<2
anthropic>=0.42,<1
structlog>=25,<26
pytest>=8.3,<9
pytest-asyncio>=0.25,<1
httpx>=0.28,<1
pyyaml>=6,<7

# Frontend (Next 14)
"@copilotkit/react-core": "^1.10.0"     # resolves to 1.57.x
"@copilotkit/react-ui": "^1.10.0"
"@copilotkit/runtime": "^1.10.0"
"next": "^14.2.18"
"react": "^18.3.1"
"react-dom": "^18.3.1"
"dotenv": "^16.4.7"
"eslint": "^8.57.1"                     # NOT v9 with Next 14
"eslint-config-next": "^14.2.18"
"typescript": "^5.7.2"
"vitest": "^2.1.8"
"@testing-library/react": "^16.1.0"
"jsdom": "^25.0.1"
```

When you copy these, **re-check `npm view <pkg> version` and PyPI** before adopting in a new project — these drift weekly.
