import { QueryClientProvider, type QueryClient } from '@tanstack/react-query';
import type { ReactNode } from 'react';

export interface AppProvidersProps {
  queryClient: QueryClient;
  children: ReactNode;
}

// Every provider the app needs. Tests render through it too, so they see what users see.
export function AppProviders({ queryClient, children }: AppProvidersProps) {
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
