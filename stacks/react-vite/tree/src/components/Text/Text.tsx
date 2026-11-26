import type { ReactNode } from 'react';
import './Text.css';

export type TextTone = 'default' | 'muted';

export interface TextProps {
  tone?: TextTone;
  children: ReactNode;
}

export function Text({ tone = 'default', children }: TextProps) {
  return <p className={`text text--${tone}`}>{children}</p>;
}
