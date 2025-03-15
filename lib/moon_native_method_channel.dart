import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'moon_native_platform_interface.dart';

/// An implementation of [MoonNativePlatform] that uses method channels.
class MethodChannelMoonNative extends MoonNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('moon_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'startTime': startTime,
      'endTime': endTime,
    };
    return await methodChannel.invokeMethod<String>('trimVideo', args);
  }

  @override
  Future<String?> rotateVideo(String videoPath, int clockwiseQuarterTurns) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'quarterTurns': clockwiseQuarterTurns, // Keep parameter name as 'quarterTurns' for native interface compatibility
    };
    return await methodChannel.invokeMethod<String>('rotateVideo', args);
  }

  @override
  Future<bool> playBeep({int frequency = 1000, int durationMs = 200, double volume = 1.0}) async {
    final Map<String, dynamic> args = {
      'frequency': frequency,
      'durationMs': durationMs,
      'volume': volume,
    };
    return await methodChannel.invokeMethod<bool>('playBeep', args) ?? false;
  }

  @override
  Future<String?> compressImageFromPath({
    required String imagePath,
    required int quality,
    String? format,
  }) async {
    final Map<String, dynamic> args = {
      'imagePath': imagePath,
      'quality': quality,
      'format': format,
    };

    return await methodChannel.invokeMethod<String>('compressImageFromPath', args);
  }

  @override
  Future<Uint8List?> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String? format,
  }) async {
    // Validate that the bytes are not empty
    if (imageBytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }
    
    final Map<String, dynamic> args = {
      'imageBytes': imageBytes,
      'quality': quality,
      'format': format,
    };

    return await methodChannel.invokeMethod<Uint8List>('compressImageFromBytes', args);
  }
}
