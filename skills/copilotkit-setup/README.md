# `copilotkit-setup` skill

A complete playbook for scaffolding a CopilotKit project (Next.js + FastAPI) with single-purpose classes, an LLM provider abstraction, an action registry, and a native eval framework — all spec-documented and source-of-truth.

## What's in here

```
copilotkit-setup/
├── SKILL.md                     <- entrypoint (YAML frontmatter + playbook)
├── 01-architecture-decisions.md <- the LLM-where + monorepo decisions
├── 02-monorepo-layout.md        <- exact directory tree + bootstrap commands
├── 03-dependency-pinning.md     <- the install gotchas (real ones)
├── 04-class-design.md           <- single-purpose class pattern
├── 05-llm-provider-pattern.md   <- LLMProvider ABC + adapters
├── 06-action-registry-pattern.md<- Action + ActionRegistry
├── 07-runtime-wiring.md         <- the two SDK-touching files
├── 08-eval-framework.md         <- YAML scenarios + runner
├── 09-debugging-runbook.md      <- every error we hit + the fix
├── 10-docs-pattern.md           <- spec-per-class, README/ARCHITECTURE rules
└── templates/                   <- copy-paste-ready files
    ├── env-example
    ├── backend-requirements.txt
    ├── backend-config.py
    ├── backend-llm-base.py
    ├── backend-mock-provider.py
    ├── backend-action-base.py
    ├── backend-action-registry.py
    ├── backend-runtime-mount.py
    ├── backend-main.py
    ├── frontend-package.json
    ├── frontend-tsconfig.json
    ├── frontend-next-config.js
    ├── frontend-runtime-route.ts
    ├── frontend-copilot-provider.tsx
    ├── eval-framework.py
    └── eval-scenario-template.yaml
```

## How to use this skill

### In Claude Code

Once installed (see below), this skill triggers automatically when:

- The user wants to scaffold a CopilotKit project.
- The user is debugging install / runtime errors with `@copilotkit/*` or the `copilotkit` PyPI package.
- The user asks how to wire `useCopilotAction`, `useCopilotReadable`, `useAgent`, or the runtime route.

The agent reads `SKILL.md` first (the entrypoint), then drills into the numbered references as needed.

### Manually (in any project)

The skill works as a plain set of Markdown files. To bootstrap a new project:

1. Read `SKILL.md` to choose the architecture.
2. Read `02-monorepo-layout.md` for the directory tree.
3. Copy files from `templates/` to your project at the paths in each file's `DROP-IN:` comment.
4. Adjust the env values in your local `.env`.
5. Run the bootstrap checklist from `09-debugging-runbook.md`.

## Installing the skill

### Project-level (this repo)

The skill already lives at `skills/copilotkit-setup/` in this repo. It's the canonical source of truth — edit here, commit, propagate.

### User-level (cross-project Claude Code)

Copy the directory to `~/.claude/skills/`:

```powershell
# Windows PowerShell
$src = "C:\Users\camer\Projects\CopilotKit\skills\copilotkit-setup"
$dst = "$HOME\.claude\skills\copilotkit-setup"
New-Item -ItemType Directory -Force -Path "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force $src $dst
```

```bash
# macOS/Linux
mkdir -p ~/.claude/skills
cp -r ./skills/copilotkit-setup ~/.claude/skills/copilotkit-setup
```

Restart Claude Code (or start a new session) — the skill becomes discoverable via the trigger phrases listed in `SKILL.md`'s frontmatter.

### In another project

The skill is portable. To make it available in `~/yourproject/`:

```bash
mkdir -p ~/yourproject/.claude/skills
cp -r ./skills/copilotkit-setup ~/yourproject/.claude/skills/
git -C ~/yourproject add .claude/skills/copilotkit-setup
git -C ~/yourproject commit -m "Adopt copilotkit-setup skill"
```

## Updating the skill

The skill is versioned with the project. To incorporate lessons from new builds:

1. Edit the relevant reference file (or add a new one).
2. Update `SKILL.md` if the entry-point text needs to change.
3. Commit with a clear message: `skill(copilotkit-setup): document <new gotcha>`.
4. If the change matters cross-project, also re-run the install command above on machines that need the update.

## Source

This skill was distilled from a real CopilotKit Kickstarter build. Everything in `templates/` is the actual code that shipped — none of it is theoretical.

The build that produced this skill is at the root of this repo. Read it as a living example.
