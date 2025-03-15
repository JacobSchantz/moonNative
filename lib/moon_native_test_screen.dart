import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:moon_native/moon_native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

class MoonNativeTestScreen extends StatelessWidget {
  const MoonNativeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Moon Native Test')),
        body: const SafeArea(
          child: MoonNativeTestWidget(),
        ),
      ),
    );
  }
}

class MoonNativeTestWidget extends StatefulWidget {
  const MoonNativeTestWidget({super.key});

  @override
  State<MoonNativeTestWidget> createState() => _MoonNativeTestWidgetState();
}

class _MoonNativeTestWidgetState extends State<MoonNativeTestWidget> {
  final TextEditingController _videoPathController = TextEditingController();
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _rotatedVideoController;
  String _videoDuration = 'Duration unknown';
  String _errorMessage = '';
  bool _isDownloading = false;
  bool _isTrimming = false;
  bool _isRotating = false;
  bool _isCompressingImage = false;
  String? _rotatedVideoPath;
  String? _originalImagePath;
  Uint8List? _originalImageBytes;
  String? _compressedImagePath;
  String? _compressionRatio;
  String? _compressedSize;
  int _clockwiseQuarterTurns = 1; // Default to 1 quarter turn (90 degrees clockwise)
  int _imageQuality = 80; // Default image compression quality
  String _imageFormat = 'jpg'; // Default image format
  final String _fixedVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';
  final String _fixedImageUrl = 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=2070&auto=format&fit=crop';

  @override
  void dispose() {
    _videoPathController.dispose();
    _videoPlayerController?.dispose();
    _rotatedVideoController?.dispose();
    super.dispose();
  }

