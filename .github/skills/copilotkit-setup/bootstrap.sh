#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — scaffold a fresh CopilotKit Kickstarter project.
#
# Self-contained: does NOT require GitHub access. Copies the complete project
# layout from the skill's bundled `bootstrap/` directory into <target>.
#
# Usage:
#   bash bootstrap.sh <target>
#   bash bootstrap.sh ./my-app --force
#   bash bootstrap.sh ../new-project --no-git
#
# Container / Codespaces example:
#   bash .github/skills/copilotkit-setup/bootstrap.sh /workspace/my-app
#
# After this completes, follow RUNBOOK.md from Step 3 (backend deps).
# =============================================================================

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <target> [--force] [--no-git]

  <target>     Directory to create (or overwrite with --force)
  --force      Allow non-empty target
  --no-git     Skip git init + initial commit
EOF
  exit 1
}

force=false
no_git=false
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force=true; shift ;;
    --no-git) no_git=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown flag: $1" >&2; usage ;;
    *) target="$1"; shift ;;
  esac
done

[[ -z "$target" ]] && usage

# Resolve absolute paths. Works from any CWD; works wherever the skill lives —
# .github/skills/, ~/.claude/skills/, or any other location.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$script_dir/bootstrap"

[[ ! -d "$src_dir" ]] && {
  echo "ERROR: bootstrap source not found at $src_dir" >&2
  echo "Re-install the skill — see RUNBOOK.md 'Appendix: Installing the skill'." >&2
  exit 1
}

if [[ -d "$target" ]] && [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
  if [[ "$force" != true ]]; then
    echo "ERROR: $target is not empty. Use --force or pick an empty dir." >&2
    exit 1
  fi
fi

mkdir -p "$target"
target="$(cd "$target" && pwd)"

echo "==> Bootstrapping CopilotKit Kickstarter"
echo "    source: $src_dir"
echo "    target: $target"
echo

# `cp -a` preserves attributes; the trailing `/.` copies hidden files
# (.env.example, .gitignore) without dotglob shenanigans.
cp -a "$src_dir"/. "$target"/

# Initialize git unless told otherwise
if [[ "$no_git" != true ]]; then
  if [[ ! -d "$target/.git" ]]; then
    (cd "$target" && git init --quiet && git add . && \
       git commit --quiet -m "Initial commit (from copilotkit-setup skill)")
    echo "==> git initialized + initial commit created"
  else
    echo "==> existing .git found; skipped git init"
  fi
fi

# Make .env from .env.example if missing
if [[ ! -f "$target/.env" ]] && [[ -f "$target/.env.example" ]]; then
  cp "$target/.env.example" "$target/.env"
  echo "==> .env created from .env.example"
fi

count=$(find "$target" -type f ! -path "$target/.git/*" | wc -l | tr -d ' ')

echo
echo "==> Done. $count files written."
echo
echo "Next steps:"
echo "  cd '$target'"
echo
echo "  # Backend (terminal 1):"
echo "  cd backend"
echo "  python -m venv .venv && source .venv/bin/activate"
echo "  pip install -r requirements.txt"
echo "  uvicorn app.main:app --reload --port 8000"
echo
echo "  # Frontend (terminal 2):"
echo "  cd frontend"
echo "  npm install"
echo "  npm run dev"
echo
echo "  # Then open http://localhost:3000"
echo
echo "Full procedure: see RUNBOOK.md in the new project."
