/**
 * <CopilotProvider /> — wraps the app in <CopilotKit /> context.
 *
 * DROP-IN: components/CopilotProvider.tsx
 *
 * NOTE: no `agent` prop. With no agent, CopilotKit uses the standard
 * chat path (LLM call in the Next route via the service adapter). Add
 * agent="<name>" only when you've registered a real LangGraphAgent
 * server-side; otherwise you'll get `useAgent: Agent X not found`.
 */
"use client";

import { CopilotKit } from "@copilotkit/react-core";
import type { ReactNode } from "react";

const RUNTIME_URL = "/api/copilotkit";

export function CopilotProvider({ children }: { children: ReactNode }) {
  return <CopilotKit runtimeUrl={RUNTIME_URL}>{children}</CopilotKit>;
}
