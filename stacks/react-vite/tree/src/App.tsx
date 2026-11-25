import { useState } from 'react';

export function App() {
  const [count, setCount] = useState(0);

  return (
    <main className="app">
      <h1>__PROJECT_NAME__</h1>
      <p>Clicked {count} times.</p>
      <button type="button" onClick={() => setCount((c) => c + 1)}>
        Click me
      </button>
    </main>
  );
}
