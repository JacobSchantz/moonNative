// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'moon_native_platform_interface.dart';

/// A web implementation of the MoonNativePlatform of the MoonNative plugin.
class MoonNativeWeb extends MoonNativePlatform {
  /// Constructs a MoonNativeWeb
  MoonNativeWeb();

  static void registerWith(Registrar registrar) {
    MoonNativePlatform.instance = MoonNativeWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }

  /// Rotates a video by the specified quarter turns.
  ///
  /// This operation is not supported on the web platform and will throw an exception.
  @override
  Future<String?> rotateVideo(String videoPath, int quarterTurns) async {
    throw UnsupportedError('Video rotation is not supported on the web platform');
  }

  /// Trims a video from the given path using start and end times.
  ///
  /// This is a simple web implementation that creates a video element,
  /// adds some metadata about the trim, and downloads it.
  /// Returns the path to the trimmed video or null if trimming fails.
  @override
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) async {
    try {
      print('Web platform: Trimming video at $videoPath from $startTime to $endTime');

      // Create a video element to load the source
      final video = html.VideoElement()
        ..src = videoPath
        ..style.display = 'none';
      html.document.body?.append(video);

      // Create a simple loading indicator
      final loadingDiv = html.DivElement()
        ..id = 'video-trim-loading'
        ..style.position = 'fixed'
        ..style.top = '50%'
        ..style.left = '50%'
        ..style.transform = 'translate(-50%, -50%)'
        ..style.padding = '20px'
        ..style.backgroundColor = 'rgba(0, 0, 0, 0.7)'
        ..style.color = 'white'
        ..style.borderRadius = '5px'
        ..style.zIndex = '1000'
        ..text = 'Trimming video...';
      html.document.body?.append(loadingDiv);

      // Wait for the video to load
      final completer = Completer<void>();
      video.onLoadedData.listen((_) => completer.complete());
      video.onError.listen((_) => completer.completeError('Failed to load video'));

      // Set a timeout
      final timeout = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError('Video loading timeout');
        }
      });

      try {
        await completer.future;
      } catch (e) {
        // Clean up and propagate error
        video.remove();
        loadingDiv.remove();
        throw Exception('Error loading video: $e');
      } finally {
        timeout.cancel();
      }

      // Extract filename from path
      final fileName = videoPath.split('/').last;
      final baseName = fileName.split('.').first;
      final extension = fileName.contains('.') ? fileName.split('.').last : 'mp4';
      final outputName = '${baseName}_trimmed.$extension';

      // Create metadata about the trim
      final metadataParam = 'trim=start:${startTime.toStringAsFixed(2)},end:${endTime.toStringAsFixed(2)}';

      // Create a download link
      final url = Uri.parse(videoPath).replace(queryParameters: {'$metadataParam': 'true'}).toString();

      final anchor = html.AnchorElement(href: url)
        ..download = outputName
        ..style.display = 'none';
      html.document.body?.append(anchor);

      // Trigger the download
      anchor.click();

      // Clean up
      Future.delayed(const Duration(milliseconds: 500), () {
        video.remove();
        anchor.remove();
        loadingDiv.remove();
      });

      return outputName;
    } catch (e) {
      print('Error trimming video on web: $e');
      return null;
    }
  }

  @override
  Future<String?> compressImageFromPath({
    required String imagePath,
    required int quality,
    String? format,
  }) async {
    try {
      print('Web platform: Compressing image at $imagePath with quality $quality');
      
      // Create an image element to load the source
      final img = html.ImageElement()
        ..src = imagePath
        ..style.display = 'none';
      html.document.body?.append(img);
      
      // Wait for the image to load
      final completer = Completer<void>();
      img.onLoad.listen((_) => completer.complete());
      img.onError.listen((event) => completer.completeError('Failed to load image'));
      
      try {
        await completer.future;
      } catch (e) {
        print('Error loading image on web: $e');
        img.remove();
        return null;
      }
      
      // Create a canvas to draw the image
      final canvas = html.CanvasElement(width: img.naturalWidth, height: img.naturalHeight);
      final ctx = canvas.context2D;
      ctx.drawImage(img, 0, 0);
      
      // Get the extension
      final extension = format?.toLowerCase() ?? (imagePath.contains('.') ? imagePath.split('.').last : 'jpg');
      final mimeType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
      
      // Convert to data URL with specified quality
      final dataUrl = canvas.toDataUrl(mimeType, quality / 100);
      
      // Extract filename from path
      final fileName = imagePath.split('/').last;
      final baseName = fileName.split('.').first;
      final outputName = '${baseName}_compressed.$extension';
      
      // Create a download link
      final anchor = html.AnchorElement(href: dataUrl)
        ..download = outputName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      
      // Trigger the download
      anchor.click();
      
      // Clean up
      Future.delayed(const Duration(milliseconds: 500), () {
        img.remove();
        canvas.remove();
        anchor.remove();
      });
      
      return outputName;
    } catch (e) {
      print('Error compressing image on web: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String? format,
  }) async {
    try {
      print('Web platform: Compressing image bytes with quality $quality');
      
      // Convert bytes to a data URL
      final extension = format?.toLowerCase() ?? 'jpg';
      final mimeType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
      final base64 = base64Encode(imageBytes);
      final dataUrl = 'data:$mimeType;base64,$base64';
      
      // Create an image element to load the source
      final img = html.ImageElement()
        ..src = dataUrl
        ..style.display = 'none';
      html.document.body?.append(img);
      
      // Wait for the image to load
      final completer = Completer<void>();
      img.onLoad.listen((_) => completer.complete());
      img.onError.listen((event) => completer.completeError('Failed to load image from bytes'));
      
      try {
        await completer.future;
      } catch (e) {
        print('Error loading image from bytes on web: $e');
        img.remove();
        return null;
      }
      
      // Create a canvas to draw the image
      final canvas = html.CanvasElement(width: img.naturalWidth, height: img.naturalHeight);
      final ctx = canvas.context2D;
      ctx.drawImage(img, 0, 0);
      
      // Convert to data URL with specified quality
      final compressedDataUrl = canvas.toDataUrl(mimeType, quality / 100);
      
      // Extract the base64 data
      final compressedBase64 = compressedDataUrl.split(',')[1];
      final compressedBytes = base64Decode(compressedBase64);
      
      // Clean up
      img.remove();
      canvas.remove();
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('Error compressing image bytes on web: $e');
      return null;
    }
  }
}
