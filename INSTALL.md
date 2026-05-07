# Install — copy-paste, no clone

Two self-extracting bash installers. Pick one based on what you want.

| Want | Use | What it gives you |
|---|---|---|
| **A working CopilotKit project, fast** | [`install-bootstrap.sh`](install-bootstrap.sh) | A 78-file project ready to `pip install` and run. ~70 KB single-file paste. |
| **The skill itself (so you can scaffold many projects later)** | [`install-skill.sh`](install-skill.sh) | The complete `copilotkit-setup` skill (107 files: bootstrap layout + reference docs + templates + scripts). ~140 KB single-file paste. Use the installed skill's `bootstrap.sh` to scaffold projects later, no GitHub access needed. |

Both have the entire payload embedded as a base64-encoded tar.gz. **Paste, run, done.**

---

## How to copy-paste from GitHub

1. Open the file's **raw view** on GitHub. The URLs are:
   - `https://github.com/Chunkys0up7/CopilotKit/raw/main/install-bootstrap.sh`
   - `https://github.com/Chunkys0up7/CopilotKit/raw/main/install-skill.sh`
2. **Select all** (`Ctrl+A` / `Cmd+A`), copy.
3. In your container/VM, create a file: `nano install-bootstrap.sh` (or your editor of choice).
4. **Paste**, save.
5. Run: `bash install-bootstrap.sh`.

---

## Option 1 — Fast project (most common)

Get a working app in ~5 seconds + install time.

### Step 1 — Paste the installer onto your machine

Save `install-bootstrap.sh` somewhere convenient (e.g. `/tmp/install-bootstrap.sh`).

### Step 2 — Run it

```bash
bash /tmp/install-bootstrap.sh /workspace/my-new-app
```

That writes 78 files into `/workspace/my-new-app/`, runs `git init`, copies `.env.example` → `.env`.

### Step 3 — Install dependencies

```bash
cd /workspace/my-new-app

# Backend (Terminal 1)
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Frontend (Terminal 2)
cd /workspace/my-new-app/frontend
npm install
npm run dev
```

### Step 4 — Open

`http://localhost:3000`. Page loads with the chat sidebar; chat returns `[mock] hi`. Set `OPENAI_API_KEY` in `.env` for real responses.

**Total time:** ~5 minutes (mostly `npm install`).

---

## Option 2 — Skill installer (use it many times)

When you want to scaffold multiple projects from the same skill without re-pasting.

### Step 1 — Paste `install-skill.sh` onto your machine

Save it somewhere like `/tmp/install-skill.sh`.

### Step 2 — Run it (places the skill into `.github/skills/copilotkit-setup/`)

Three target patterns:

```bash
# A) Vendor into a specific repo (skill at <repo>/.github/skills/copilotkit-setup/)
bash /tmp/install-skill.sh /workspace/myrepo

# B) Install user-wide (skill at ~/.claude/skills/copilotkit-setup/)
bash /tmp/install-skill.sh ~/.claude/skills

# C) Install into the current directory
bash /tmp/install-skill.sh .
```

### Step 3 — Use the installed skill to scaffold projects

```bash
# After option (A):
bash /workspace/myrepo/.github/skills/copilotkit-setup/bootstrap.sh /workspace/new-project-1
bash /workspace/myrepo/.github/skills/copilotkit-setup/bootstrap.sh /workspace/new-project-2

# After option (B):
bash ~/.claude/skills/copilotkit-setup/bootstrap.sh /workspace/new-project-3
```

Each `bootstrap.sh` call produces a fresh 78-file project in seconds.

---

## Verify your install

```bash
# Check what got written
find /workspace/my-new-app -type f | wc -l       # → ~78

# Sanity check the project is intact (in the venv)
cd /workspace/my-new-app/backend
source .venv/bin/activate
python -m pytest tests/ evals/ -q                # → 18 passed
```

---

## What's inside `install-bootstrap.sh`?

A 70 KB shell script with:
1. A bash header that creates the target dir + parses args.
2. ~960 lines of base64-encoded `tar.gz` (the entire 77-file project).
3. A footer that runs `git init`, copies `.env`, and prints next-step commands.

The base64 is the project's source compressed by ~6× (327 KB → 52 KB → 70 KB after base64). On the receiving end it's decoded with `base64 -d | tar xzf -` — both are stdlib utilities present on every Linux distro.

---

## Rebuilding the installers

If you change source files in this repo, regenerate the installers:

```bash
# install-bootstrap.sh — embeds the bootstrap/ project layout
tar czf /tmp/ck-bootstrap.tar.gz -C .github/skills/copilotkit-setup/bootstrap .
# (then re-run the build script that wraps the tarball with the bash shell)

# install-skill.sh — embeds the entire copilotkit-setup skill
tar czf /tmp/ck-skill.tar.gz -C .github/skills copilotkit-setup
```

A future improvement: add a `make installers` target in `scripts/` that rebuilds both.

---

## Troubleshooting

| Error | Fix |
|---|---|
| *`base64: command not found`* | Install `coreutils` (`apt-get install coreutils` / `apk add coreutils`). |
| *`tar: command not found`* | Install `tar` (`apt-get install tar`). |
| *`Target is not empty`* | Pass `--force` as the second argument. |
| *Pasted file size mismatch* | Make sure your editor didn't wrap or strip lines. Use `wc -c install-bootstrap.sh` — it should be ~73 KB. |
| *`bad data in line N`* (during base64 decode) | Same — the paste got corrupted. Re-copy from the raw GitHub view. |
