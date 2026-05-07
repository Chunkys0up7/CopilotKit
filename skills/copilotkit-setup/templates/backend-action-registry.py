"""
ActionRegistry — holds Action objects and dispatches incoming ToolCalls.

DROP-IN: app/actions/registry.py
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Any

from app.llm.base import ToolCall
from .base import Action, ActionResult


class ActionRegistry:
    def __init__(self, actions: Iterable[Action[Any]] = ()) -> None:
        self._actions: dict[str, Action[Any]] = {}
        for action in actions:
            self.register(action)

    def register(self, action: Action[Any]) -> None:
        if action.name in self._actions:
            raise ValueError(f"Action {action.name!r} already registered.")
        self._actions[action.name] = action

    def __len__(self) -> int:
        return len(self._actions)

    def __contains__(self, name: object) -> bool:
        return name in self._actions

    def names(self) -> list[str]:
        return sorted(self._actions)

    def get(self, name: str) -> Action[Any] | None:
        return self._actions.get(name)

    def openai_schemas(self) -> list[dict[str, Any]]:
        return [a.openai_schema() for a in self._actions.values()]

    def anthropic_schemas(self) -> list[dict[str, Any]]:
        return [a.anthropic_schema() for a in self._actions.values()]

    def copilotkit_schemas(self) -> list[dict[str, Any]]:
        return [a.copilotkit_schema() for a in self._actions.values()]

    async def dispatch(self, call: ToolCall) -> ActionResult:
        action = self.get(call.name)
        if action is None:
            return ActionResult(ok=False, error=f"unknown action: {call.name!r}")
        return await action.call(call.arguments)


def default_registry() -> ActionRegistry:
    """Pre-populate with your actions. Replace with your factory."""
    # from .my_actions import my_action
    # return ActionRegistry(actions=[my_action])
    return ActionRegistry()
