# Core Package

Shared core package for the IoT project that provides common functionality for both IoT device and phone applications.

## Features

- **Event Models**: Common event models with JSON serialization/deserialization
- **Encryption Utilities**: Secure encryption using AES-GCM for IoT communication
- **Network Protocol Handlers**: Standard protocol implementation for device-app communication

## Usage

Add this package to your project's `pubspec.yaml`:

```yaml
dependencies:
  core:
    path: ../../packages/core
```

Then import the required components:

```dart
import 'package:core/core.dart';

// Or import specific features
import 'package:core/src/events/events.dart';
import 'package:core/src/encryption/encryption.dart';
import 'package:core/src/network/network.dart';
```

## Version Control

This package follows semantic versioning:
- Major version: Breaking API changes
- Minor version: Non-breaking functionality additions
- Patch version: Bug fixes and minor improvements

Current version: 0.0.1
