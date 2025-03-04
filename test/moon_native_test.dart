import 'package:flutter_test/flutter_test.dart';
import 'package:moon_native/moon_native.dart';
import 'package:moon_native/moon_native_platform_interface.dart';
import 'package:moon_native/moon_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

class MockMoonNativePlatform extends Mock implements MoonNativePlatform {}

void main() {
  final MoonNativePlatform initialPlatform = MoonNativePlatform.instance;

  test('$MethodChannelMoonNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMoonNative>());
  });

  test('getPlatformVersion', () async {
    final moonNativePlugin = MoonNative();
    final fakePlatform = MockMoonNativePlatform();
    
    // Set up the mock
    when(() => fakePlatform.getPlatformVersion())
        .thenAnswer((_) async => '42');
    
    // Set the mock as the platform instance
    MoonNativePlatform.instance = fakePlatform;

    // Verify the result
    expect(await moonNativePlugin.getPlatformVersion(), '42');
  });
}
