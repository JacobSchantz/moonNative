import 'dart:typed_data';
import 'dart:async';

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

  /// Plays a system sound
  ///
  /// Parameters:
  /// - frequency: (Optional) The frequency of the beep in Hz (Android only)
  /// - durationMs: (Optional) The duration of the beep in milliseconds (Android only)
  /// - volume: (Optional) The volume of the beep from 0.0 to 1.0 (Android only)
  /// - soundId: (Optional) The iOS system sound ID to play (iOS only), defaults to 1304 (chime sound)
  ///           Some common system sound IDs:
  ///           - 1000: Standard system sound
  ///           - 1057: Standard beep
  ///           - 1304: Mail notification (chime)
  ///           - 1307: Message sent (swoosh)
  ///
  /// Returns true if the sound was played successfully, false otherwise
  Future<bool> playBeep({int frequency = 1000, int durationMs = 200, double volume = 1.0, int? soundId}) {
    throw UnimplementedError('playBeep() has not been implemented.');
  }

  /// Gets the navigation mode on Android (whether it uses gesture navigation or back button)
  ///
  /// Returns a map containing:
  /// - isGestureNavigation: true if the device uses gesture navigation, false if it uses buttons
  /// - navigationMode: the raw navigation mode value (Android only):
  ///   - 0: 3-button navigation (back, home, recents)
  ///   - 1: 2-button navigation (back gesture, home pill)
  ///   - 2: Gesture navigation (all gestures)
  Future<Map<String, dynamic>?> getNavigationMode() {
    throw UnimplementedError('getNavigationMode() has not been implemented.');
  }

  /// Compresses an image file from a path
  ///
  /// Parameters:
  /// - imagePath: Path to the input image file
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to source format
  ///
  /// Returns the path to the compressed image file
  Future<String?> compressImageFromPath({
    required String imagePath,
    required int quality,
    String? format,
  }) {
    throw UnimplementedError('compressImageFromPath() has not been implemented.');
  }

  /// Compresses an image from bytes
  ///
  /// Parameters:
  /// - imageBytes: Raw bytes of the input image
  /// - quality: Quality of the compressed image (0-100), where 100 is highest quality
  /// - format: (Optional) Output format ('jpg', 'png', or 'webp'), defaults to 'jpg' if not specified
  ///
  /// Returns the compressed image as bytes
  Future<Uint8List?> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String? format,
  }) {
    throw UnimplementedError('compressImageFromBytes() has not been implemented.');
  }
  
  /// Enqueues a video for background compression
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - quality: Quality of the compressed video (0-100), where 100 is highest quality
  /// - resolution: Target resolution e.g. '720p', '480p', '360p' (optional)
  /// - bitrate: Target bitrate in bits per second (optional)
  /// - customId: Optional custom identifier for tracking the compression task
  ///
  /// Returns a Future<bool> that resolves to true if enqueuing was successful,
  /// and the compressionId of the task is stored internally.
  /// To monitor the progress, use the videoCompressionUpdates getter.
  Future<bool> enqueueVideoCompression({
    required String videoPath,
    required int quality,
    String? resolution,
    int? bitrate,
    String? customId,
  }) {
    throw UnimplementedError('enqueueVideoCompression() has not been implemented.');
  }
  
  /// Stream of video compression status updates
  ///
  /// This stream emits updates for all ongoing video compression tasks, including:
  /// - progress: A value between 0.0 and 1.0 indicating progress
  /// - status: 'processing', 'completed', 'error', or 'cancelled'
  /// - compressionId: The unique ID of the compression task
  /// - outputPath: Path to the compressed video file (when completed)
  /// - error: Error message (if error occurred)
  Stream<VideoCompressionUpdate> get videoCompressionUpdates {
    throw UnimplementedError('videoCompressionUpdates has not been implemented.');
  }
  
  /// Cancels an ongoing video compression task
  ///
  /// Parameters:
  /// - compressionId: The unique ID of the compression task to cancel
  ///
  /// Returns true if successfully cancelled, false otherwise
  Future<bool> cancelVideoCompression(String compressionId) {
    throw UnimplementedError('cancelVideoCompression() has not been implemented.');
  }
  
  /// Gets the current ringer mode of the device
  ///
  /// Returns the ringer mode as a map containing:
  /// - ringerMode: Integer representing the ringer mode:
  ///   - 0: Silent mode - No sound, may or may not vibrate depending on device settings
  ///   - 1: Vibrate mode - No sound, but will vibrate
  ///   - 2: Normal mode - Sound and vibration are enabled
  /// - hasSound: true if the ringer will produce sound
  /// - hasVibration: true if the ringer will vibrate
  Future<Map<String, dynamic>?> getRingerMode() {
    throw UnimplementedError('getRingerMode() has not been implemented.');
  }
}

/// Represents a video compression status update
class VideoCompressionUpdate {
  /// Current status of the compression task
  final VideoCompressionStatus status;
  
  /// Progress value between 0.0 and 1.0
  final double progress;
  
  /// Unique ID of the compression task
  final String compressionId;
  
  /// Path to the output file (only valid when status is completed)
  final String? outputPath;
  
  /// Error message (only valid when status is error)
  final String? error;
  
  VideoCompressionUpdate({
    required this.status,
    required this.progress,
    required this.compressionId,
    this.outputPath,
    this.error,
  });
}

/// Possible states of a video compression task
enum VideoCompressionStatus {
  /// Compression is in progress
  processing,
  
  /// Compression has completed successfully
  completed,
  
  /// An error occurred during compression
  error,
  
  /// Compression was cancelled
  cancelled,
}

/// Possible ringer mode states
enum MoonRingerMode {
  /// Silent mode (no sound)
  silent,
  
  /// Vibrate mode (no sound, with vibration)
  vibrate,
  
  /// Normal mode (sound on)
  normal,
}
