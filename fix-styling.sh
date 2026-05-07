#!/usr/bin/env bash
# =============================================================================
# fix-styling.sh — minimal one-off patcher for the unstyled-UI / 404-on-.ts
# regression. Only touches two files. Designed to be safer than fix-all.sh
# when fix-all.sh's broader changes regressed things.
#
# What it does:
#   1. Trims frontend/next.config.js's `transpilePackages` to the minimal
#      working set: @copilotkit/react-core + @copilotkit/react-ui.
#      (The longer list broke Next's chunking on .ts files because runtime
#      packages can't be re-bundled.)
#   2. Adds @ag-ui/client as an explicit dependency in package.json
#      (it was being imported from a transitive — fine in some configs,
#      a 404 cause in others).
#   3. Wipes frontend/.next so Next picks up the new config.
#
# It does NOT touch any other file.
#
# Usage:
#   bash fix-styling.sh                  # patches ./
#   bash fix-styling.sh /workspace/foo   # patches /workspace/foo/
# =============================================================================
set -euo pipefail

target="${1:-.}"
[[ ! -d "$target" ]] && { echo "ERROR: $target is not a directory" >&2; exit 1; }
target="$(cd "$target" && pwd)"

if [[ ! -f "$target/frontend/next.config.js" ]]; then
  echo "ERROR: $target/frontend/next.config.js not found" >&2
  echo "       run this from inside a kickstarter project, or pass the path" >&2
  exit 1
fi

echo "==> Patching $target"

# --- 1. next.config.js ----------------------------------------------------
cat > "$target/frontend/next.config.js" <<'EOF'
const path = require("node:path");
require("dotenv").config({
  path: path.resolve(__dirname, "..", ".env"),
});

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // Minimal transpilePackages — only the two client-rendered packages that
  // ship subpath CSS exports. Including @copilotkit/runtime here breaks
  // chunking (it's used server-side in the API route and Next can't
  // re-bundle its pre-built CJS); same for runtime-client-gql / shared.
  transpilePackages: ["@copilotkit/react-core", "@copilotkit/react-ui"],

  experimental: {
    serverActions: { bodySizeLimit: "2mb" },
  },
  env: {
    NEXT_PUBLIC_BACKEND_URL:
      process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
  },
};

module.exports = nextConfig;
EOF
echo "    [1/3] next.config.js — trimmed transpilePackages to react-core + react-ui"

# --- 2. package.json — add @ag-ui/client explicitly ------------------------
# Use python (always available) for reliable JSON edit.
python - "$target/frontend/package.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    pkg = json.load(f)
deps = pkg.setdefault("dependencies", {})
if "@ag-ui/client" not in deps:
    deps["@ag-ui/client"] = "^0.0.53"
    # Re-sort dependencies alphabetically for tidiness
    pkg["dependencies"] = dict(sorted(deps.items()))
    with open(path, "w") as f:
        json.dump(pkg, f, indent=2)
        f.write("\n")
    print("    [2/3] package.json — added @ag-ui/client ^0.0.53 to dependencies")
else:
    print("    [2/3] package.json — @ag-ui/client already declared, skipped")
PYEOF

# --- 3. clear .next cache --------------------------------------------------
if [[ -d "$target/frontend/.next" ]]; then
  rm -rf "$target/frontend/.next"
  echo "    [3/3] .next — dev cache cleared"
else
  echo "    [3/3] .next — already absent, skipped"
fi

echo
echo "==> Done. Next:"
echo
echo "  cd '$target/frontend'"
echo "  npm install            # picks up @ag-ui/client (likely a no-op,"
echo "                         #   it's already in node_modules)"
echo "  # Ctrl+C any running 'npm run dev' first, then:"
echo "  npm run dev"
echo
echo "  # Then hard-refresh the browser (Ctrl+Shift+R) at http://localhost:3000"
echo
echo "  # First request will recompile ~30s — wait for 'Compiled / in <N>s'"
echo "  # in the dev terminal before refreshing."
