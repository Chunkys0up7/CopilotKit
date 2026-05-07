// Load the repo-root .env *before* Next builds its own env so the same
// file drives both the Python backend and this Next process.
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
