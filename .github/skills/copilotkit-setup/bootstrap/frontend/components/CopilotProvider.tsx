/**
 * <CopilotProvider /> — wraps the app in <CopilotKit /> context.
 *
 * Configuration:
 *   - runtimeUrl points at /api/copilotkit (Next route → Python actions).
 *   - agents__unsafe_dev_only registers a "default" HttpAgent that POSTs
 *     directly to the Python backend's /agent/default endpoint, which
 *     hosts our LangGraph CoAgent over the AG-UI protocol.
 *
 * Why HttpAgent + agents__unsafe_dev_only instead of letting CopilotKit
 * discover the agent via the runtime's /info endpoint?
 *
 *   The copilotkit Python SDK 0.1.88's LangGraphAGUIAgent bridge is
 *   broken (missing super().dict_repr() and agent.execute() methods).
 *   Bypassing it with a direct AG-UI HttpAgent is the cleanest path
 *   until that's fixed upstream. The actions runtime still flows
 *   through /api/copilotkit normally.
 *
 * Spec: docs/classes/CopilotProvider.md
 */
"use client";

import { CopilotKit } from "@copilotkit/react-core";
import { HttpAgent } from "@ag-ui/client";
import { useMemo, type ReactNode } from "react";

const RUNTIME_URL = "/api/copilotkit";
const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export function CopilotProvider({ children }: { children: ReactNode }) {
  // useMemo so the same HttpAgent instance is reused across renders;
  // re-creating it on every render would reset connection state.
  const agents = useMemo(
    () => ({
      default: new HttpAgent({ url: `${BACKEND_URL}/agent/default` }),
    }),
    [],
  );

  return (
    <CopilotKit
      runtimeUrl={RUNTIME_URL}
      agents__unsafe_dev_only={agents}
    >
      {children}
    </CopilotKit>
  );
}
