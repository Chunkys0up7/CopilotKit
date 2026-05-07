"""
FastAPI entrypoint.

DROP-IN: app/main.py
Run with: uvicorn app.main:app --reload --port 8000
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__, runtime
from app.config import get_settings
from app.logging_config import configure_logging, get_logger

settings = get_settings()
configure_logging(settings.log_level)
log = get_logger(__name__)


@asynccontextmanager
async def _lifespan(app: FastAPI):  # noqa: ARG001
    log.info("backend.startup", version=__version__, provider=settings.llm_provider)
    yield
    log.info("backend.shutdown")


app = FastAPI(
    title="CopilotKit Backend",
    version=__version__,
    lifespan=_lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "version": __version__, "provider": settings.llm_provider}


# Wire CopilotKit endpoint last so the SDK import stays lazy elsewhere.
runtime.mount(app)
