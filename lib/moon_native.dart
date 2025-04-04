import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'moon_native_platform_interface.dart';

// Export test screen so it can be imported in other projects
export 'moon_native_test_screen.dart';
// Export video compression types so they can be used in other projects
export 'moon_native_platform_interface.dart' show VideoCompressionUpdate, VideoCompressionStatus, MoonRingerMode;

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
    assert(clockwiseQuarterTurns >= 1 && clockwiseQuarterTurns <= 3, 'clockwiseQuarterTurns must be between 1 and 3 inclusive');
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

  /// Gets the navigation mode on Android (whether it uses gesture navigation or back button)
  ///
  /// Returns the navigation mode as a MoonNavigationMode enum:
  ///   - MoonNavigationMode.threeButton: 3-button navigation (back, home, recents)
  ///   - MoonNavigationMode.twoButton: 2-button navigation (back gesture, home pill)
  ///   - MoonNavigationMode.fullGesture: Gesture navigation (all gestures)
  ///
  /// Returns null on iOS or if the detection fails
  static Future<MoonNavigationMode?> getNavigationMode() async {
    final result = await MoonNativePlatform.instance.getNavigationMode();
    if (result == null) return null;

    final navigationMode = result['navigationMode'] as int;

    switch (navigationMode) {
      case 0:
        return MoonNavigationMode.threeButton;
      case 1:
        return MoonNavigationMode.twoButton;
      case 2:
        return MoonNavigationMode.fullGesture;
      default:
        debugPrint('MoonNative: Unknown navigation mode: $navigationMode');
        return null;
    }
  }

  /// Compresses an image from a file path
  ///
  /// Parameters:
  /// - imagePath: Path to the input image file
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to source format
  ///
  /// Returns the path to the compressed image file or null if compression failed.
  /// If the compressed image is larger than the original, the original image is returned.
  static Future<String?> compressImageFromPath({
    required String imagePath,
    required int quality,
    String? format,
  }) async {
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100 inclusive');

    // Validate the input file exists
    final inputFile = File(imagePath);
    if (!await inputFile.exists()) {
      debugPrint('MoonNative: Input file does not exist: $imagePath');
      return null;
    }

    debugPrint('MoonNative: Compressing image from path: $imagePath');
    debugPrint('MoonNative: File exists: ${await inputFile.exists()}, size: ${await inputFile.length()} bytes');

    try {
      // First, compress the image using the platform implementation
      final compressedPath = await MoonNativePlatform.instance.compressImageFromPath(
        imagePath: imagePath,
        quality: quality,
        format: format,
      );

      if (compressedPath == null) {
        debugPrint('MoonNative: Compression returned null path');
        return null; // Compression failed
      }

      debugPrint('MoonNative: Compression returned path: $compressedPath');

      // Verify the compressed file exists
      final compressedFile = File(compressedPath);
      if (!await compressedFile.exists()) {
        debugPrint('MoonNative: Compressed file does not exist: $compressedPath');
        return null;
      }

      // Compare file sizes to ensure we're not increasing the size
      try {
        // For file path input, compare file sizes
        final originalSize = await inputFile.length();
        final compressedSize = await compressedFile.length();

        debugPrint('MoonNative: Original size: $originalSize bytes, Compressed size: $compressedSize bytes');

        if (compressedSize > originalSize) {
          debugPrint('MoonNative: Compression increased file size. Using original instead.');
          return imagePath; // Return original path if compression increased size
        }

        return compressedPath;
      } catch (e) {
        debugPrint('MoonNative: Error comparing file sizes: $e');
        return compressedPath; // Return the compressed path anyway if we can't compare sizes
      }
    } catch (e) {
      debugPrint('MoonNative: Error in compressImageFromPath: $e');
      return null;
    }
  }

  /// Compresses an image from bytes
  ///
  /// Parameters:
  /// - imageBytes: Raw bytes of the input image
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to 'jpg' if not specified
  ///
  /// Returns the compressed image as bytes or null if compression failed.
  /// If the compressed image is larger than the original, the original bytes are returned.
  static Future<Uint8List?> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String? format,
  }) async {
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100 inclusive');

    // First, compress the image using the platform implementation
    final compressedBytes = await MoonNativePlatform.instance.compressImageFromBytes(
      imageBytes: imageBytes,
      quality: quality,
      format: format,
    );

    if (compressedBytes == null) {
      return null; // Compression failed
    }

    // Compare sizes to ensure we're not increasing the size
    final originalSize = imageBytes.length;
    final compressedSize = compressedBytes.length;

    if (compressedSize > originalSize) {
      debugPrint('MoonNative: Compression increased file size. Using original instead.');
      debugPrint('MoonNative: Original: $originalSize bytes, Compressed: $compressedSize bytes');
      return imageBytes; // Return original bytes if compressed is larger
    } else {
      debugPrint('MoonNative: Compression successful, reduced size by ${originalSize - compressedSize} bytes');
      return compressedBytes;
    }
  }

  /// Enqueues a video for background compression
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - quality: Quality of the compressed video (0-100), where 100 is highest quality
  ///   Use the VideoQuality class constants for common presets
  /// - resolution: Target resolution e.g. '720p', '480p', '360p' (optional)
  ///   Use the VideoResolution class constants for common resolutions
  /// - bitrate: Target bitrate in bits per second (optional)
  /// - customId: Optional custom identifier for tracking the task throughout its lifecycle
  ///
  /// Returns a Future<bool> that resolves to true if enqueuing was successful.
  /// To monitor the progress, use the videoCompressionUpdates getter.
  static Future<bool> enqueueVideoCompression({
    required String videoPath,
    required int quality,
    String? resolution,
    int? bitrate,
    String? customId,
  }) {
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100 inclusive');
    return MoonNativePlatform.instance.enqueueVideoCompression(
      videoPath: videoPath,
      quality: quality,
      resolution: resolution,
      bitrate: bitrate,
      customId: customId,
    );
  }

  /// Stream of video compression status updates
  ///
  /// This stream emits updates for all ongoing video compression tasks, including:
  /// - progress: A value between 0.0 and 1.0 indicating progress
  /// - status: VideoCompressionStatus enum (processing, completed, error, or cancelled)
  /// - compressionId: The unique ID of the compression task
  /// - outputPath: Path to the compressed video file (when completed)
  /// - error: Error message (if error occurred)
  static Stream<VideoCompressionUpdate> get videoCompressionUpdates {
    return MoonNativePlatform.instance.videoCompressionUpdates;
  }

  /// Cancels an ongoing video compression task
  ///
  /// Parameters:
  /// - compressionId: The unique ID of the compression task to cancel
  ///
  /// Returns true if successfully cancelled, false otherwise
  static Future<bool> cancelVideoCompression(String compressionId) {
    return MoonNativePlatform.instance.cancelVideoCompression(compressionId);
  }

  /// Gets the current ringer mode of the device
  ///
  /// Returns the ringer mode as a MoonRingerMode enum:
  ///   - MoonRingerMode.silent: Silent mode (no sound)
  ///   - MoonRingerMode.vibrate: Vibrate mode (no sound, with vibration)
  ///   - MoonRingerMode.normal: Normal mode (sound on)
  ///
  /// Also returns a map with additional information:
  ///   - hasSound: true if the ringer will produce sound
  ///   - hasVibration: true if the ringer will vibrate
  ///
  /// Implementation details per platform:
  ///   - Android: Uses AudioManager to get precise ringer mode
  ///   - iOS: Uses notification settings to determine if device is in silent mode
  ///
  /// Returns null if getting the ringer mode fails.
  static Future<Map<String, dynamic>?> getRingerMode() async {
    try {
      // Call platform implementation
      final result = await MoonNativePlatform.instance.getRingerMode();
      if (result == null) {
        debugPrint('MoonNative: getRingerMode() returned null from platform implementation');
        return null;
      }

      // Make sure we have a 'ringerMode' key
      if (!result.containsKey('ringerMode')) {
        debugPrint('MoonNative: Platform implementation returned map without ringerMode key');
        // Default to normal mode if ringerMode key is missing
        result['ringerMode'] = 2;
      }

      // Safe type casting with fallback
      int ringerModeInt;
      try {
        ringerModeInt = result['ringerMode'] as int? ?? 2; // Default to normal mode
      } catch (e) {
        debugPrint('MoonNative: Error casting ringerMode to int: $e');
        // Try to parse it if it's a string
        if (result['ringerMode'] is String) {
          try {
            ringerModeInt = int.parse(result['ringerMode'] as String);
          } catch (_) {
            ringerModeInt = 2; // Default to normal if parsing fails
          }
        } else {
          ringerModeInt = 2; // Default to normal mode
        }
      }

      // Validate range
      if (ringerModeInt < 0 || ringerModeInt > 2) {
        debugPrint('MoonNative: Invalid ringerMode value: $ringerModeInt, using default');
        ringerModeInt = 2; // Default to normal mode if out of range
      }

      // Map to enum
      MoonRingerMode mode;
      switch (ringerModeInt) {
        case 0:
          mode = MoonRingerMode.silent;
          break;
        case 1:
          mode = MoonRingerMode.vibrate;
          break;
        case 2:
        default:
          mode = MoonRingerMode.normal;
          break;
      }

      // Safely check for sound and vibration flags
      bool hasSound = false;
      bool hasVibration = false;

      try {
        hasSound = result['hasSound'] as bool? ?? false;
      } catch (e) {
        debugPrint('MoonNative: Error parsing hasSound: $e');
        // If there's a string, try to parse it as bool
        if (result['hasSound'] is String) {
          hasSound = (result['hasSound'] as String).toLowerCase() == 'true';
        }
        // For ringerMode normal, assume sound is on
        if (ringerModeInt == 2) hasSound = true;
      }

      try {
        hasVibration = result['hasVibration'] as bool? ?? false;
      } catch (e) {
        debugPrint('MoonNative: Error parsing hasVibration: $e');
        // If there's a string, try to parse it as bool
        if (result['hasVibration'] is String) {
          hasVibration = (result['hasVibration'] as String).toLowerCase() == 'true';
        }
        // For ringerMode vibrate or normal, assume vibration is on
        if (ringerModeInt == 1 || ringerModeInt == 2) hasVibration = true;
      }

      return {
        'mode': mode,
        'hasSound': hasSound,
        'hasVibration': hasVibration,
      };
    } catch (e, stackTrace) {
      // Catch any other errors
      debugPrint('MoonNative: Unexpected error in getRingerMode: $e');
      debugPrint('MoonNative: Stack trace: $stackTrace');
      return null;
    }
  }
}

enum MoonNavigationMode { threeButton, twoButton, fullGesture }

/// Video compression quality presets
class VideoQuality {
  /// Low quality - smaller file size (25% quality)
  static const int low = 25;

  /// Medium quality - balanced (50% quality)
  static const int medium = 50;

  /// High quality - larger file size (75% quality)
  static const int high = 75;

  /// Maximum quality - very large file size (100% quality)
  static const int maximum = 100;
}

/// Standard video resolutions
class VideoResolution {
  /// 480p resolution (854x480)
  static const String sd480 = '480p';

  /// 720p resolution (1280x720)
  static const String hd720 = '720p';

  /// 1080p resolution (1920x1080)
  static const String fullHd = '1080p';

  /// 2K resolution (2560x1440)
  static const String qhd = '1440p';

  /// 4K resolution (3840x2160)
  static const String uhd = '2160p';
}
