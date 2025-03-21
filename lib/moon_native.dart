import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
}

enum MoonNavigationMode { threeButton, twoButton, fullGesture }
