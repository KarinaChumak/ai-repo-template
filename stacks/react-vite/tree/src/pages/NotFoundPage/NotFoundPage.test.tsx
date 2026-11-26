import { screen } from '@testing-library/react';
import { renderRoute } from '@/test/render';

describe('NotFoundPage', () => {
  it('shows "Page not found" for an unknown address', async () => {
    renderRoute('/no-such-page');

    expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument();
  });
});
