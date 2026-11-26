React 19 + TypeScript + Vite single-page app, compiled with React Compiler. Tests: Vitest + Testing Library + MSW (unit), Playwright (e2e).

Decided by the stack, so don't ask about these:

- Routing: React Router. Routes are in `src/app/routes.tsx`.
- Server data: TanStack Query. No other fetching or caching layer.
- API mocks in tests: MSW, with default handlers in `src/test/handlers.ts`.
- Styling: plain CSS per component in `src/components/`, using the tokens in `src/index.css`.

Open, for `/kickoff` to settle when Phase 1 needs it: the API server, translations (i18n), a primitives library for accessible widgets (select, dialog), forms and validation.

Non-goals: SSR, a global state library, CSS-in-JS. Ask before adding any of them.

Where code goes:

- `src/components/<Name>/`: generic, styled building blocks (Button, Text, PageLayout, Alert). They own all the CSS and know nothing about the product.
- `src/features/<area>/`: the product's components, queries and types for one area. They compose `src/components/` and have no CSS.
- `src/pages/<Name>Page/`: one component per route. Pages compose features and components, with no CSS.
- `src/app/`: routes, providers and the query client.
