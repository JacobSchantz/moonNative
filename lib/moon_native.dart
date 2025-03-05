import 'moon_native_platform_interface.dart';
import 'dart:async';

// Export test screen so it can be imported in other projects
export 'moon_native_test_screen.dart';

class MoonNative {
  Future<String?> getPlatformVersion() {
    return MoonNativePlatform.instance.getPlatformVersion();
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
}
