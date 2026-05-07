"""
Settings — single source of runtime configuration.

DROP-IN: app/config.py
"""

from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ProviderName = Literal["mock", "openai", "anthropic"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR"]

# Repo-root .env (two levels up from app/config.py)
_REPO_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_REPO_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    llm_provider: ProviderName = Field(default="mock")
    llm_model: str = Field(default="gpt-4o-mini")
    openai_api_key: str = Field(default="")
    anthropic_api_key: str = Field(default="")

    backend_host: str = Field(default="0.0.0.0")
    backend_port: int = Field(default=8000, ge=1, le=65535)
    cors_origins: str = Field(default="http://localhost:3000")
    log_level: LogLevel = Field(default="INFO")

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


_SINGLETON: Settings | None = None


def get_settings() -> Settings:
    global _SINGLETON
    if _SINGLETON is None:
        _SINGLETON = Settings()
    return _SINGLETON
