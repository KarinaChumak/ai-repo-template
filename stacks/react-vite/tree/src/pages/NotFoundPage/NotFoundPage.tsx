import { PageLayout } from '@/components/PageLayout';
import { Text } from '@/components/Text';

export function NotFoundPage() {
  return (
    <PageLayout title="Page not found">
      <Text tone="muted">There's nothing at this address.</Text>
    </PageLayout>
  );
}
