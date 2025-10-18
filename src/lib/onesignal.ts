import { OneSignal } from 'react-native-onesignal';
import Constants from 'expo-constants';

export function initializeOneSignal() {
  const oneSignalAppId = Constants.expoConfig?.extra?.oneSignalAppId;

  if (!oneSignalAppId || oneSignalAppId === 'your-onesignal-app-id') {
    console.log('[OneSignal] Skipping initialization - no App ID configured');
    return;
  }

  try {
    // Initialize OneSignal with v5 API
    OneSignal.initialize(oneSignalAppId);

    // Request push notification permissions
    OneSignal.Notifications.requestPermission(true);

    // Configure notification handlers
    OneSignal.Notifications.addEventListener('foregroundWillDisplay', (event) => {
      console.log('[OneSignal] Notification received in foreground:', event);
    });

    OneSignal.Notifications.addEventListener('click', (event) => {
      console.log('[OneSignal] Notification clicked:', event);
      // Handle notification tap - navigate to appropriate screen
    });

    console.log('[OneSignal] Initialized successfully');
  } catch (error) {
    console.error('[OneSignal] Initialization error:', error);
  }
}

export function setUserTag(key: string, value: string) {
  OneSignal.User.addTag(key, value);
}

export function removeUserTag(key: string) {
  OneSignal.User.removeTag(key);
}

export function setExternalUserId(userId: string) {
  OneSignal.login(userId);
}
