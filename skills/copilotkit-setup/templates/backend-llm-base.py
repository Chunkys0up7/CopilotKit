"""
LLMProvider — the contract every concrete provider must satisfy.

A provider takes a list of messages plus an optional tool schema and
returns either a single LLMResponse (sync) or an async iterator of
LLMChunk (streaming). Tool-call shape is normalized so the upstream
ActionRegistry sees one format regardless of vendor.

DROP-IN: app/llm/base.py
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any, Literal, Self

from app.config import Settings  # adjust import path to your project

Role = Literal["system", "user", "assistant", "tool"]


@dataclass(frozen=True, slots=True)
class LLMMessage:
    role: Role
    content: str
    name: str | None = None
    tool_call_id: str | None = None


@dataclass(frozen=True, slots=True)
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any]


@dataclass(frozen=True, slots=True)
class LLMResponse:
    content: str
    tool_calls: tuple[ToolCall, ...] = ()
    finish_reason: str = "stop"
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LLMChunk:
    text_delta: str = ""
    tool_call: ToolCall | None = None
    done: bool = False


class LLMProvider(ABC):
    name: str = "abstract"

    def __init__(self, model: str) -> None:
        self.model = model

    @classmethod
    @abstractmethod
    def from_settings(cls, settings: Settings) -> Self: ...

    @abstractmethod
    async def generate(
        self,
        messages: list[LLMMessage],
        tools: list[dict[str, Any]] | None = None,
    ) -> LLMResponse: ...

    @abstractmethod
    def stream(
        self,
        messages: list[LLMMessage],
        tools: list[dict[str, Any]] | None = None,
    ) -> AsyncIterator[LLMChunk]: ...

    def describe(self) -> dict[str, str]:
        return {"provider": self.name, "model": self.model}
