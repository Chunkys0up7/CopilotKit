"""
CopilotKit runtime wiring.

Builds a `CopilotKitRemoteEndpoint` populated with our `ActionRegistry`
and `DemoAgent`, then mounts it onto the FastAPI app at `/copilotkit_remote`.

This module is the *only* place that imports from the `copilotkit` SDK —
the rest of the backend stays SDK-agnostic so you could lift it to a
different runtime (e.g. plain Server-Sent Events) without rewriting actions.

Spec: docs/classes/Runtime.md
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI

from app.actions import ActionRegistry, default_registry
from app.actions.base import Action
from app.agents import build_demo_agent
from app.llm import LLMProvider, get_provider
from app.logging_config import get_logger

log = get_logger(__name__)

_REMOTE_PATH = "/copilotkit_remote"


def _action_to_copilotkit(action: Action[Any]) -> Any:
    """Wrap one of our `Action` objects in the SDK's expected shape.

    The SDK accepts a list of dicts with `name`, `description`,
    `parameters` (list-of-param dicts), and `handler` (async fn). Our
    `Action.copilotkit_schema()` already produces the schema half — we
    add the handler that adapts the SDK's positional kwargs back into
    our Pydantic-validated path.
    """
    schema = action.copilotkit_schema()

    async def _handler(**kwargs: Any) -> Any:
        result = await action.call(kwargs)
        return result.value if result.ok else {"error": result.error}

    return {**schema, "handler": _handler}


def mount(app: FastAPI, *, registry: ActionRegistry | None = None) -> None:
    """Attach the CopilotKit remote endpoint to a FastAPI app."""
    registry = registry or default_registry()
    provider: LLMProvider = get_provider()
    log.info(
        "copilotkit.runtime.mount",
        provider=provider.name,
        model=provider.model,
        actions=registry.names(),
    )

    # Lazy import keeps `copilotkit` truly optional for unit tests.
    from copilotkit import CopilotKitRemoteEndpoint  # type: ignore[import-untyped]
    from copilotkit.integrations.fastapi import add_fastapi_endpoint  # type: ignore[import-untyped]

    sdk_actions = [_action_to_copilotkit(a) for a in (registry.get(n) for n in registry.names()) if a]
    agent = build_demo_agent(provider)

    endpoint = CopilotKitRemoteEndpoint(
        actions=sdk_actions,
        agents=[
            {
                "name": agent.name,
                "description": "Demo CoAgent — one-shot LLM call wrapped as an agent.",
            }
        ],
    )
    add_fastapi_endpoint(app, endpoint, _REMOTE_PATH)
    log.info("copilotkit.runtime.mounted", path=_REMOTE_PATH)


__all__ = ["mount"]
