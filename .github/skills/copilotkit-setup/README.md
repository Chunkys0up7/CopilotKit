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
├── bootstrap.sh                 <- one-shot scaffolder (bash)
├── bootstrap.ps1                <- one-shot scaffolder (PowerShell)
├── bootstrap/                   <- the COMPLETE 77-file project layout
│   ├── README.md, RUNBOOK.md, ARCHITECTURE.md, ...
│   ├── backend/, frontend/, docs/, scripts/
└── templates/                   <- per-file drop-ins (for piecewise adoption)
    ├── env-example
    ├── backend-*.py
    ├── frontend-*.{ts,tsx,js,json}
    └── eval-*.{py,yaml}
```

## How to use this skill

### One command

From an empty directory anywhere on your machine — works in Linux containers, Codespaces, macOS, WSL, or Windows:

```bash
# bash
target=/workspace/my-new-app
bash .github/skills/copilotkit-setup/bootstrap.sh "$target"
```

```powershell
# PowerShell
pwsh .github\skills\copilotkit-setup\bootstrap.ps1 -Target C:\workspace\my-new-app
```

The script copies the bundled `bootstrap/` layout (77 files), runs `git init`, copies `.env.example` → `.env`, and prints the next-step commands. Total time: ~3 seconds.

After that, follow `RUNBOOK.md` from Step 3 (backend deps) onward.

### In Claude Code

Once the skill is installed at one of these locations, it triggers automatically:
- `<repo>/.github/skills/copilotkit-setup/` (project-relative)
- `~/.claude/skills/copilotkit-setup/` (user-wide)

Trigger phrases (from SKILL.md frontmatter):
- "scaffold a CopilotKit project here"
- "add a CopilotKit copilot to this app"
- "wire up CopilotKit"

The agent reads `SKILL.md` first, then drills into the numbered references as needed.

### Manually (no Claude in the loop)

The skill works as plain Markdown + bash/ps1. To bootstrap a new project without Claude:

1. Read `SKILL.md` to confirm the architecture.
2. Run `bootstrap.sh` (or `.ps1`) — see One command above.
3. Follow `RUNBOOK.md` in the scaffolded project.

For piecewise adoption (you have an existing app, just want one piece), see `templates/` and the `DROP-IN:` comment at the top of each template file.

## Installing the skill

The skill is portable — a directory of Markdown + scripts + a `bootstrap/` source tree. No install step required if it's already in your repo at `.github/skills/copilotkit-setup/`.

### Adopt it in another repo

```bash
src=/path/to/source-repo/.github/skills/copilotkit-setup
mkdir -p .github/skills
cp -a "$src" .github/skills/copilotkit-setup
git add .github/skills/copilotkit-setup
git commit -m "Adopt copilotkit-setup skill"
```

### Install user-wide (one machine, many repos)

```bash
src=/path/to/source-repo/.github/skills/copilotkit-setup
mkdir -p ~/.claude/skills
cp -a "$src" ~/.claude/skills/copilotkit-setup
```

Then any project on this machine can call:
```bash
bash ~/.claude/skills/copilotkit-setup/bootstrap.sh /workspace/new-project
```

### Verify install

```bash
test -f .github/skills/copilotkit-setup/SKILL.md         && echo OK
test -f .github/skills/copilotkit-setup/bootstrap.sh     && echo OK
test -d .github/skills/copilotkit-setup/bootstrap        && echo OK
test -f .github/skills/copilotkit-setup/bootstrap/README.md && echo OK
```

All four must print `OK`.

## Updating the skill

The skill is versioned with the project. To incorporate lessons from new builds:

1. Edit the relevant reference file (or add a new one).
2. Update `SKILL.md` if the entrypoint text needs to change.
3. If the change affects the bootstrap project layout, also update files inside `bootstrap/`.
4. Commit with a clear message: `skill(copilotkit-setup): document <new gotcha>`.
5. Propagate to other repos / user-wide installs by re-copying.

## Source

This skill was distilled from a real CopilotKit Kickstarter build. Every file in `bootstrap/` is the actual code that shipped — none of it is theoretical.

The build that produced this skill is at the root of this repo. Read it as a living example.
