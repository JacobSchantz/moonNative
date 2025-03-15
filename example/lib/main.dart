import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:moon_native/moon_native_test_screen.dart';

void main() {
  // Ensure plugins are registered for web platform
  if (kIsWeb) {
    // Web plugin registration will be handled automatically by Flutter
    // We don't need to manually call registerPlugins
  }
  
  runApp(const MoonNativeTestScreen());
}
