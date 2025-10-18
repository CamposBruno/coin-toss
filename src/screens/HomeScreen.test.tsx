import React from 'react';
import { render, screen } from '@testing-library/react-native';
import HomeScreen from '../../app/index';

// Mock the theme provider
jest.mock('@/providers/ThemeProvider', () => ({
  useTheme: () => ({
    colors: {
      background: '#FFFFFF',
      text: '#000000',
      textSecondary: '#666666',
      primary: '#6C5CE7',
    },
    isDark: false,
  }),
}));

describe('HomeScreen', () => {
  it('renders welcome message', () => {
    render(<HomeScreen />);
    expect(screen.getByText('Welcome to The Hyve')).toBeTruthy();
  });

  it('renders app description', () => {
    render(<HomeScreen />);
    expect(screen.getByText(/Connect. Host. Experience./)).toBeTruthy();
  });

  it('displays how it works section', () => {
    render(<HomeScreen />);
    expect(screen.getByText('How It Works')).toBeTruthy();
  });

  it('shows version information', () => {
    render(<HomeScreen />);
    expect(screen.getByText(/MVP Foundation v1.0.0/)).toBeTruthy();
  });
});
