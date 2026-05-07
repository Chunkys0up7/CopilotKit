// Load the repo-root .env *before* Next builds its own env so the same
// file drives both the Python backend and this Next process.
const path = require("node:path");
require("dotenv").config({
  path: path.resolve(__dirname, "..", ".env"),
});

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // CopilotKit packages ship as ESM with subpath exports (including CSS).
  // Next 14 needs them in transpilePackages to bundle CSS reliably and to
  // process their TypeScript output without raw-imports failing.
  transpilePackages: [
    "@copilotkit/react-core",
    "@copilotkit/react-ui",
    "@copilotkit/runtime",
    "@copilotkit/runtime-client-gql",
    "@copilotkit/shared",
  ],

  experimental: {
    serverActions: { bodySizeLimit: "2mb" },
  },
  env: {
    NEXT_PUBLIC_BACKEND_URL:
      process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
  },
};

module.exports = nextConfig;
