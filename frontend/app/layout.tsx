/**
 * Root layout — wraps every page in the <CopilotProvider />.
 *
 * The provider connects to /api/copilotkit (the runtime route handler)
 * which in turn calls the FastAPI backend. We import the CopilotKit
 * stylesheet here so the chat UI is themed consistently across pages.
 *
 * Spec: docs/classes/RootLayout.md
 */
import type { Metadata } from "next";
// Two CSS imports cooperate — order matters:
// 1. CopilotKit's chat UI styles (sidebar, bubbles, buttons, popups).
//    The `./styles.css` subpath resolves via package.json `exports` to
//    dist/index.css in 1.57+; older versions ship index.css at this path
//    directly, so the same import works on both.
// 2. Our app-level globals come AFTER so CSS variables we set
//    (--copilot-kit-primary-color etc.) override CopilotKit defaults.
import "@copilotkit/react-ui/styles.css";
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
