import * as Sentry from 'sentry-expo';
import Constants from 'expo-constants';

type SeverityLevel = 'fatal' | 'error' | 'warning' | 'log' | 'info' | 'debug';

export function initializeSentry() {
  const sentryDsn = Constants.expoConfig?.extra?.sentryDsn;

  if (!sentryDsn || sentryDsn === 'your-sentry-dsn') {
    console.log('[Sentry] Skipping initialization - no DSN configured');
    return;
  }

  Sentry.init({
    dsn: sentryDsn,
    enableInExpoDevelopment: false,
    debug: __DEV__,
    tracesSampleRate: 1.0,
    environment: __DEV__ ? 'development' : 'production',
  });

  console.log('[Sentry] Initialized successfully');
}

export function logError(error: Error, context?: Record<string, unknown>) {
  if (__DEV__) {
    console.error('[Sentry Error]', error, context);
  }

  Sentry.Native.captureException(error, {
    extra: context,
  });
}

export function logMessage(message: string, level: SeverityLevel = 'info') {
  if (__DEV__) {
    console.log(`[Sentry ${level}]`, message);
  }

  Sentry.Native.captureMessage(message, level);
}
