# Changelog

All notable changes to this kickstarter are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Initial monorepo scaffold (frontend + backend + evals + docs).
- LLM provider abstraction with `MockProvider`, `OpenAIProvider`, `AnthropicProvider`.
- `ActionRegistry` for backend actions; example `EchoAction` and `WeatherAction`.
- FastAPI runtime wiring CopilotKit's `CopilotKitRemoteEndpoint`.
- Next.js 14 App Router frontend with `<CopilotSidebar />`, example `useCopilotAction` and `useCopilotReadable` registrations.
- Eval framework: YAML scenarios, deterministic via `MockProvider`, pytest-driven runner.
- Per-class spec docs in `docs/classes/`.

[Unreleased]: https://github.com/Chunkys0up7/CopilotKit/compare/main...HEAD
