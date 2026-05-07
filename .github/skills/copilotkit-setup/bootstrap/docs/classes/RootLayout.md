# `RootLayout`

**File:** [`frontend/app/layout.tsx`](../../frontend/app/layout.tsx)

## Purpose
Wrap every page in `<CopilotProvider />`, import the CopilotKit stylesheet, and define HTML metadata.

## Public surface
Default-exported `RootLayout({ children })` — Next.js App Router convention.

## Collaborators
- `<CopilotProvider />` (sibling component).
- `@copilotkit/react-ui/styles.css` for default chat theme.

## Complexity
- Static — rendered once per route segment.

## Test coverage
- Smoke-tested by any page render.
