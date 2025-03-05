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
  Future<double> performNativeCalculation(double a, double b) async {
    final Map<String, dynamic> args = {
      'a': a,
      'b': b,
    };
    final result = await methodChannel.invokeMethod<double>('performNativeCalculation', args);
    return result ?? 0.0;
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
  Future<String?> downloadVideo(String url, String localPath) async {
    final Map<String, dynamic> args = {
      'url': url,
      'localPath': localPath,
    };
    return await methodChannel.invokeMethod<String>('downloadVideo', args);
  }

  @override
  Future<double?> getVideoDuration(String videoPath) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
    };
    return await methodChannel.invokeMethod<double>('getVideoDuration', args);
  }
}
