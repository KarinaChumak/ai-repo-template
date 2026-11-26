import type { ReactNode } from 'react';
import './PageLayout.css';

export interface PageLayoutProps {
  title: string;
  children: ReactNode;
}

export function PageLayout({ title, children }: PageLayoutProps) {
  return (
    <main className="page-layout">
      <h1 className="page-layout__title">{title}</h1>
      {children}
    </main>
  );
}
