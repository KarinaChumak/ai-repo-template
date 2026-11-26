import { render, screen } from '@testing-library/react';
import { Text } from '@/components/Text';

describe('Text', () => {
  it('shows its content as a paragraph', () => {
    render(<Text tone="muted">Saved a minute ago</Text>);

    expect(screen.getByText('Saved a minute ago').tagName).toBe('P');
  });
});
