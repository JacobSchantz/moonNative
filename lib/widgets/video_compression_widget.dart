import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:moon_native/moon_native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Widget for demonstrating video compression
class VideoCompressionWidget extends StatefulWidget {
  final String? defaultVideoUrl;

  const VideoCompressionWidget({Key? key, this.defaultVideoUrl}) : super(key: key);

  @override
  State<VideoCompressionWidget> createState() => _VideoCompressionWidgetState();
}

class _VideoCompressionWidgetState extends State<VideoCompressionWidget> {
  File? _sourceVideo;
  File? _compressedVideo;
  bool _isCompressing = false;
  bool _isDownloading = false;
  double _compressionProgress = 0.0;
  String? _compressionId;
  String? _errorMessage;
  StreamSubscription? _compressionSubscription;

  VideoPlayerController? _sourceController;
  VideoPlayerController? _compressedController;

  // Compression settings
  int _quality = 70; // Default quality
  String _resolution = '720p'; // Default resolution

  @override
  void initState() {
    super.initState();
    // Set up the global listener for compression updates
    debugPrint('VideoCompressionWidget: initializing');
    if (widget.defaultVideoUrl != null) {
      _downloadDefaultVideo();
    }
  }

  @override
  void dispose() {
    _sourceController?.dispose();
    _compressedController?.dispose();
    _compressionSubscription?.cancel();
    super.dispose();
  }

