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
  String _videoDuration = 'Duration unknown';
  String _errorMessage = '';
  final String _fixedVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';

  @override
  void dispose() {
    _videoPathController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _errorMessage = '';
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Error downloading video: $e';
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Error trimming video: $e';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _downloadVideo,
            child: const Text('Download Sample Video'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _videoPathController,
            decoration: const InputDecoration(labelText: 'Video Path'),
          ),
          const SizedBox(height: 10),
          Text(_videoDuration),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _trimVideo,
            child: const Text('Trim Video (Half)'),
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
