/**
 * CopilotKit runtime route — the bridge between the browser and the
 * Python backend.
 *
 * Why this file exists:
 *   - The browser only knows how to talk to /api/copilotkit on its own
 *     origin (CORS-friendly, same-domain cookies, etc.).
 *   - The Python backend exposes /copilotkit_remote.
 *   - @copilotkit/runtime in this route forwards one to the other and
 *     handles streaming.
 *
 * Swap providers: this route is provider-agnostic. The LLM call happens
 * inside the FastAPI service; this route just relays.
 *
 * Spec: docs/classes/RuntimeRoute.md
 */
import {
  CopilotRuntime,
  copilotRuntimeNextJSAppRouterEndpoint,
  ExperimentalEmptyAdapter,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

const runtime = new CopilotRuntime({
  remoteEndpoints: [
    {
      url: `${BACKEND_URL}/copilotkit_remote`,
    },
  ],
});

// EmptyAdapter is correct here — the actual LLM call is made by the
// Python backend via its provider. The Next route is a pure relay.
const serviceAdapter = new ExperimentalEmptyAdapter();

export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
