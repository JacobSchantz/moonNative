import 'moon_native_platform_interface.dart';
import 'dart:async';

class MoonNative {
  Future<String?> getPlatformVersion() {
    return MoonNativePlatform.instance.getPlatformVersion();
  }

  /// Performs a calculation on the native side
  ///
  /// Each platform implements this differently to demonstrate
  /// native code integration.
  ///
  /// Parameters:
  ///   a - First operand
  ///   b - Second operand
  ///
  /// Returns the result of the platform-specific calculation.
  Future<double> performNativeCalculation(double a, double b) {
    return MoonNativePlatform.instance.performNativeCalculation(a, b);
  }

  /// Trims a video to the specified duration
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - startTime: Start time in seconds
  /// - endTime: End time in seconds
  ///
  /// Returns the path to the trimmed video file or null if trimming failed
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) {
    return MoonNativePlatform.instance.trimVideo(videoPath, startTime, endTime);
  }

  /// Downloads a video from a URL to a local path
  ///
  /// Parameters:
  /// - url: The URL of the video to download
  /// - localPath: The local path where the video should be saved
  ///
  /// Returns the path to the downloaded video or null if download failed
  Future<String?> downloadVideo(String url, String localPath) {
    return MoonNativePlatform.instance.downloadVideo(url, localPath);
  }

  /// Gets the duration of a video at the specified path
  ///
  /// Parameters:
  /// - videoPath: Path to the video file
  ///
  /// Returns the duration of the video in seconds or null if getting duration failed
  Future<double?> getVideoDuration(String videoPath) {
    return MoonNativePlatform.instance.getVideoDuration(videoPath);
  }
}
