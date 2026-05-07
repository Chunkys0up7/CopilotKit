# UI capabilities reference

This is the catalogue of every UI primitive the kickstarter ships. Some are imported directly from `@copilotkit/react-ui`; the rest are local components that wrap them. When CopilotKit ships a new component, list it here once you adopt it.

## Pre-built CopilotKit components

| Component | When to use | Key props (subset) | Local example |
|---|---|---|---|
| `<CopilotChat />` | Full-page chat surface. | `messages`, `onSendMessage`, `instructions`, `labels`, `Markdown`, `Input`, `Header`, `Messages`, `RenderMessage` | not yet — try replacing the sidebar in `HomePage`. |
| `<CopilotSidebar />` | Floating, dockable chat. The default for in-app copilots. | `defaultOpen`, `clickOutsideToClose`, `hitEscapeToClose`, `labels`, `instructions`, `Window`, `Button`, `Header`, `Messages`, `Input` | [`HomePage`](../frontend/app/page.tsx) |
| `<CopilotPopup />` | Smaller, non-docked popup for one-shot tasks. | `defaultOpen`, `clickOutsideToClose`, `labels`, `instructions` | (not used) |
| `<CopilotTextarea />` | Inline LLM-completing textarea. | `value`, `onValueChange`, `autosuggestionsConfig`, `placeholder` | (not used) |

All four accept a `labels` object, an `instructions` string (system prompt addendum), and a stylesheet via the `@copilotkit/react-ui/styles.css` import + CSS variables (e.g. `--copilot-kit-primary-color`).

## Hooks

| Hook | What it does | Local example |
|---|---|---|
| `useCopilotAction` | Register a function the LLM can call from chat. | [`ExampleActions`](../frontend/components/actions/ExampleActions.tsx) |
| `useCopilotReadable` | Expose live app state to the LLM as context. | [`ChatPanel`](../frontend/components/ChatPanel.tsx) |
| `useCopilotChat` | Programmatic chat control (`messages`, `append`, `stop`). | (not used yet — handy for "send a message from a button") |
| `useCoAgent` | Programmatic agent control. | (not used — wire when you upgrade `DemoAgent` to LangGraph) |
| `useCoAgentStateRender` | Render agent state inline in the chat (e.g. "planning…"). | (not used — wire when `AgentState` carries real status updates) |
| `useComponent` | Register a React component the agent can render with structured props (Generative UI). | (not used — see Generative UI section below) |

## Generative UI

Three patterns, picked per use-case:

1. **Static (high control).** Agent returns structured data → frontend renders a pre-defined component. Wire via `useComponent({ name, description, Component, handler })`.
2. **Declarative (shared control).** Agent emits A2UI / Open-JSON-UI; `@copilotkit/a2ui-renderer` renders it. Best when the UI shape is dynamic.
3. **Open-ended (high flexibility).** Agent returns HTML/JSX rendered in a sandbox. Use sparingly.

This kickstarter ships only the action/readable surface; pick a Generative UI pattern when you have a concrete use-case and document it under [`docs/classes/`](classes/INDEX.md).

## Theming

Override CSS variables in `frontend/app/globals.css`. The full list is on the [CopilotKit customization docs](https://docs.copilotkit.ai/concepts/customize-look-and-feel/customize-built-in-ui-components).

## Accessibility

- All built-in components ship with ARIA labels and keyboard navigation. Test screen-reader output before shipping.
- Custom labels (`labels.title`, `labels.initial`, etc.) should be human-readable, not internal codes.
