/* eslint-env jest */
import '@testing-library/react-native/extend-expect';

// Mock expo modules
jest.mock('expo-constants', () => ({
  expoConfig: {
    extra: {
      apiBaseUrl: 'https://api.test.com',
      auth0Domain: 'test.auth0.com',
      auth0ClientId: 'test-client-id',
      oneSignalAppId: 'test-onesignal-id',
      sentryDsn: 'test-sentry-dsn',
    },
  },
}));

jest.mock('react-native-onesignal', () => ({
  OneSignal: {
    initialize: jest.fn(),
    Notifications: {
      requestPermission: jest.fn(),
      addEventListener: jest.fn(),
    },
    User: {
      addTag: jest.fn(),
      removeTag: jest.fn(),
    },
    login: jest.fn(),
  },
}));

jest.mock('react-native-auth0', () => ({
  Auth0Provider: ({ children }) => children,
  useAuth0: () => ({
    authorize: jest.fn(),
    clearSession: jest.fn(),
    user: null,
    error: null,
    isLoading: false,
  }),
}));
