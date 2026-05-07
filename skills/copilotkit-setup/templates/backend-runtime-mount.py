"""
CopilotKit FastAPI runtime wiring.

This module is the *only* place that imports the copilotkit SDK — the rest
of the backend stays SDK-agnostic and unit-testable without it.

DROP-IN: app/runtime.py
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI

from app.actions import ActionRegistry, default_registry
from app.actions.base import Action
from app.llm import LLMProvider, get_provider
from app.logging_config import get_logger

log = get_logger(__name__)

_REMOTE_PATH = "/copilotkit_remote"


def _action_to_copilotkit(action: Action[Any]) -> Any:
    schema = action.copilotkit_schema()

    async def _handler(**kwargs: Any) -> Any:
        result = await action.call(kwargs)
        return result.value if result.ok else {"error": result.error}

    return {**schema, "handler": _handler}


def mount(app: FastAPI, *, registry: ActionRegistry | None = None) -> None:
    registry = registry or default_registry()
    provider: LLMProvider = get_provider()
    log.info(
        "copilotkit.runtime.mount",
        provider=provider.name,
        model=provider.model,
        actions=registry.names(),
    )

    # Lazy import keeps copilotkit truly optional for unit tests.
    from copilotkit import CopilotKitRemoteEndpoint  # type: ignore[import-untyped]
    from copilotkit.integrations.fastapi import add_fastapi_endpoint  # type: ignore[import-untyped]

    sdk_actions = [
        _action_to_copilotkit(a)
        for a in (registry.get(n) for n in registry.names())
        if a
    ]

    # agents=[] is intentional in standard-chat mode. When you build a real
    # LangGraph CoAgent, instantiate it (e.g. LangGraphAgent(name="demo",
    # graph=compiled_graph)) and pass it here. Then add agent="demo" to
    # the React <CopilotKit> provider.
    endpoint = CopilotKitRemoteEndpoint(actions=sdk_actions, agents=[])

    add_fastapi_endpoint(app, endpoint, _REMOTE_PATH)
    log.info("copilotkit.runtime.mounted", path=_REMOTE_PATH)


__all__ = ["mount"]
