import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moon_native/moon_native.dart';
import 'package:moon_native/services/image_service.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionWidget extends StatefulWidget {
  final String defaultImageUrl;
  
  const ImageCompressionWidget({
    Key? key, 
    required this.defaultImageUrl,
  }) : super(key: key);

  @override
  State<ImageCompressionWidget> createState() => _ImageCompressionWidgetState();
}

class _ImageCompressionWidgetState extends State<ImageCompressionWidget> {
  final ImageService _imageService = ImageService();
  
  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _originalImageBytes;
  String? _compressedImagePath;
  Uint8List? _compressedImageBytes; // Store bytes directly instead of path
  String? _compressionRatio;
  String? _compressionRatioFromBytes;
  int _imageQuality = 80;
  String _imageFormat = 'jpg';
  String? _tempImagePath;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Image Compression Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Compression controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _compressImageBothWays,
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Processing...'),
                            ],
                          )
                        : const Text('Test Both Compression Methods'),
                  ),
                ),
              ],
            ),
            
            // Quality slider
            Row(
              children: [
                const Text('Quality:'),
                Expanded(
                  child: Slider(
                    value: _imageQuality.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: _imageQuality.toString(),
                    onChanged: (value) => setState(() => _imageQuality = value.round()),
                  ),
                ),
                Text('$_imageQuality%'),
              ],
            ),
            
            // Format dropdown
            Row(
              children: [
                const Text('Format:'),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _imageFormat,
                  items: const [
                    DropdownMenuItem(value: 'jpg', child: Text('JPEG')),
                    DropdownMenuItem(value: 'png', child: Text('PNG')),
                    DropdownMenuItem(value: 'webp', child: Text('WebP')),
                  ],
                  onChanged: (value) => setState(() => _imageFormat = value!),
                ),
              ],
            ),
            
            // Image preview
            if (_originalImageBytes != null && _compressedImagePath != null && _compressedImageBytes != null)
              Column(
                children: [
                  // Original image
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Image', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 200,
                        child: Center(
                          child: Image.memory(
                            _originalImageBytes!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Text('Size: ${(_originalImageBytes!.length / 1024).toStringAsFixed(2)} KB'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Comparison results
                  Row(
                    children: [
                      // Compressed from Path
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Compressed from Path', style: TextStyle(fontWeight: FontWeight.bold)),
                            if (_compressionRatio != null) Text('Ratio: $_compressionRatio', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 150,
                              child: Center(
                                child: Image.file(
                                  File(_compressedImagePath!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Compressed from Bytes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Compressed from Bytes', style: TextStyle(fontWeight: FontWeight.bold)),
                            if (_compressionRatioFromBytes != null) Text('Ratio: $_compressionRatioFromBytes', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 150,
                              child: Center(
                                child: _compressedImageBytes != null
                                  ? Image.memory(
                                      _compressedImageBytes!,
                                      fit: BoxFit.contain,
                                    )
                                  : const Text('No image available'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: SelectableText(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy error message',
                      onPressed: () {
                        // Using Flutter's clipboard functionality
                        Clipboard.setData(ClipboardData(text: _errorMessage!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error message copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _compressImageBothWays() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Download image bytes
      final imageBytes = await _imageService.downloadImageBytes(widget.defaultImageUrl);
      _originalImageBytes = imageBytes;
      
      // Save bytes to a temporary file to test path-based compression
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_image.jpg');
      await tempFile.writeAsBytes(imageBytes);
      _tempImagePath = tempFile.path;
      
      // Method 1: Compress using path
      final pathResult = await MoonNative.compressImageFromPath(
        imagePath: _tempImagePath!,
        quality: _imageQuality,
        format: _imageFormat,
      );
      
      if (pathResult == null) {
        throw Exception('Path-based compression failed');
      }
      
      // Method 2: Compress using bytes
      final compressedBytes = await MoonNative.compressImageFromBytes(
        imageBytes: imageBytes,
        quality: _imageQuality,
        format: _imageFormat,
      );
      
      if (compressedBytes == null) {
        throw Exception('Bytes-based compression failed');
      }
      
      // Calculate compression ratios
      final originalSize = imageBytes.length;
      final pathCompressedSize = File(pathResult).lengthSync();
      final bytesCompressedSize = compressedBytes.length;
      
      final pathRatio = originalSize / pathCompressedSize;
      final bytesRatio = originalSize / bytesCompressedSize;
      
      setState(() {
        _compressedImagePath = pathResult;
        _compressedImageBytes = compressedBytes; // Store bytes directly
        _compressionRatio = '${pathRatio.toStringAsFixed(2)}x (${(originalSize / 1024).toStringAsFixed(2)} KB → ${(pathCompressedSize / 1024).toStringAsFixed(2)} KB)';
        _compressionRatioFromBytes = '${bytesRatio.toStringAsFixed(2)}x (${(originalSize / 1024).toStringAsFixed(2)} KB → ${(bytesCompressedSize / 1024).toStringAsFixed(2)} KB)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
