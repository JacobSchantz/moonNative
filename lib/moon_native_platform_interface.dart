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

  /// Downloads a video from a URL to a local path
  ///
  /// Parameters:
  /// - url: The URL of the video to download
  /// - localPath: The local path where the video should be saved
  ///
  /// Returns the path to the downloaded video or null if download failed
  Future<String?> downloadVideo(String url, String localPath) {
    throw UnimplementedError('downloadVideo() has not been implemented.');
  }

  /// Gets the duration of a video at the specified path
  ///
  /// Parameters:
  /// - videoPath: Path to the video file
  ///
  /// Returns the duration of the video in seconds or null if getting duration failed
  Future<double?> getVideoDuration(String videoPath) {
    throw UnimplementedError('getVideoDuration() has not been implemented.');
  }
}
