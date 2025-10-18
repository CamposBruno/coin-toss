import { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'The Hyve',
  slug: 'the-hyve',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  userInterfaceStyle: 'automatic',
  splash: {
    image: './assets/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#6C5CE7',
  },
  assetBundlePatterns: ['**/*'],
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.thehyve.app',
    infoPlist: {
      NSCameraUsageDescription:
        'The Hyve needs access to your camera for profile photos and event check-in.',
      NSPhotoLibraryUsageDescription:
        'The Hyve needs access to your photo library to upload event photos.',
      NSLocationWhenInUseUsageDescription: 'The Hyve needs your location to find nearby events.',
    },
  },
  android: {
    adaptiveIcon: {
      foregroundImage: './assets/adaptive-icon.png',
      backgroundColor: '#6C5CE7',
    },
    package: 'com.thehyve.app',
    permissions: [
      'CAMERA',
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'ACCESS_FINE_LOCATION',
      'ACCESS_COARSE_LOCATION',
    ],
  },
  web: {
    favicon: './assets/favicon.png',
    bundler: 'metro',
  },
  plugins: [
    'expo-router',
    'sentry-expo',
    [
      'onesignal-expo-plugin',
      {
        mode: 'development',
      },
    ],
    [
      'react-native-auth0',
      {
        domain: process.env.AUTH0_DOMAIN || 'your-domain.auth0.com',
      },
    ],
  ],
  extra: {
    apiBaseUrl: process.env.API_BASE_URL || 'https://api.thehyve.app',
    auth0Domain: process.env.AUTH0_DOMAIN || 'your-domain.auth0.com',
    auth0ClientId: process.env.AUTH0_CLIENT_ID || 'your-client-id',
    oneSignalAppId: process.env.ONESIGNAL_APP_ID || 'your-onesignal-app-id',
    sentryDsn: process.env.SENTRY_DSN || 'your-sentry-dsn',
    eas: {
      projectId: process.env.EAS_PROJECT_ID || 'your-project-id',
    },
  },
  owner: 'thehyve',
  scheme: 'thehyve',
});
