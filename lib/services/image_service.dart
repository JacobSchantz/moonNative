import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moon_native/moon_native.dart';

class ImageService {
  Future<Uint8List> downloadImageBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
    return response.bodyBytes;
  }
  
  Future<CompressedImageResult> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String format = 'jpg',
  }) async {
    final compressedPath = await MoonNative.compressImage(
      imageBytes: imageBytes,
      quality: quality,
      format: format,
    );
    
    if (compressedPath == null) {
      throw Exception('Image compression failed');
    }
    
    final compressedFile = File(compressedPath);
    final compressedSize = compressedFile.lengthSync();
    final originalSize = imageBytes.length;
    final ratio = originalSize / compressedSize;
    
    return CompressedImageResult(
      originalBytes: imageBytes,
      compressedPath: compressedPath,
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionRatio: ratio,
    );
  }
}

class CompressedImageResult {
  final Uint8List originalBytes;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  
  CompressedImageResult({
    required this.originalBytes,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
  });
  
  String get originalSizeFormatted => '${(originalSize / 1024).toStringAsFixed(2)} KB';
  String get compressedSizeFormatted => '${(compressedSize / 1024).toStringAsFixed(2)} KB';
  String get compressionRatioFormatted => '${compressionRatio.toStringAsFixed(2)}x ($originalSizeFormatted → $compressedSizeFormatted)';
}
