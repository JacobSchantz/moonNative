import 'dart:typed_data';

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
  
  /// Rotates a video by the specified clockwise quarter turns
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - clockwiseQuarterTurns: Number of 90° clockwise rotations (1=90°, 2=180°, 3=270°)
  ///   Must be a value between 1 and 3 inclusive.
  ///
  /// Returns the path to the rotated video file
  Future<String?> rotateVideo(String videoPath, int clockwiseQuarterTurns) {
    throw UnimplementedError('rotateVideo() has not been implemented.');
  }
  
  /// Plays a short beep sound
  ///
  /// Parameters:
  /// - frequency: (Optional) The frequency of the beep in Hz (Android only)
  /// - durationMs: (Optional) The duration of the beep in milliseconds (Android only)
  /// - volume: (Optional) The volume of the beep from 0.0 to 1.0 (Android only)
  ///
  /// Returns true if the beep was played successfully, false otherwise
  Future<bool> playBeep({int frequency = 1000, int durationMs = 200, double volume = 1.0}) {
    throw UnimplementedError('playBeep() has not been implemented.');
  }
  
  /// Compresses an image file or bytes
  ///
  /// Parameters:
  /// - imagePath: Path to the input image file (provide either imagePath or imageBytes)
  /// - imageBytes: Raw bytes of the input image (provide either imagePath or imageBytes)
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to source format
  ///
  /// Returns the path to the compressed image file
  Future<String?> compressImage({
    String? imagePath, 
    Uint8List? imageBytes,
    required int quality, 
    String? format,
  }) {
    throw UnimplementedError('compressImage() has not been implemented.');
  }
}