  /// Download the default video
  Future<void> _downloadDefaultVideo() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.defaultVideoUrl!));

      if (response.statusCode == 200) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final videoFile = File('${documentsDir.path}/sample_video.mp4');

        await videoFile.writeAsBytes(response.bodyBytes);

        setState(() {
          _sourceVideo = videoFile;
          _isDownloading = false;
          _initializeSourcePlayer();
        });
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to download video: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Error downloading video: $e';
      });
      debugPrint('Error downloading default video: $e');
    }
  }

  /// Initialize the source video player
  Future<void> _initializeSourcePlayer() async {
    if (_sourceVideo != null) {
      _sourceController = VideoPlayerController.file(_sourceVideo!);
      await _sourceController!.initialize();

      // Don't autoplay, just prepare the controller
      setState(() {});
    }
  }

  /// Initialize the compressed video player
  Future<void> _initializeCompressedPlayer() async {
    if (_compressedVideo != null) {
      _compressedController = VideoPlayerController.file(_compressedVideo!);
      await _compressedController!.initialize();

      // Don't autoplay, just prepare the controller
      setState(() {});
    }
  }

  /// Compress the selected video
  Future<void> _compressVideo() async {
    if (_sourceVideo == null || _isCompressing) return;

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
      _errorMessage = null;
      _compressedVideo = null;
      _compressedController?.dispose();
      _compressedController = null;
      _compressionId = null; // Reset compression ID
    });

    try {
      debugPrint('Setting up compression subscription');
      // Cancel any existing subscription to avoid memory leaks
      _compressionSubscription?.cancel();
      
      // Set up the stream subscription BEFORE enqueuing the task
      _compressionSubscription = MoonNative.videoCompressionUpdates.listen(
        (update) {
          debugPrint('Received compression update: ${update.status}, progress: ${update.progress}, ID: ${update.compressionId}');
          
          // Store the compression ID when we first get it
          if (_compressionId == null && update.compressionId.isNotEmpty) {
            debugPrint('Setting compression ID to: ${update.compressionId}');
            setState(() {
              _compressionId = update.compressionId;
            });
          }
          
          // Process all updates when we don't have an ID yet, or updates that match our ID
          if (_compressionId == null || _compressionId == update.compressionId) {
            setState(() {
              // Always update progress
              _compressionProgress = update.progress;
              debugPrint('Updated progress: $_compressionProgress');
              
              // Handle different update statuses
              switch (update.status) {
                case VideoCompressionStatus.processing:
                  // Just update progress
                  break;
                  
                case VideoCompressionStatus.completed:
                  _isCompressing = false;
                  if (update.outputPath != null) {
                    debugPrint('Compression completed with output path: ${update.outputPath}');
                    _compressedVideo = File(update.outputPath!);
                    _initializeCompressedPlayer();
                  }
                  break;
                  
                case VideoCompressionStatus.error:
                  _isCompressing = false;
                  _errorMessage = update.error ?? 'Unknown compression error';
                  debugPrint('Compression error: $_errorMessage');
                  break;
                  
                case VideoCompressionStatus.cancelled:
                  _isCompressing = false;
                  _errorMessage = 'Compression was cancelled';
                  debugPrint('Compression cancelled');
                  break;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Error in compression stream: $error');
          setState(() {
            _isCompressing = false;
            _errorMessage = 'Error in compression stream: $error';
          });
        },
      );

      debugPrint('Enqueueing compression task for ${_sourceVideo!.path}');
      // Enqueue the compression task directly with MoonNative
      final success = await MoonNative.enqueueVideoCompression(
        videoPath: _sourceVideo!.path,
        quality: _quality,
        resolution: _resolution,
      );

      debugPrint('Compression enqueued: $success');
      if (!success) {
        // If enqueuing failed, clean up
        _compressionSubscription?.cancel();
        setState(() {
          _isCompressing = false;
          _errorMessage = 'Failed to start compression task';
        });
      } else {
        // Wait for real progress updates from the native side
        debugPrint('Compression task started, waiting for native progress updates');
      }
    } catch (e) {
      debugPrint('Exception during compression setup: $e');
      setState(() {
        _isCompressing = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  /// Cancel the current compression
  Future<void> _cancelCompression() async {
    if (_compressionId != null && _isCompressing) {
      debugPrint('Cancelling compression with ID: $_compressionId');
      final cancelled = await MoonNative.cancelVideoCompression(_compressionId!);
      
      debugPrint('Compression cancelled: $cancelled');
      if (!cancelled) {
        setState(() {
          _errorMessage = 'Failed to cancel compression';
        });
      } else {
        setState(() {
          _isCompressing = false;
          _compressionProgress = 0.0;
          _errorMessage = 'Compression cancelled';
        });
      }
    }
  }
  
  // Note: Removed progress simulation code as requested
  // Now relying solely on native progress updates

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background Video Compression',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Video status
            if (_sourceVideo == null && !_isDownloading)
              ElevatedButton.icon(
                onPressed: _downloadDefaultVideo,
                icon: const Icon(Icons.download),
                label: const Text('Download Sample Video'),
              )
            else if (_isDownloading)
              const Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Downloading sample video...'),
                ],
              )
            else
              Text('Sample video ready: ${path.basename(_sourceVideo!.path)}'),
            const SizedBox(height: 16),

            // Quality slider
            Row(
              children: [
                const Text('Quality: '),
                Expanded(
                  child: Slider(
                    value: _quality.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '$_quality',
                    onChanged: _isCompressing
                        ? null
                        : (value) {
                            setState(() {
                              _quality = value.round();
                            });
                          },
                  ),
                ),
                Text('$_quality%'),
              ],
            ),

            // Resolution selector
            Row(
              children: [
                const Text('Resolution: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _resolution,
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _resolution = value;
                            });
                          }
                        },
                  items: ['1080p', '720p', '480p', '360p'].map((resolution) {
                    return DropdownMenuItem<String>(
                      value: resolution,
                      child: Text(resolution),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Source video preview
            if (_sourceController != null && _sourceController!.value.isInitialized)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source Video:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: _sourceController!.value.aspectRatio,
                    child: VideoPlayer(_sourceController!),
                  ),
                  VideoProgressIndicator(_sourceController!, allowScrubbing: true),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _sourceController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            _sourceController!.value.isPlaying ? _sourceController!.pause() : _sourceController!.play();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              )
            else if (_sourceVideo != null)
              const Center(child: CircularProgressIndicator()),

            const SizedBox(height: 16),

            // Compression control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _sourceVideo != null && !_isCompressing ? _compressVideo : null,
                  icon: const Icon(Icons.compress),
                  label: const Text('Compress Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isCompressing ? _cancelCompression : null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Compression progress
            if (_isCompressing)
              Column(
                children: [
                  LinearProgressIndicator(value: _compressionProgress),
                  const SizedBox(height: 8),
                  Text('Compressing: ${(_compressionProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 16),

            // Compressed video preview
            if (_compressedController != null && _compressedController!.value.isInitialized)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compressed Video:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: _compressedController!.value.aspectRatio,
                    child: VideoPlayer(_compressedController!),
                  ),
                  VideoProgressIndicator(_compressedController!, allowScrubbing: true),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _compressedController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            _compressedController!.value.isPlaying ? _compressedController!.pause() : _compressedController!.play();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_sourceVideo != null && _compressedVideo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Original: ${(File(_sourceVideo!.path).lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB\n'
                        'Compressed: ${(File(_compressedVideo!.path).lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
