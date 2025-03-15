import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:moon_native/services/video_service.dart';

class VideoProcessingWidget extends StatefulWidget {
  final String defaultVideoUrl;
  
  const VideoProcessingWidget({
    Key? key, 
    required this.defaultVideoUrl,
  }) : super(key: key);

  @override
  State<VideoProcessingWidget> createState() => _VideoProcessingWidgetState();
}

class _VideoProcessingWidgetState extends State<VideoProcessingWidget> {
  final VideoService _videoService = VideoService();
  
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _processedVideoController;
  
  String? _videoPath;
  String _videoDuration = 'Duration unknown';
  String? _errorMessage;
  
  bool _isDownloading = false;
  bool _isProcessing = false;
  bool _isTrimming = false;
  int _clockwiseQuarterTurns = 1;
  
  // Trim settings
  double _startTime = 0;
  double _endTime = 10;
  
  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _processedVideoController?.dispose();
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
              'Video Processing Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Download button
            ElevatedButton(
              onPressed: _isDownloading ? null : _downloadVideo,
              child: _isDownloading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Downloading...'),
                      ],
                    )
                  : const Text('Download Sample Video'),
            ),
            
            const SizedBox(height: 16),
            
            // Video duration
            if (_videoPath != null)
              Text('Video Duration: $_videoDuration'),
            
            const SizedBox(height: 8),
            
            // Original video player
            if (_videoPlayerController != null)
              SizedBox(
                height: 200,
                child: AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            
            if (_videoPlayerController != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _videoPlayerController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
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
            
            const SizedBox(height: 16),
            
            // Video processing controls
            if (_videoPath != null) ...[
              // Trim controls
              Row(
                children: [
                  const Text('Trim Video:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isTrimming ? null : _trimVideo,
                      child: _isTrimming
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Trimming...'),
                              ],
                            )
                          : const Text('Trim'),
                    ),
                  ),
                ],
              ),
              
              // Trim range
              Row(
                children: [
                  const Text('Start:'),
                  Expanded(
                    child: Slider(
                      value: _startTime,
                      min: 0,
                      max: _endTime,
                      divisions: 100,
                      label: _startTime.toStringAsFixed(1),
                      onChanged: (value) => setState(() => _startTime = value),
                    ),
                  ),
                  Text('${_startTime.toStringAsFixed(1)}s'),
                ],
              ),
              
              Row(
                children: [
                  const Text('End:'),
                  Expanded(
                    child: Slider(
                      value: _endTime,
                      min: _startTime + 1,
                      max: 60,
                      divisions: 100,
                      label: _endTime.toStringAsFixed(1),
                      onChanged: (value) => setState(() => _endTime = value),
                    ),
                  ),
                  Text('${_endTime.toStringAsFixed(1)}s'),
                ],
              ),
              
              // Rotation controls
              Row(
                children: [
                  const Text('Rotate Video:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _rotateVideo,
                      child: _isProcessing
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Rotating...'),
                              ],
                            )
                          : const Text('Rotate'),
                    ),
                  ),
                ],
              ),
              
              // Rotation angle
              Row(
                children: [
                  const Text('Angle:'),
                  Expanded(
                    child: DropdownButton<int>(
                      value: _clockwiseQuarterTurns,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('90° Clockwise')),
                        DropdownMenuItem(value: 2, child: Text('180°')),
                        DropdownMenuItem(value: 3, child: Text('270° Clockwise')),
                        DropdownMenuItem(value: -1, child: Text('90° Counter-Clockwise')),
                      ],
                      onChanged: (value) => setState(() => _clockwiseQuarterTurns = value!),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Processed video player
            if (_processedVideoController != null) ...[
              const Divider(),
              const Text(
                'Processed Video:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: AspectRatio(
                  aspectRatio: _processedVideoController!.value.aspectRatio,
                  child: VideoPlayer(_processedVideoController!),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _processedVideoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        _processedVideoController!.value.isPlaying
                            ? _processedVideoController!.pause()
                            : _processedVideoController!.play();
                      });
                    },
                  ),
                ],
              ),
            ],
            
            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final videoPath = await _videoService.downloadVideo(widget.defaultVideoUrl);
      
      // Initialize video player
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      
      // Get video duration
      final duration = controller.value.duration;
      
      setState(() {
        _videoPath = videoPath;
        _videoPlayerController = controller;
        _videoDuration = '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        _endTime = duration.inSeconds.toDouble().clamp(0, 60);
        _isDownloading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isDownloading = false;
      });
    }
  }

  Future<void> _trimVideo() async {
    if (_videoPath == null) return;
    
    setState(() {
      _isTrimming = true;
      _errorMessage = null;
    });

    try {
      final trimmedPath = await _videoService.trimVideo(
        _videoPath!,
        _startTime,
        _endTime,
      );
      
      // Initialize video player for trimmed video
      final controller = VideoPlayerController.file(File(trimmedPath));
      await controller.initialize();
      
      // Dispose previous processed video controller if exists
      await _processedVideoController?.dispose();
      
      setState(() {
        _processedVideoController = controller;
        _isTrimming = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isTrimming = false;
      });
    }
  }

  Future<void> _rotateVideo() async {
    if (_videoPath == null) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final rotatedPath = await _videoService.rotateVideo(
        _videoPath!,
        _clockwiseQuarterTurns,
      );
      
      // Initialize video player for rotated video
      final controller = VideoPlayerController.file(File(rotatedPath));
      await controller.initialize();
      
      // Dispose previous processed video controller if exists
      await _processedVideoController?.dispose();
      
      setState(() {
        _processedVideoController = controller;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
}