  Future<void> _downloadAndCompressImage() async {
    setState(() {
      _errorMessage = '';
      _isCompressingImage = true;
      _compressedImagePath = null;
      _compressionRatio = null;
      _compressedSize = null;
    });

    try {
      // Download image from URL
      final appDir = await getApplicationDocumentsDirectory();
      final filename = 'original_image.jpg';
      final localPath = path.join(appDir.path, filename);

      final response = await http.get(Uri.parse(_fixedImageUrl));
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Error: Image download failed (Status: ${response.statusCode})';
          _isCompressingImage = false;
        });
        return;
      }

      // Save the downloaded image
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);

      // Store original image path
      setState(() {
        _originalImagePath = localPath;
      });

      print('Downloaded image to: $localPath');
      print('Original image size: ${file.lengthSync()} bytes');

      // Compress the image
      final String? compressedPath = await MoonNative.compressImage(
        imagePath: localPath,
        quality: _imageQuality,
        format: _imageFormat,
      );

      if (compressedPath == null) {
        setState(() {
          _errorMessage = 'Error: Image compression failed - no output generated';
          _isCompressingImage = false;
        });
        return;
      }

      // Verify the compressed file exists
      final File compressedFile = File(compressedPath);
      if (!compressedFile.existsSync()) {
        setState(() {
          _errorMessage = 'Error: Compressed image file does not exist';
          _isCompressingImage = false;
        });
        return;
      }

      // Get file sizes for comparison
      final int originalSize = file.lengthSync();
      final int compressedSize = compressedFile.lengthSync();

      // Calculate compression ratio and formatted sizes
      final double ratio = originalSize / compressedSize;
      final String originalSizeStr = '${(originalSize / 1024).toStringAsFixed(2)} KB';
      final String compressedSizeStr = '${(compressedSize / 1024).toStringAsFixed(2)} KB';

      print('Original image size: $originalSize bytes');
      print('Compressed image size: $compressedSize bytes');
      print('Compression ratio: ${(compressedSize / originalSize * 100).toStringAsFixed(2)}%');

      setState(() {
        _compressedImagePath = compressedPath;
        _compressionRatio = '${ratio.toStringAsFixed(2)}x (${originalSizeStr} → ${compressedSizeStr})';
        _compressedSize = compressedSizeStr;
        _isCompressingImage = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error compressing image: $e';
        _isCompressingImage = false;
      });
    }
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _errorMessage = '';
      _isDownloading = true;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filename = _fixedVideoUrl.split('/').last;
      final localPath = path.join(appDir.path, filename);

      final response = await http.get(Uri.parse(_fixedVideoUrl));
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Error: Download failed (Status: ${response.statusCode})';
        });
        return;
      }

      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);
      _videoPathController.text = localPath;
      await _updateVideoDuration();

      setState(() {
        _isDownloading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error downloading video: $e';
        _isDownloading = false;
      });
    }
  }

  Future<void> _updateVideoDuration() async {
    try {
      final String videoPath = _videoPathController.text;
      if (videoPath.isEmpty || !File(videoPath).existsSync()) {
        setState(() {
          _videoDuration = 'Duration unknown';
        });
        return;
      }

      await _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.file(File(videoPath));
      await _videoPlayerController!.initialize();

      final duration = _videoPlayerController!.value.duration;
      setState(() {
        _videoDuration = 'Duration: ${duration.inSeconds}.${duration.inMilliseconds % 1000} s';
      });
    } catch (e) {
      setState(() {
        _videoDuration = 'Duration unknown';
        _errorMessage = 'Error getting duration: $e';
      });
    }
  }

  Future<void> _trimVideo() async {
    setState(() {
      _errorMessage = '';
      _isTrimming = true;
    });

    try {
      final String videoPath = _videoPathController.text;
      if (videoPath.isEmpty) {
        setState(() {
          _errorMessage = 'Error: Please enter a video path';
        });
        return;
      }
      if (!File(videoPath).existsSync()) {
        setState(() {
          _errorMessage = 'Error: Video file not found';
        });
        return;
      }

      await _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.file(File(videoPath));
      await _videoPlayerController!.initialize();
      final duration = _videoPlayerController!.value.duration.inMilliseconds / 1000.0;
      final halfDuration = duration / 2;

      final String? outputPath = await MoonNative.trimVideo(videoPath, 0.0, halfDuration);
      if (outputPath == null) {
        setState(() {
          _errorMessage = 'Error: Trimming failed - no output generated';
        });
        return;
      }

      _videoPathController.text = outputPath;
      await _updateVideoDuration();

      setState(() {
        _isTrimming = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error trimming video: $e';
        _isTrimming = false;
      });
    }
  }

  void _copyErrorMessage() {
    if (_errorMessage.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _errorMessage));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error message copied to clipboard')),
      );
    }
  }

  Future<void> _rotateVideo() async {
    setState(() {
      _errorMessage = '';
      _isRotating = true;
    });

    try {
      final String videoPath = _videoPathController.text;
      if (videoPath.isEmpty) {
        setState(() {
          _errorMessage = 'Error: Please enter a video path';
        });
        return;
      }

      final File videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        setState(() {
          _errorMessage = 'Error: Video file not found';
        });
        return;
      }

      // Print original video file size for debugging
      print('Original video file size: ${videoFile.lengthSync()} bytes');

      final String? outputPath = await MoonNative.rotateVideo(videoPath, _clockwiseQuarterTurns);
      if (outputPath == null) {
        setState(() {
          _errorMessage = 'Error: Rotation failed - no output generated';
        });
        return;
      }

      // Verify the rotated file exists and has content
      final File rotatedFile = File(outputPath);
      if (!rotatedFile.existsSync()) {
        setState(() {
          _errorMessage = 'Error: Rotated video file does not exist';
        });
        return;
      }

      final int rotatedFileSize = rotatedFile.lengthSync();
      print('Rotated video file size: $rotatedFileSize bytes');

      if (rotatedFileSize <= 0) {
        setState(() {
          _errorMessage = 'Error: Rotated video file is empty';
        });
        return;
      }

      // Dispose of previous rotated video controller if exists
      await _rotatedVideoController?.dispose();

      // Create the controller with a delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize new controller with rotated video
      _rotatedVideoController = VideoPlayerController.file(rotatedFile);

      try {
        await _rotatedVideoController!.initialize();
        print('Rotated video initialized successfully');
        print('Video dimensions: ${_rotatedVideoController!.value.size}');
        print('Video duration: ${_rotatedVideoController!.value.duration}');

        // Start playback of both videos
        _videoPlayerController?.play();
        _rotatedVideoController?.play();

        setState(() {
          _rotatedVideoPath = outputPath;
          _isRotating = false;
        });
      } catch (initError) {
        print('Error initializing rotated video: $initError');
        setState(() {
          _errorMessage = 'Error initializing rotated video: $initError';
          _isRotating = false;
        });
      }
    } catch (e) {
      print('Error rotating video: $e');
      setState(() {
        _errorMessage = 'Error rotating video: $e';
        _isRotating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isDownloading ? null : _downloadVideo,
              child: _isDownloading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Downloading...')],
                    )
                  : const Text('Download Sample Video'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _videoPathController,
              decoration: const InputDecoration(labelText: 'Video Path'),
            ),
            const SizedBox(height: 10),
            Text(_videoDuration),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTrimming ? null : _trimVideo,
                    child: _isTrimming
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Trimming...')],
                          )
                        : const Text('Trim Video (Half)'),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _clockwiseQuarterTurns,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Quarter Turn')),
                    DropdownMenuItem(value: 2, child: Text('2 Quarter Turns')),
                    DropdownMenuItem(value: 3, child: Text('3 Quarter Turns')),
                  ],
                  onChanged: (value) => setState(() => _clockwiseQuarterTurns = value!),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRotating ? null : _rotateVideo,
                    child: _isRotating
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Rotating...')],
                          )
                        : const Text('Rotate Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_videoPlayerController != null)
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Original Video', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          ),
                          VideoProgressIndicator(_videoPlayerController!, allowScrubbing: true),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(_videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                onPressed: () {
                                  setState(() {
                                    _videoPlayerController!.value.isPlaying ? _videoPlayerController!.pause() : _videoPlayerController!.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_rotatedVideoController != null && _rotatedVideoPath != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Rotated Video ($_clockwiseQuarterTurns Quarter ${_clockwiseQuarterTurns == 1 ? 'Turn' : 'Turns'})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: _rotatedVideoController!.value.aspectRatio,
                                child: VideoPlayer(_rotatedVideoController!),
                              ),
                            ),
                            VideoProgressIndicator(_rotatedVideoController!, allowScrubbing: true),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(_rotatedVideoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                  onPressed: () {
                                    setState(() {
                                      _rotatedVideoController!.value.isPlaying ? _rotatedVideoController!.pause() : _rotatedVideoController!.play();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const Text('Image Compression', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCompressingImage ? null : _downloadAndCompressImage,
                    child: _isCompressingImage
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Downloading & Compressing...')],
                          )
                        : const Text('Compress from File'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCompressingImage
                        ? null
                        : () async {
                            setState(() {
                              _isCompressingImage = true;
                              _errorMessage = '';
                              _compressedImagePath = null;
                              _compressionRatio = null;
                              _compressedSize = null;
                            });

                            try {
                              // Download the image directly as bytes
                              final response = await http.get(Uri.parse(_fixedImageUrl));
                              if (response.statusCode != 200) {
                                throw Exception('Failed to download image: ${response.statusCode}');
                              }

                              print('Downloaded image bytes: ${response.bodyBytes.length} bytes');

                              // Validate that we have image bytes
                              if (response.bodyBytes.isEmpty) {
                                setState(() {
                                  _errorMessage = 'Error: Downloaded image bytes are empty';
                                  _isCompressingImage = false;
                                });
                                return;
                              }
                              
                              // Store the original bytes for display
                              final Uint8List originalBytes = response.bodyBytes;
                              
                              // Try compressing directly from bytes
                              String? compressedPath;
                              try {
                                compressedPath = await MoonNative.compressImage(
                                  imageBytes: originalBytes,
                                  quality: _imageQuality,
                                  format: _imageFormat,
                                );
                                print('Compression result (from bytes): $compressedPath');
                              } catch (e) {
                                print('Error during compression from bytes: $e');
                                setState(() {
                                  _errorMessage = 'Error: ${e.toString()}';
                                  _isCompressingImage = false;
                                });
                                return;
                              }

                              if (compressedPath == null) {
                                setState(() {
                                  _errorMessage = 'Error: Image compression from bytes failed';
                                  _isCompressingImage = false;
                                });
                                return;
                              }

                              // Get file sizes for comparison
                              final File compressedFile = File(compressedPath);
                              final int compressedSize = compressedFile.lengthSync();
                              final int originalSize = originalBytes.length;

                              // Calculate compression ratio
                              final double ratio = originalSize / compressedSize;
                              final String originalSizeStr = '${(originalSize / 1024).toStringAsFixed(2)} KB';
                              final String compressedSizeStr = '${(compressedSize / 1024).toStringAsFixed(2)} KB';

                              setState(() {
                                _originalImageBytes = originalBytes;
                                _compressedImagePath = compressedPath;
                                _compressionRatio = '${ratio.toStringAsFixed(2)}x (${originalSizeStr} → ${compressedSizeStr})';
                                _compressedSize = compressedSizeStr;
                                _isCompressingImage = false;
                              });
                            } catch (e) {
                              setState(() {
                                _errorMessage = 'Error: ${e.toString()}';
                                _isCompressingImage = false;
                              });
                            }
                          },
                    child: _isCompressingImage
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Processing...'),
                            ],
                          )
                        : const Text('Compress from Bytes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            if ((_originalImagePath != null || _originalImageBytes != null) && _compressedImagePath != null)
              SizedBox(
                height: 300,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Original Image', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Expanded(
                            child: _originalImageBytes != null
                              ? Image.memory(
                                  _originalImageBytes!,
                                  fit: BoxFit.contain,
                                )
                              : Image.file(
                                  File(_originalImagePath!),
                                  fit: BoxFit.contain,
                                ),
                          ),
                          if (_originalImagePath != null)
                            Text('Size: ${(File(_originalImagePath!).lengthSync() / 1024).toStringAsFixed(2)} KB')
                          else if (_originalImageBytes != null)
                            Text('Size: ${(_originalImageBytes!.length / 1024).toStringAsFixed(2)} KB'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Compressed Image', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_compressionRatio != null) Text('Ratio: $_compressionRatio', style: const TextStyle(fontSize: 12)),
                          if (_compressedSize != null) Text('Size: $_compressedSize', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 5),
                          Expanded(
                            child: Image.file(
                              File(_compressedImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.red),
                    onPressed: _copyErrorMessage,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
