import { render, screen } from '@testing-library/react';
import { PageLayout } from '@/components/PageLayout';

describe('PageLayout', () => {
  it('shows the title as the main heading, above its content', () => {
    render(<PageLayout title="Settings">Content</PageLayout>);

    expect(screen.getByRole('main')).toHaveTextContent('SettingsContent');
    expect(screen.getByRole('heading', { level: 1, name: 'Settings' })).toBeInTheDocument();
  });
});
