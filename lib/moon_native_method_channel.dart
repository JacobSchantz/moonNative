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
  Future<String?> rotateVideo(String videoPath, int quarterTurns) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'quarterTurns': quarterTurns,
    };
    return await methodChannel.invokeMethod<String>('rotateVideo', args);
  }
}
