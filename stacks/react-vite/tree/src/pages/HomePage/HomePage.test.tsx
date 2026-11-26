import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { renderRoute } from '@/test/render';

describe('HomePage', () => {
  it('counts clicks', async () => {
    const user = userEvent.setup();
    renderRoute('/');

    await user.click(await screen.findByRole('button', { name: 'Click me' }));

    expect(screen.getByText('Clicked 1 times.')).toBeInTheDocument();
  });
});
