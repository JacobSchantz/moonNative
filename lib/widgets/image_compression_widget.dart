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
  final TextEditingController _urlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _originalImageBytes;
  String? _compressedImagePath;
  Uint8List? _compressedImageBytes;
  String? _compressionRatio;
  String? _compressionRatioFromBytes;
  int _imageQuality = 80;
  String _imageFormat = 'jpg';
  String? _tempImagePath;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.defaultImageUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

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

            // URL input field
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                border: OutlineInputBorder(),
                hintText: 'Enter URL of image to download',
              ),
            ),
            const SizedBox(height: 16),

            // Compression controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _downloadAndCompressImage,
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Processing...'),
                            ],
                          )
                        : const Text('Download Image'),
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

            // Compression method buttons
            if (_originalImageBytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _compressFromPath,
                        child: const Text('Compress from Path'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _compressFromBytes,
                        child: const Text('Compress from Bytes'),
                      ),
                    ),
                  ],
                ),
              ),

            // Image preview
            if (_originalImageBytes != null)
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
                  if (_compressedImagePath != null || _compressedImageBytes != null)
                    Row(
                      children: [
                        // Compressed from Path
                        if (_compressedImagePath != null)
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
                        if (_compressedImagePath != null && _compressedImageBytes != null)
                          const SizedBox(width: 16),
                        // Compressed from Bytes
                        if (_compressedImageBytes != null)
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
                                    child: Image.memory(
                                      _compressedImageBytes!,
                                      fit: BoxFit.contain,
                                    ),
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

  Future<void> _downloadAndCompressImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _compressedImagePath = null;
      _compressedImageBytes = null;
      _compressionRatio = null;
      _compressionRatioFromBytes = null;
    });

    try {
      final imageUrl = _urlController.text.trim();
      if (imageUrl.isEmpty) {
        throw Exception('Please enter a valid image URL');
      }

      // Download image bytes
      final imageBytes = await _imageService.downloadImageBytes(imageUrl);
      _originalImageBytes = imageBytes;

      // Save bytes to a temporary file to test path-based compression
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_image.jpg');
      await tempFile.writeAsBytes(imageBytes);
      _tempImagePath = tempFile.path;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error downloading image: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _compressFromPath() async {
    if (_tempImagePath == null) {
      setState(() {
        _errorMessage = 'No image available to compress';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _compressedImagePath = null;
      _compressionRatio = null;
    });

    try {
      // Compress using path
      final pathResult = await MoonNative.compressImageFromPath(
        imagePath: _tempImagePath!,
        quality: _imageQuality,
        format: _imageFormat,
      );

      if (pathResult == null) {
        throw Exception('Path-based compression failed');
      }

      // Calculate compression ratio
      final originalSize = _originalImageBytes!.length;
      final pathCompressedSize = File(pathResult).lengthSync();
      final pathRatio = originalSize / pathCompressedSize;

      setState(() {
        _compressedImagePath = pathResult;
        _compressionRatio = '${pathRatio.toStringAsFixed(2)}x (${(originalSize / 1024).toStringAsFixed(2)} KB → ${(pathCompressedSize / 1024).toStringAsFixed(2)} KB)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error compressing from path: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _compressFromBytes() async {
    if (_originalImageBytes == null) {
      setState(() {
        _errorMessage = 'No image available to compress';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _compressedImageBytes = null;
      _compressionRatioFromBytes = null;
    });

    try {
      // Compress using bytes
      final compressedBytes = await MoonNative.compressImageFromBytes(
        imageBytes: _originalImageBytes!,
        quality: _imageQuality,
        format: _imageFormat,
      );

      if (compressedBytes == null) {
        throw Exception('Bytes-based compression failed');
      }

      // Calculate compression ratio
      final originalSize = _originalImageBytes!.length;
      final bytesCompressedSize = compressedBytes.length;
      final bytesRatio = originalSize / bytesCompressedSize;

      setState(() {
        _compressedImageBytes = compressedBytes;
        _compressionRatioFromBytes = '${bytesRatio.toStringAsFixed(2)}x (${(originalSize / 1024).toStringAsFixed(2)} KB → ${(bytesCompressedSize / 1024).toStringAsFixed(2)} KB)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error compressing from bytes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
