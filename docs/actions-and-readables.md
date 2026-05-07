# Actions & Readables — how the LLM talks to your app

## Mental model

```
              ┌──────────────────┐
              │  user message    │
              └────────┬─────────┘
                       ▼
   ┌────────────────────────────────────┐
   │   LLM (chosen provider)            │
   │   Sees:  - registered ACTIONS      │ ← addable from frontend OR backend
   │          - all current READABLES   │ ← values pushed via useCopilotReadable
   └─────────────┬──────────────────────┘
                 │
        decides to call action `X`
                 │
       ┌─────────┴─────────┐
       ▼                   ▼
  client-side       server-side
  useCopilotAction  ActionRegistry
       │                   │
       └─────────┬─────────┘
                 ▼
            tool result
                 │
                 ▼
   LLM continues, possibly emitting text
   or calling another action.
```

## When to put an action where

| Action runs… | Put it… | Example in this repo |
|---|---|---|
| In the browser (touches local React state) | **Frontend** — `useCopilotAction` | `addTodo`, `removeTodo` |
| On the server (DB, third-party API, secrets) | **Backend** — `Action` + `ActionRegistry` | `echo`, `get_weather` |

A single conversation can mix both freely; CopilotKit's runtime relays calls in either direction.

## Adding a backend action

```python
# backend/app/actions/my_thing.py
from pydantic import BaseModel, Field
from app.actions.base import Action

class CreateTicketParams(BaseModel):
    title: str = Field(description="Short ticket title.")
    priority: str = Field(default="normal", description="low | normal | high")

async def _handler(params: CreateTicketParams) -> dict:
    # ... talk to your ticket system here ...
    return {"id": "TKT-123", "title": params.title}

create_ticket = Action(
    name="create_ticket",
    description="Open a new support ticket.",
    parameters=CreateTicketParams,
    handler=_handler,
)
```

Then add to the registry:

```python
# backend/app/actions/registry.py
from .my_thing import create_ticket

def default_registry() -> ActionRegistry:
    return ActionRegistry(actions=[echo_action, weather_action, create_ticket])
```

That's it — the LLM will see the new action's schema on the next turn.

## Adding a frontend action

```tsx
useCopilotAction({
  name: "highlightSection",
  description: "Visually highlight a section by id.",
  parameters: [
    { name: "id", type: "string", description: "DOM id.", required: true },
  ],
  handler: async ({ id }) => {
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    return { ok: true };
  },
});
```

## Adding a readable (context the LLM sees but the user doesn't)

```tsx
useCopilotReadable({
  description: "The currently-open document and the user's cursor position.",
  value: { docId, cursor },
});
```

Readables update live — every change re-renders, the new value is sent on the next turn. Keep them small: every readable costs context tokens.

## Naming guidance

- Actions: `verb_noun` (e.g. `create_ticket`, `add_todo`). The LLM picks them by name + description, so be specific.
- Readables: write the *description* like a sentence the model will read first ("The user's current todo list…"). Don't describe the value's *type* — the JSON makes that obvious.
