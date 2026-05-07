# `Settings`

**File:** [`backend/app/config.py`](../../backend/app/config.py)

## Purpose
Single, validated source of runtime configuration loaded once from environment variables and the repo-root `.env` file.

## Public surface

| Member | Signature | Notes |
|---|---|---|
| `llm_provider` | `Literal["mock","openai","anthropic"]` | Default `mock`. |
| `llm_model` | `str` | Provider-specific model name. |
| `openai_api_key` / `anthropic_api_key` | `str` | Required only for the active provider. |
| `backend_host`, `backend_port` | `str`, `int` | Validated as a port range. |
| `cors_origins` | `str` (CSV) | Use `cors_origins_list` to consume. |
| `cors_origins_list` | `property -> list[str]` | |
| `log_level` | `Literal["DEBUG","INFO","WARNING","ERROR"]` | |
| `get_settings()` | `() -> Settings` | Process-wide cached singleton. |

## Collaborators
- **Imports:** `pydantic`, `pydantic_settings`.
- **Imported by:** `app.main`, `app.runtime`, `app.llm.*`, `evals.framework`.

## Complexity
- Construction: O(env vars). Once per process.
- All accessors: O(1).

## Test coverage
- `tests/test_llm_providers.py::test_factory_returns_mock_when_configured` exercises the factory with a freshly-built `Settings`.
- `tests/conftest.py::mock_settings` is the shared fixture for env mutation.

## Failure modes
- Invalid `llm_provider` → `pydantic.ValidationError` at startup.
- Missing API key for non-mock provider → raised by the provider's `__init__`, not here. (We don't fail-fast on key absence because the *active* provider may be mock.)
