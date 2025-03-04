import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'moon_native_method_channel.dart';

abstract class MoonNativePlatform extends PlatformInterface {
  /// Constructs a MoonNativePlatform.
  MoonNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static MoonNativePlatform _instance = MethodChannelMoonNative();

  /// The default instance of [MoonNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelMoonNative].
  static MoonNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MoonNativePlatform] when
  /// they register themselves.
  static set instance(MoonNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  
  /// Performs a native calculation and returns the result
  /// 
  /// The calculation is performed on the native side and may vary by platform.
  /// Each platform should implement a simple calculation (e.g., adding two numbers)
  /// but with platform-specific features or optimizations.
  Future<double> performNativeCalculation(double a, double b) {
    throw UnimplementedError('performNativeCalculation() has not been implemented.');
  }
}
