# `LoggingConfig` (module)

**File:** [`backend/app/logging_config.py`](../../backend/app/logging_config.py)

## Purpose
Wire stdlib logging + structlog so every module gets coloured human output in dev and JSON-on-stdout in production with a single call.

## Public surface

| Function | Signature |
|---|---|
| `configure_logging(level: str = "INFO") -> None` | Idempotent; safe to call once at startup. |
| `get_logger(name: str \| None = None) -> BoundLogger` | Pass `__name__` from the caller. |

## Collaborators
- **Imports:** `structlog`.
- **Imported by:** `app.main`, `app.runtime`.

## Complexity
- O(1) per log call (string formatting + write).

## Test coverage
- Exercised indirectly via every test that imports `app.runtime` or `app.main`.

## Failure modes
- None at runtime — falls back to stdout if structlog import fails (it doesn't, since it's pinned).
