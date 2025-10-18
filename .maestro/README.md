# Maestro E2E Tests

This directory contains end-to-end tests for The Hyve mobile app using Maestro.

## Setup

1. Install Maestro:

   ```bash
   curl -Ls "https://get.maestro.mobile.dev" | bash
   ```

2. Add Maestro to your PATH:
   ```bash
   export PATH="$PATH:$HOME/.maestro/bin"
   ```

## Running Tests

### iOS Simulator

```bash
maestro test .maestro/home_flow.yaml
```

### Android Emulator

```bash
maestro test .maestro/home_flow.yaml
```

## Writing Tests

Maestro uses YAML files to define test flows. Each flow represents a user journey through the app.

Example:

```yaml
appId: com.thehyve.app
---
- launchApp
- assertVisible: 'Welcome'
- tapOn: 'Login'
- inputText: 'user@example.com'
- tapOn: 'Submit'
```

## Available Test Flows

- `home_flow.yaml` - Tests the home screen rendering and basic navigation

## Resources

- [Maestro Documentation](https://maestro.mobile.dev/)
- [Maestro CLI Reference](https://maestro.mobile.dev/cli/test-suites-and-reports)
