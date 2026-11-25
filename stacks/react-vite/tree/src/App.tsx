import { useState } from 'react';
import { Button } from '@/components/Button';

export function App() {
  const [count, setCount] = useState(0);

  return (
    <main className="app">
      <h1>__PROJECT_TITLE__</h1>
      <p>Clicked {count} times.</p>
      <Button onClick={() => setCount((c) => c + 1)}>Click me</Button>
    </main>
  );
}
