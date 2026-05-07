# 01 — Architecture decisions

Make these calls **before** writing code. Each one shapes the rest.

---

## Decision 1 — Where does the LLM call live?

This is the single most consequential decision and the source of CopilotKit's most common confusion.

```
                                            ┌─────────────────────────┐
browser  ──►  /api/copilotkit  ──►          │  service adapter        │
                                            │  (LLM call here for     │
                                            │   STANDARD chat)        │
                                            └────────────┬────────────┘
                                                         │
                                                         ▼
                                            ┌─────────────────────────┐
                                            │  Python /copilotkit_    │
                                            │  remote                 │
                                            │  - server actions       │
                                            │  - CoAgents (LLM call   │
                                            │    here for COAGENT     │
                                            │    chat)                │
                                            └─────────────────────────┘
```

### Pick **standard chat** when…
- You want a chat sidebar with tool-calling and that's it.
- You want it working tonight.
- Latency budget is tight (one fewer hop).
- You're happy with the canonical CopilotKit flow.

**Implementation:** Next route uses `OpenAIAdapter` / `AnthropicAdapter`. Python backend hosts actions only. React provider has no `agent` prop.

### Pick **CoAgent mode** when…
- You need streaming agent state visible in the UI (`useCoAgentStateRender`).
- You need checkpointing, replay, or human-in-the-loop interrupts.
- The agent has multi-step planning that benefits from LangGraph's graph runtime.
- You want the same agent reachable from non-React clients (CLI, mobile, other services).

**Implementation:** Next route uses `ExperimentalEmptyAdapter` (no LLM call here). Python backend hosts a real `LangGraphAgent`. React provider has `agent="<name>"`.

### **Rule:** Never half-pick.

Setting `agent="<name>"` on the React provider but not registering a real `LangGraphAgent` server-side gives you the famous `useAgent: Agent X not found after runtime sync` error. Either commit to CoAgent or don't.

If you're unsure → **start with standard chat**. The Python `LLMProvider` abstraction in this kickstarter still gives you a clean upgrade path: when you build the agent, you reuse the same provider class.

---

## Decision 2 — Single-stack or full monorepo?

| Option | What | When |
|---|---|---|
| **Next-only** | Everything in Next.js; no Python. | Prototype, no server-side actions that need Python libs, no CoAgents. |
| **Next + FastAPI monorepo** | What this kickstarter ships. | You want server-side actions in Python (DB access, ML, third-party APIs), or you'll add CoAgents later, or you want Python evals. |
| **Next + Express/Nest** | Server-side actions in Node. | Your team is Node-first and Python is a foreign tool. |

The kickstarter assumes **Next + FastAPI** because:
- Python is the lingua franca for LLM tooling (LangGraph, LangChain, evals).
- Splitting frontend and AI backend is good practice once you scale.
- The eval framework belongs naturally on the Python side.

If you're going Next-only, drop the `backend/` directory and move actions to `useCopilotAction` / API routes.

---

## Decision 3 — Mock-first or skip the mock?

**Always include the mock provider.** It's ~80 lines of code and pays back forever:

- The eval suite runs in CI without API keys or rate limits.
- New developers can clone, install, and see a working page in 10 minutes (no key).
- Action-pipeline tests don't need a real LLM — `/tool <name> <json>` directives stub one out.

The only argument against is "we have keys, why bother?" — and the answer is *because future-you and your CI runner don't have keys*.

---

## Decision 4 — Generative UI strategy

Three patterns, pick per use-case (you'll often use multiple):

| Pattern | What | When |
|---|---|---|
| **Static** | Agent returns structured JSON; frontend renders a pre-defined React component via `useComponent({ name, Component, handler })`. | High-control: you know the shape. Charts, forms, product cards. |
| **Declarative** | Agent emits A2UI JSON; `@copilotkit/a2ui-renderer` renders generic components. | Shared control: agent picks shape from a vocabulary. Dashboards. |
| **Open-ended** | Agent returns HTML/JSX rendered in a sandboxed iframe. | High flexibility, low safety. Use sparingly. |

The kickstarter ships the action/readable surface only. **Don't pre-build a Generative UI layer until you have a concrete use-case** — picking the wrong pattern is a real cost.

---

## Decision 5 — Auth strategy (defer if possible)

CopilotKit's runtime is unauthenticated by default. Options:

| Approach | Complexity | When |
|---|---|---|
| **No auth (dev)** | trivial | Local dev, evals, demos. |
| **Auth at the Next layer** | low | Wrap `/api/copilotkit` with your auth middleware (Clerk, NextAuth, etc.). |
| **Per-request properties** | medium | Pass `properties={{ userId, role }}` to `<CopilotKit>`; agents see them in tool calls. |
| **CopilotKit Cloud** | low | Managed: SSO, RBAC, audit logs. Costs money. |

**Defer auth until you have a real user.** Don't pre-build for hypothetical multi-tenancy.

---

## Decision matrix shortcut

If your answers are: **standard chat**, **monorepo**, **mock-first**, **no Generative UI yet**, **auth deferred** — copy the kickstarter as-is. That's the default optimum for ~80% of new projects.

If any answer differs, see the corresponding section below before scaffolding.

---

## What this implies for file structure

The decisions above translate to:

- A `frontend/` and `backend/` at the repo root.
- A single `.env` at the repo root, wired into both processes.
- A `MockProvider` in `backend/app/llm/mock_provider.py`.
- An empty `agents=[]` on the FastAPI side (placeholder for future CoAgent).
- An `evals/` directory with at least one scenario.

See [`02-monorepo-layout.md`](./02-monorepo-layout.md) for the exact tree.
