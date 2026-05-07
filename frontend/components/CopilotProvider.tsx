/**
 * <CopilotProvider /> — wraps the app in a single <CopilotKit /> context.
 *
 * One place to:
 *   - point at the runtime URL
 *   - configure agent name & default opts
 *   - inject auth headers (TODO when you add auth)
 *
 * Spec: docs/classes/CopilotProvider.md
 */
"use client";

import { CopilotKit } from "@copilotkit/react-core";
import type { ReactNode } from "react";

const RUNTIME_URL = "/api/copilotkit";
const AGENT_NAME = "demo"; // matches build_demo_agent().name in the backend

export function CopilotProvider({ children }: { children: ReactNode }) {
  return (
    <CopilotKit runtimeUrl={RUNTIME_URL} agent={AGENT_NAME}>
      {children}
    </CopilotKit>
  );
}
