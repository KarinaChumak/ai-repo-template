## What failure looks like here

- The UI lies: shows stale, wrong, or another user's data; a success state after a failed request.
- The UI traps: a flow that can't be completed by keyboard or screen reader, a modal that can't be closed, a lost form draft.
- The UI breaks silently: an unhandled promise rejection, an effect that loops.

## Flag

- Missing loading, empty, and error states for anything that fetches.
- `useEffect` used to derive state from props or other state.
- Unstable keys (`key={index}` on lists that reorder), missing effect cleanup.
- Accessibility regressions: interactive elements without an accessible name, click handlers on non-interactive elements, color as the only signal.
