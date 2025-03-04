# MoonNative

A Flutter plugin that demonstrates native function calls across all supported platforms: Android, iOS, macOS, Windows, Linux, and Web.

## Features

- Cross-platform support (Android, iOS, macOS, Windows, Linux, Web)
- Example of native method channel implementation for each platform
- Demonstrates different native calculations per platform:
  - iOS: (a * b) + 10
  - Android: a^b (power function)
  - macOS: ((a + b) / 2) * CPU core count
  - Windows: (a - b)²
  - Linux: Coming soon

## Usage

```dart
// Import the package
import 'package:moon_native/moon_native.dart';

// Create an instance
final moonNative = MoonNative();

// Get the platform version
String? platformVersion = await moonNative.getPlatformVersion();

// Perform a native calculation
double result = await moonNative.performNativeCalculation(5.0, 2.0);
```

## Platform-specific details

Each platform implements the `performNativeCalculation` method differently to showcase how to customize native code per platform:

- **iOS**: Implements multiplication and addition: (a * b) + 10
- **Android**: Implements power operation: a^b
- **macOS**: Calculates average multiplied by CPU core count: ((a + b) / 2) * cores
- **Windows**: Implements difference squared: (a - b)²
- **Linux**: Coming soon

## Example

Check out the example app to see the plugin in action. It provides a simple UI to test the native calculations on different platforms.

