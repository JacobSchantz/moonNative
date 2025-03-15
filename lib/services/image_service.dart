import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moon_native/moon_native.dart';
import 'package:path_provider/path_provider.dart';

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
    final compressedBytes = await MoonNative.compressImageFromBytes(
      imageBytes: imageBytes,
      quality: quality,
      format: format,
    );
    
    if (compressedBytes == null) {
      throw Exception('Image compression failed');
    }
    
    // Save the compressed bytes to a temporary file to maintain compatibility
    final tempDir = await getTemporaryDirectory();
    final outputFileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputFile = File('${tempDir.path}/$outputFileName');
    await outputFile.writeAsBytes(compressedBytes);
    
    final compressedSize = compressedBytes.length;
    final originalSize = imageBytes.length;
    final ratio = originalSize / compressedSize;
    
    return CompressedImageResult(
      originalBytes: imageBytes,
      compressedPath: outputFile.path,
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
