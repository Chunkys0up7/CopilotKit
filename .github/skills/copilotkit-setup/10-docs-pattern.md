# 10 — Docs as code

The kickstarter treats documentation as **a source artifact**, not afterthought. Every class has a spec; every PR that changes a class updates the spec. The repo is the single source of truth.

---

## What ships with the code

| File | Audience | When updated |
|---|---|---|
| `README.md` | Anyone landing on the repo | When capabilities change. |
| `ARCHITECTURE.md` | Onboarding engineer | When the request flow or major component layout changes. |
| `CHANGELOG.md` | Anyone bumping a dependency | Every release. |
| `.env.example` | Anyone running locally | When env vars are added/removed. |
| `docs/classes/INDEX.md` | Code reader | When classes are added/removed. |
| `docs/classes/<Class>.md` | Code reader of *this class* | When the class's public surface changes. |
| `docs/<topic>.md` (capabilities, providers, etc.) | New developer | When the topic gains/loses a feature. |
| `docs/complexity.md` | Performance debugger | When a hot path changes Big-O. |

**Rule:** if a code change makes a doc lie, the same commit fixes the doc.

---

## The spec template

```markdown
# `MyClass`

**File:** [`path/to/file.py`](../../path/to/file.py)

## Purpose
One sentence — if you need "and" / "also", split the class.

## Public surface

| Member | Signature | Notes |
|---|---|---|
| `do_thing` | `async (x: int) -> Result` | Raises `FooError` on …. |
| `state` | `property -> str` | |

## Collaborators
- **Imports:** `Other`, `pydantic.BaseModel`.
- **Imported by:** `app.runtime`, `tests.test_my_class`.

## Complexity
- `do_thing`: O(n) where n = len(x).

## Test coverage
- `tests/test_my_class.py::test_do_thing_basic`
- `tests/test_my_class.py::test_do_thing_validates`

## Failure modes
- Bad input → `pydantic.ValidationError`.
- Network error → propagates unchanged.
```

Keep it short — the code is the truth, the spec is the contract.

---

## What goes in `README.md`

1. **One paragraph above the fold:** what this is, why someone would use it.
2. **Capability table:** "you get X out of the box."
3. **Quickstart:** the exact commands to run on a clean machine.
4. **Repository layout:** ASCII tree (annotated).
5. **Core concepts:** 1-paragraph primer on the framework's vocabulary.
6. **Class index pointer:** "every class has a spec — see `docs/classes/INDEX.md`".
7. **Status / status / changelog pointer.**
8. **License.**

Keep total length under ~150 lines. If you need more, that's a separate `docs/` page.

---

## What goes in `ARCHITECTURE.md`

1. **High-level diagram** (ASCII art is fine — readable in any tool).
2. **Where each major decision was made** ("LLM call lives in the Next route", "evals run on the Python side").
3. **Request flow** — numbered steps, one or two diagrams.
4. **Design principles** — table of "principle | what it means here".
5. **What's *intentionally* not here yet** — defer auth, persistence, multi-tenant; cite the file/line where each TODO lives.
6. **Versioning policy.**

Treat ARCHITECTURE.md as the contract a new senior engineer needs to ship without asking questions.

---

## CHANGELOG conventions

Use [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

### Added
- New thing.

### Changed
- Renamed X to Y.

### Fixed
- Bug in Z.

### Deprecated
### Removed
### Security
```

**One bullet per behavior change.** Don't combine "added X and fixed Y" — they're separate concerns and someone reverting either should know which commit to revert.

---

## Inline docstrings (Python)

```python
"""
ClassName — one sentence.

Why this exists in one paragraph. What problem it solves, what it
deliberately does NOT solve.

Spec: docs/classes/ClassName.md

Complexity:
    method_name:  O(...)
"""
```

The "Spec: docs/classes/X.md" line is the link — readers can jump from code to spec without searching.

---

## Inline docstrings (TypeScript)

```ts
/**
 * <ComponentName /> — one sentence.
 *
 * Why this exists. What's special about its props.
 *
 * Spec: docs/classes/ComponentName.md
 */
```

JSDoc is optional but the file-top comment is required.

---

## CI lint for spec coverage (optional, recommended)

A small script that scans `app/**/*.py` (and `components/**/*.tsx`) for `class` definitions and checks that each has a corresponding `docs/classes/<ClassName>.md`:

```python
# scripts/lint_specs.py
import ast, sys
from pathlib import Path

def class_names(path: Path) -> set[str]:
    names = set()
    tree = ast.parse(path.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and not node.name.startswith("_"):
            names.add(node.name)
    return names

def specs_exist() -> int:
    backend = Path("backend/app").rglob("*.py")
    docs = {p.stem for p in Path("docs/classes").glob("*.md")}
    missing = []
    for path in backend:
        for name in class_names(path):
            if name not in docs:
                missing.append(f"{path}::{name}")
    if missing:
        print("Missing spec docs:")
        for m in missing: print(f"  - {m}")
        return 1
    print("All classes have spec docs.")
    return 0

if __name__ == "__main__":
    sys.exit(specs_exist())
```

Run in CI: `python scripts/lint_specs.py`. Fails the build on missing specs.

---

## What NOT to do

- **Don't write API reference docs.** `mypy` + `pydantic` already produce machine-readable types; humans don't need duplicate prose. Spec docs describe **purpose and shape**, not every method param.
- **Don't write "how to" guides for things the README covers.** One quickstart, in one place.
- **Don't write tutorials in the repo.** Those go in your product docs site. The repo doc is for engineers reading the code.
- **Don't auto-generate from docstrings into HTML and call that "the docs".** Sphinx output is unreadable to a stranger. Hand-write the human-facing pages.
- **Don't let docs go stale.** Better to delete a stale page than leave it as a trap.

---

## How to reuse this pattern in another project

1. Copy `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md` templates.
2. Copy `docs/` skeleton (`classes/`, `complexity.md`, capability docs).
3. Adopt the rule: **every PR that changes a class updates its spec** — set as a CI lint or a code review checklist.
4. Adopt the docstring file-top comment with `Spec: docs/classes/X.md`.

The whole pattern is ~5 conventions and one optional CI script. It's lightweight enough to use on solo projects and structured enough to scale to a team.
