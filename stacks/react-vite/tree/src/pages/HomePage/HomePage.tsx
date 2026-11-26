import { useState } from 'react';
import { Button } from '@/components/Button';
import { PageLayout } from '@/components/PageLayout';
import { Text } from '@/components/Text';

export function HomePage() {
  const [count, setCount] = useState(0);

  return (
    <PageLayout title="__PROJECT_TITLE__">
      <Text>Clicked {count} times.</Text>
      <Button onClick={() => setCount((c) => c + 1)}>Click me</Button>
    </PageLayout>
  );
}
