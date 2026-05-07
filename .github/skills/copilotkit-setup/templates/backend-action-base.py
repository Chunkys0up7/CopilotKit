"""
Action — wraps one async callable as a typed, schema-emitting tool.

DROP-IN: app/actions/base.py
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ValidationError

ParamsT = TypeVar("ParamsT", bound=BaseModel)


@dataclass(frozen=True, slots=True)
class ActionResult:
    ok: bool
    value: Any = None
    error: str | None = None

    def to_message(self) -> str:
        return str(self.value) if self.ok else f"ERROR: {self.error}"


@dataclass(frozen=True, slots=True)
class Action(Generic[ParamsT]):
    name: str
    description: str
    parameters: type[ParamsT]
    handler: Callable[[ParamsT], Awaitable[Any]]

    def openai_schema(self) -> dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters.model_json_schema(),
            },
        }

    def anthropic_schema(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "input_schema": self.parameters.model_json_schema(),
        }

    def copilotkit_schema(self) -> dict[str, Any]:
        schema = self.parameters.model_json_schema()
        properties = schema.get("properties", {})
        required = set(schema.get("required", []))
        params = [
            {
                "name": pname,
                "type": pinfo.get("type", "string"),
                "description": pinfo.get("description", ""),
                "required": pname in required,
            }
            for pname, pinfo in properties.items()
        ]
        return {"name": self.name, "description": self.description, "parameters": params}

    async def call(self, raw_args: dict[str, Any]) -> ActionResult:
        try:
            parsed = self.parameters.model_validate(raw_args)
        except ValidationError as exc:
            return ActionResult(ok=False, error=f"invalid arguments: {exc}")
        try:
            value = await self.handler(parsed)
        except Exception as exc:  # noqa: BLE001
            return ActionResult(ok=False, error=f"{type(exc).__name__}: {exc}")
        return ActionResult(ok=True, value=value)
