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

  /// Trims a video to the specified duration
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - startTime: Start time in seconds
  /// - endTime: End time in seconds
  ///
  /// Returns the path to the trimmed video file
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) {
    throw UnimplementedError('trimVideo() has not been implemented.');
  }
}
