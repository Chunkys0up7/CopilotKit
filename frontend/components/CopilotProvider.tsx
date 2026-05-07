/**
 * <CopilotProvider /> — wraps the app in a single <CopilotKit /> context.
 *
 * One place to:
 *   - point at the runtime URL
 *   - inject auth headers (TODO when you add auth)
 *
 * The `agent` prop is intentionally not set: with no `agent`, CopilotKit
 * uses the standard chat path (LLM call happens in the Next route via a
 * service adapter). Add `agent="..."` only when you've registered a real
 * LangGraph CoAgent in the Python backend.
 *
 * Spec: docs/classes/CopilotProvider.md
 */
"use client";

import { CopilotKit } from "@copilotkit/react-core";
import type { ReactNode } from "react";

const RUNTIME_URL = "/api/copilotkit";

export function CopilotProvider({ children }: { children: ReactNode }) {
  return <CopilotKit runtimeUrl={RUNTIME_URL}>{children}</CopilotKit>;
}
