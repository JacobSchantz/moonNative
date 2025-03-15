import 'dart:async';
import 'dart:typed_data';

import 'moon_native_platform_interface.dart';

// Export test screen so it can be imported in other projects
export 'moon_native_test_screen.dart';

class MoonNative {
  /// Private constructor to prevent instantiation
  MoonNative._();
  
  /// Gets the platform version
  static Future<String?> getPlatformVersion() {
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
  static Future<String?> trimVideo(String videoPath, double startTime, double endTime) {
    return MoonNativePlatform.instance.trimVideo(videoPath, startTime, endTime);
  }
  
  /// Rotates a video by the specified clockwise quarter turns
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - clockwiseQuarterTurns: Number of 90° clockwise rotations (1=90°, 2=180°, 3=270°)
  ///   Must be a value between 1 and 3 inclusive.
  ///
  /// Returns the path to the rotated video file or null if rotation failed
  static Future<String?> rotateVideo(String videoPath, int clockwiseQuarterTurns) {
    assert(clockwiseQuarterTurns >= 1 && clockwiseQuarterTurns <= 3, 
           'clockwiseQuarterTurns must be between 1 and 3 inclusive');
    return MoonNativePlatform.instance.rotateVideo(videoPath, clockwiseQuarterTurns);
  }
  
  /// Plays a short beep sound
  ///
  /// Parameters:
  /// - frequency: (Optional) The frequency of the beep in Hz (Android only)
  /// - durationMs: (Optional) The duration of the beep in milliseconds (Android only)
  /// - volume: (Optional) The volume of the beep from 0.0 to 1.0 (Android only)
  ///
  /// Returns true if the beep was played successfully, false otherwise
  static Future<bool> playBeep({int frequency = 1000, int durationMs = 200, double volume = 1.0}) {
    return MoonNativePlatform.instance.playBeep(
      frequency: frequency,
      durationMs: durationMs,
      volume: volume,
    );
  }
  
  /// Compresses an image from a file path or bytes
  ///
  /// Parameters:
  /// - imagePath: Path to the input image file (provide either imagePath or imageBytes)
  /// - imageBytes: Raw bytes of the input image (provide either imagePath or imageBytes)
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to source format
  ///
  /// Returns the path to the compressed image file or null if compression failed
  static Future<String?> compressImage({
    String? imagePath,
    Uint8List? imageBytes,
    required int quality,
    String? format,
  }) {
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100 inclusive');
    assert(imagePath != null || imageBytes != null, 'Either imagePath or imageBytes must be provided');
    
    return MoonNativePlatform.instance.compressImage(
      imagePath: imagePath,
      imageBytes: imageBytes,
      quality: quality,
      format: format,
    );
  }
}
