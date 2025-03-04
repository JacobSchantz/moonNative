import 'package:flutter_test/flutter_test.dart';
import 'package:moon_native/moon_native.dart';
import 'package:moon_native/moon_native_platform_interface.dart';
import 'package:moon_native/moon_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMoonNativePlatform
    with MockPlatformInterfaceMixin
    implements MoonNativePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MoonNativePlatform initialPlatform = MoonNativePlatform.instance;

  test('$MethodChannelMoonNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMoonNative>());
  });

  test('getPlatformVersion', () async {
    MoonNative moonNativePlugin = MoonNative();
    MockMoonNativePlatform fakePlatform = MockMoonNativePlatform();
    MoonNativePlatform.instance = fakePlatform;

    expect(await moonNativePlugin.getPlatformVersion(), '42');
  });
}
