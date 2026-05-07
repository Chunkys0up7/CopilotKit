#!/usr/bin/env bash
# =============================================================================
# fix-styling-defensive.sh — most-conservative styling fix.
#
# Removes transpilePackages entirely and switches to a direct dist-path
# CSS import. Use this if fix-styling.sh didn't help.
#
# Touches three files + clears .next. Nothing else.
#
# Usage:
#   bash fix-styling-defensive.sh                  # patches ./
#   bash fix-styling-defensive.sh /workspace/foo   # patches /workspace/foo/
# =============================================================================
set -euo pipefail

target="${1:-.}"
[[ ! -d "$target" ]] && { echo "ERROR: $target is not a directory" >&2; exit 1; }
target="$(cd "$target" && pwd)"

if [[ ! -f "$target/frontend/next.config.js" ]]; then
  echo "ERROR: $target/frontend/next.config.js not found" >&2
  exit 1
fi

echo "==> Patching $target (defensive variant)"

# --- 1. next.config.js: NO transpilePackages -------------------------------
cat > "$target/frontend/next.config.js" <<'EOF'
const path = require("node:path");
require("dotenv").config({
  path: path.resolve(__dirname, "..", ".env"),
});

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
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
echo "    [1/4] next.config.js — removed transpilePackages"

# --- 2. layout.tsx: import CSS via direct dist path ------------------------
cat > "$target/frontend/app/layout.tsx" <<'EOF'
/**
 * Root layout — wraps every page in the <CopilotProvider />.
 *
 * CSS imports use the *direct dist path* instead of the package's
 * subpath export. Some Next 14 + container/proxy combos fail to
 * resolve the export map for `.css` files; the dist path always works
 * because it's a literal file lookup in node_modules.
 *
 * Spec: docs/classes/RootLayout.md
 */
import type { Metadata } from "next";
import "@copilotkit/react-ui/dist/index.css";
import "./globals.css";
import { CopilotProvider } from "@/components/CopilotProvider";

export const metadata: Metadata = {
  title: "CopilotKit Kickstarter",
  description: "A clean, spec-driven scaffold for CopilotKit-powered apps.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <CopilotProvider>{children}</CopilotProvider>
      </body>
    </html>
  );
}
EOF
echo "    [2/4] layout.tsx — direct dist CSS path"

# --- 3. package.json: ensure @ag-ui/client is declared ---------------------
python - "$target/frontend/package.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    pkg = json.load(f)
deps = pkg.setdefault("dependencies", {})
changed = False
if "@ag-ui/client" not in deps:
    deps["@ag-ui/client"] = "^0.0.53"
    changed = True
if changed:
    pkg["dependencies"] = dict(sorted(deps.items()))
    with open(path, "w") as f:
        json.dump(pkg, f, indent=2)
        f.write("\n")
    print("    [3/4] package.json — added @ag-ui/client")
else:
    print("    [3/4] package.json — @ag-ui/client already declared, skipped")
PYEOF

# --- 4. clear .next cache --------------------------------------------------
if [[ -d "$target/frontend/.next" ]]; then
  rm -rf "$target/frontend/.next"
  echo "    [4/4] .next — dev cache cleared"
else
  echo "    [4/4] .next — already absent, skipped"
fi

echo
echo "==> Done. Next:"
echo
echo "  cd '$target/frontend'"
echo "  npm install            # picks up @ag-ui/client if needed"
echo "  # Ctrl+C any running 'npm run dev' first, then:"
echo "  npm run dev 2>&1 | tee /tmp/devout.log"
echo "  # Wait for 'Compiled / in <N>s' OR an error."
echo "  # If errors, paste back: head -40 /tmp/devout.log"
echo
echo "  # If clean: hard-refresh browser (Ctrl+Shift+R)"
