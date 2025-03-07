import 'package:flutter/material.dart';
import 'package:moon_native/moon_native.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
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
        appBar: AppBar(title: const Text('Video Utility')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MoonNativeTestWidget(),
            ],
          ),
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
  final _moonNativePlugin = MoonNative();
  final TextEditingController _videoPathController = TextEditingController();
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _rotatedVideoController;
  String _videoDuration = 'Duration unknown';
  String _errorMessage = '';
  bool _isDownloading = false;
  bool _isTrimming = false;
  bool _isRotating = false;
  String? _rotatedVideoPath;
  int _selectedQuarterTurns = 1; // Default to 90 degrees clockwise
  final String _fixedVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';

  @override
  void dispose() {
    _videoPathController.dispose();
    _videoPlayerController?.dispose();
    _rotatedVideoController?.dispose();
    super.dispose();
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

      final String? outputPath = await _moonNativePlugin.trimVideo(videoPath, 0.0, halfDuration);
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

      final String? outputPath = await _moonNativePlugin.rotateVideo(videoPath, _selectedQuarterTurns);
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
                value: _selectedQuarterTurns,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('90° CW')),
                  DropdownMenuItem(value: 2, child: Text('180°')),
                  DropdownMenuItem(value: 3, child: Text('270° CW')),
                  DropdownMenuItem(value: -1, child: Text('90° CCW')),
                ],
                onChanged: (value) => setState(() => _selectedQuarterTurns = value!),
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
                                  _videoPlayerController!.value.isPlaying
                                      ? _videoPlayerController!.pause()
                                      : _videoPlayerController!.play();
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
                          Text('Rotated Video (${_selectedQuarterTurns * 90}°)', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                    _rotatedVideoController!.value.isPlaying
                                        ? _rotatedVideoController!.pause()
                                        : _rotatedVideoController!.play();
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
    );
  }
}
