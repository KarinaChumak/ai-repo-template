---
paths:
  - 'src/features/**'
  - 'src/pages/**'
---

- Name files, components and hooks after the glossary in `__NOTES_DIR__/product.md`.
- Compose components from `src/components/`. No HTML elements, CSS or `className` here; ESLint enforces it. A missing look is a new prop or component in `src/components/`.
- Queries for an area live in its `queries.ts`. The hook returns the `useQuery` result unchanged:

  ```ts
  export const bookingQuery = (bookingId: string) =>
    queryOptions({ queryKey: ['booking', bookingId], queryFn: () => getBooking(bookingId) });

  export function useBookingQuery(bookingId: string) {
    return useQuery(bookingQuery(bookingId));
  }
  ```

- A fetch function throws on a non-2xx response, with an error class the UI can tell apart (`NotFoundError`), so components branch on `query.error`, not on a status of their own.
- Every query has its loading, error and empty states on screen, each with a test.
