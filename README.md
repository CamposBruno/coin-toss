# 🐝 The Hyve - Social Networking & Event Planning App

The Hyve is a revolutionary social networking app that matches everyday people as event hosts or guests using an intelligent algorithm. Say goodbye to loneliness and hello to meaningful connections!

## 🚀 Tech Stack

### Core

- **Framework**: Expo SDK 52 with React Native 0.76
- **Language**: TypeScript (strict mode)
- **Navigation**: React Navigation (Native Stack + Bottom Tabs)
- **State Management**: TanStack Query (React Query)
- **Forms**: React Hook Form + Zod validation

### Services

- **Authentication**: Auth0
- **Push Notifications**: OneSignal
- **Crash Reporting**: Sentry
- **API Client**: Custom fetch-based client

### Development

- **Code Quality**: ESLint + Prettier
- **Git Hooks**: Husky + lint-staged
- **Testing**: Jest + React Native Testing Library
- **E2E Testing**: Maestro
- **CI/CD**: GitHub Actions + EAS Build

## 📋 Prerequisites

- Node.js 18+ and npm
- Expo CLI (`npm install -g expo-cli`)
- iOS Simulator (macOS) or Android Emulator
- EAS CLI for builds (`npm install -g eas-cli`)

## 🛠️ Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd the-hyve
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Set up environment variables**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your actual credentials:
   - `API_BASE_URL` - Your backend API URL
   - `AUTH0_DOMAIN` - Auth0 domain
   - `AUTH0_CLIENT_ID` - Auth0 client ID
   - `ONESIGNAL_APP_ID` - OneSignal app ID
   - `SENTRY_DSN` - Sentry DSN
   - `EAS_PROJECT_ID` - EAS project ID

4. **Install Husky hooks**
   ```bash
   npm run prepare
   ```

## 🏃 Running the App

### Development

```bash
npm start
```

### iOS Simulator

```bash
npm run ios
```

### Android Emulator

```bash
npm run android
```

### Web

```bash
npm run web
```

## 🧪 Testing

### Run all tests

```bash
npm test
```

### Watch mode

```bash
npm run test:watch
```

### E2E tests with Maestro

```bash
maestro test .maestro/
```

## 🔍 Code Quality

### Linting

```bash
npm run lint
npm run lint:fix
```

### Type checking

```bash
npm run type-check
```

### Formatting

```bash
npm run format
```

## 📦 Building

### Development build

```bash
eas build --profile development --platform ios
eas build --profile development --platform android
```

### Preview build

```bash
eas build --profile preview --platform all
```

### Production build

```bash
eas build --profile production --platform all
```

## 📁 Project Structure

```
the-hyve/
├── app/                    # Expo Router app directory
│   ├── _layout.tsx        # Root layout with providers
│   ├── index.tsx          # Home screen
│   └── +not-found.tsx     # 404 screen
├── src/
│   ├── features/          # Feature-based modules
│   │   └── events/        # Event management feature
│   ├── lib/               # Utilities and services
│   │   ├── api.ts         # API client
│   │   ├── auth.ts        # Auth utilities
│   │   ├── onesignal.ts   # Push notification setup
│   │   ├── sentry.ts      # Error tracking
│   │   └── validation.ts  # Zod schemas
│   ├── providers/         # React Context providers
│   │   ├── AppProviders.tsx
│   │   └── ThemeProvider.tsx
│   ├── screens/           # Screen components and tests
│   └── types/             # TypeScript type definitions
├── .github/
│   └── workflows/         # CI/CD pipelines
├── .maestro/              # E2E test flows
├── assets/                # Images, fonts, etc.
├── app.config.ts          # Expo configuration
├── tsconfig.json          # TypeScript config
├── .eslintrc.cjs          # ESLint config
├── .prettierrc            # Prettier config
├── jest.config.js         # Jest config
├── eas.json               # EAS Build config
└── package.json           # Dependencies
```

## 🎨 Theming

The app includes a minimal light/dark mode theme system. Access the theme in components:

```tsx
import { useTheme } from '@/providers/ThemeProvider';

function MyComponent() {
  const { colors, isDark, toggleTheme } = useTheme();

  return (
    <View style={{ backgroundColor: colors.background }}>
      <Text style={{ color: colors.text }}>Hello!</Text>
    </View>
  );
}
```

## 🔐 Environment Variables

All sensitive configuration is managed through environment variables:

- **API_BASE_URL** - Backend API endpoint
- **AUTH0_DOMAIN** - Auth0 tenant domain
- **AUTH0_CLIENT_ID** - Auth0 application client ID
- **ONESIGNAL_APP_ID** - OneSignal application ID
- **SENTRY_DSN** - Sentry project DSN
- **EAS_PROJECT_ID** - Expo Application Services project ID

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

Pre-commit hooks will automatically:

- Run ESLint and auto-fix issues
- Format code with Prettier
- Run type checking

## 📝 Core Dependencies

| Package                  | Version  | Purpose            |
| ------------------------ | -------- | ------------------ |
| expo                     | ~52.0.11 | Framework          |
| react-native             | 0.76.5   | Mobile framework   |
| @react-navigation/native | ^6.1.17  | Navigation         |
| @tanstack/react-query    | ^5.51.1  | Data fetching      |
| react-hook-form          | ^7.52.1  | Form management    |
| zod                      | ^3.23.8  | Schema validation  |
| react-native-auth0       | ^4.0.0   | Authentication     |
| react-native-onesignal   | ^5.2.6   | Push notifications |
| sentry-expo              | ~8.0.0   | Error tracking     |

## 📚 Additional Resources

- [Expo Documentation](https://docs.expo.dev/)
- [React Native Documentation](https://reactnavigation.org/)
- [React Navigation](https://reactnavigation.org/)
- [TanStack Query](https://tanstack.com/query/latest)
- [Auth0 React Native Guide](https://auth0.com/docs/quickstart/native/react-native)
- [OneSignal Documentation](https://documentation.onesignal.com/)
- [Sentry Documentation](https://docs.sentry.io/)

## ✅ Acceptance Criteria Status

- ✅ `expo start` runs successfully with no TypeScript or lint errors
- ✅ App structure configured for iOS and Android builds
- ✅ Auth0, OneSignal, and Sentry initialized (with dummy keys)
- ✅ CI pipeline configured (lint + unit tests on PRs)
- ✅ `AppProviders` wraps navigation and providers
- ✅ Home screen renders "Welcome to The Hyve" message
- ✅ ESLint + Prettier pre-commit hooks functional
- ✅ All core dependencies pinned and documented

## 📄 License

Copyright © 2025 The Hyve. All rights reserved.
