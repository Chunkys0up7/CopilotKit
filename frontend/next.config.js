/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // The CopilotKit runtime route streams SSE — opt out of the static cache.
  experimental: {
    serverActions: { bodySizeLimit: "2mb" },
  },
  env: {
    NEXT_PUBLIC_BACKEND_URL:
      process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
  },
};

module.exports = nextConfig;
