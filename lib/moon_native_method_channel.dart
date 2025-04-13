import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'moon_native_platform_interface.dart';

/// An implementation of [MoonNativePlatform] that uses method channels.
class MethodChannelMoonNative extends MoonNativePlatform {
  // Map to track active compression tasks by ID
  final Map<String, StreamController<VideoCompressionUpdate>> _compressionControllers = {};
  
  // EventChannel for receiving native compression progress updates
  static const EventChannel _compressionEventChannel = EventChannel('moon_native/compression_events');
  
  // Stream of all compression events from native code
  late final Stream<dynamic> _compressionEvents;
  
  // The broadcast stream controller for all compression updates
  final StreamController<VideoCompressionUpdate> _updatesController = 
      StreamController<VideoCompressionUpdate>.broadcast();
  
  // Flag to track if event listener is initialized
  bool _eventListenerInitialized = false;
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('moon_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'startTime': startTime,
      'endTime': endTime,
    };
    return await methodChannel.invokeMethod<String>('trimVideo', args);
  }

  @override
  Future<String?> rotateVideo(String videoPath, int clockwiseQuarterTurns) async {
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'quarterTurns': clockwiseQuarterTurns, // Keep parameter name as 'quarterTurns' for native interface compatibility
    };
    return await methodChannel.invokeMethod<String>('rotateVideo', args);
  }

  @override
  Future<bool> playBeep({int frequency = 1000, int durationMs = 200, double volume = 1.0, int? soundId}) async {
    final Map<String, dynamic> args = {
      'frequency': frequency,
      'durationMs': durationMs,
      'volume': volume,
    };
    
    // Add soundId to args if provided (for iOS)
    if (soundId != null) {
      args['soundId'] = soundId;
    }
    
    return await methodChannel.invokeMethod<bool>('playBeep', args) ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getNavigationMode() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>('getNavigationMode');
      if (result == null) return null;

      // Convert from Map<Object?, Object?> to Map<String, dynamic>
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting navigation mode: $e');
      return null;
    }
  }
  
  @override
  Future<Map<String, dynamic>?> getRingerMode() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>('getRingerMode');
      if (result == null) return null;

      // Convert from Map<Object?, Object?> to Map<String, dynamic>
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting ringer mode: $e');
      return null;
    }
  }

  @override
  Future<String?> compressImageFromPath({
    required String imagePath,
    required int quality,
    String? format,
  }) async {
    final Map<String, dynamic> args = {
      'imagePath': imagePath,
      'quality': quality,
      'format': format,
    };

    return await methodChannel.invokeMethod<String>('compressImage', args);
  }

  @override
  Future<Uint8List?> compressImageFromBytes({
    required Uint8List imageBytes,
    required int quality,
    String? format,
  }) async {
    // Validate that the bytes are not empty
    if (imageBytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    final Map<String, dynamic> args = {
      'imageBytes': imageBytes,
      'quality': quality,
      'format': format,
    };

    return await methodChannel.invokeMethod<Uint8List>('compressImageFromBytes', args);
  }
  
  @override
  Future<bool> enqueueVideoCompression({
    required String videoPath,
    required int quality,
    String? resolution,
    int? bitrate,
    String? customId,
  }) async {
    // Initialize event listener on first use
    _initializeEventListenerIfNeeded();
    
    // Use custom ID if provided, otherwise generate a unique ID
    final compressionId = customId ?? _generateUniqueId();
    
    // Prepare method arguments
    final Map<String, dynamic> args = {
      'videoPath': videoPath,
      'quality': quality,
      if (resolution != null) 'resolution': resolution,
      if (bitrate != null) 'bitrate': bitrate,
      if (customId != null) 'customId': customId,
    };
    
    // Store the ID that will be used for tracking (either custom or generated)
    args['compressionId'] = compressionId;
    
    // Create initial update
    final initialUpdate = VideoCompressionUpdate(
      status: VideoCompressionStatus.processing,
      progress: 0.0,
      compressionId: compressionId,
    );
    
    // Send initial update to the global stream
    _updatesController.add(initialUpdate);
    
    try {
      // Enqueue compression in background
      final success = await methodChannel.invokeMethod<bool>('enqueueVideoCompression', args) ?? false;
      
      if (!success) {
        // Failed to enqueue
        final errorUpdate = VideoCompressionUpdate(
          status: VideoCompressionStatus.error,
          progress: 0.0,
          compressionId: compressionId,
          error: 'Failed to enqueue video compression',
        );
        _updatesController.add(errorUpdate);
        return false;
      }
      
      // On web, we need different approach than on native platforms
      if (kIsWeb) {
        _setupWebProgressUpdates(compressionId);
      }
      
      return true; // Successfully enqueued
    } catch (e) {
      debugPrint('Failed to enqueue video compression: $e');
      return false; // Failed to enqueue
    }
  }
  
  @override
  Stream<VideoCompressionUpdate> get videoCompressionUpdates {
    _initializeEventListenerIfNeeded();
    return _updatesController.stream;
  }
  
  @override
  Future<bool> cancelVideoCompression(String compressionId) async {
    // First check if this task exists in our controllers map
    final controller = _compressionControllers[compressionId];
    if (controller == null) {
      return false; // Task not found
    }

    // Attempt to cancel on native side
    bool? success = false;
    try {
      success = await methodChannel.invokeMethod<bool>(
        'cancelVideoCompression',
        {'compressionId': compressionId}
      );
    } catch (e) {
      debugPrint('Error cancelling compression: $e');
    }
    
    // If successfully cancelled or if we got an error, notify subscribers
    final update = VideoCompressionUpdate(
      status: VideoCompressionStatus.cancelled,
      progress: 0.0,
      compressionId: compressionId,
    );
    controller.add(update);
    
    // Clean up resources
    Future.delayed(const Duration(seconds: 1), () {
      if (!controller.isClosed) {
        controller.close();
        _compressionControllers.remove(compressionId);
      }
    });
    
    return success ?? false;
  }
  
  /// Initialize the event listener for compression progress updates
  void _initializeEventListenerIfNeeded() {
    if (_eventListenerInitialized) {
      debugPrint('Event listener already initialized, skipping initialization');
      return;
    }
    
    try {
      debugPrint('Initializing compression event listener');
      // Listen to compression events from native code
      _compressionEvents = _compressionEventChannel.receiveBroadcastStream();
      
      _compressionEvents.listen(
        (dynamic event) {
          debugPrint('Received event from native channel: $event');
          if (event is Map) {
            // Extract data from event
            final String? compressionId = event['compressionId'] as String?;
            final String? status = event['status'] as String?;
            final dynamic rawProgress = event['progress'];
            
            // Handle progress which could be double or int
            double? progress;
            if (rawProgress is double) {
              progress = rawProgress;
            } else if (rawProgress is int) {
              progress = rawProgress.toDouble();
            }
            
            debugPrint('Parsed event - ID: $compressionId, Status: $status, Progress: $progress');
            
            if (compressionId != null && status != null && progress != null) {
              // Map status string to enum
              VideoCompressionStatus compressionStatus;
              switch (status) {
                case 'processing':
                  compressionStatus = VideoCompressionStatus.processing;
                  break;
                case 'completed':
                  compressionStatus = VideoCompressionStatus.completed;
                  break;
                case 'error':
                  compressionStatus = VideoCompressionStatus.error;
                  break;
                case 'cancelled':
                  compressionStatus = VideoCompressionStatus.cancelled;
                  break;
                default:
                  debugPrint('Unknown status: $status, defaulting to processing');
                  compressionStatus = VideoCompressionStatus.processing;
              }
              
              // Create and emit update
              final update = VideoCompressionUpdate(
                status: compressionStatus,
                progress: progress,
                compressionId: compressionId,
                outputPath: event['outputPath'] as String?,
                error: event['error'] as String?,
              );
              
              // Send to the global updates stream
              debugPrint('Sending update to stream: $update');
              _updatesController.add(update);
            } else {
              debugPrint('Missing required fields in event: $event');
            }
          } else {
            debugPrint('Received non-map event: $event');
          }
        },
        onError: (dynamic error) {
          debugPrint('Error from compression event channel: $error');
        },
        onDone: () {
          debugPrint('Compression event channel stream closed');
        },
      );
      
      debugPrint('Event listener successfully initialized');
      _eventListenerInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize compression event listener: $e');
      // Fall back to mock progress if we can't get real events
      _eventListenerInitialized = true; // Prevent repeated attempts
    }
  }
  
  /// Generate a unique ID for a compression task
  String _generateUniqueId() {
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(10000).toString().padLeft(4, '0');
    return 'compression_${timestamp}_$randomPart';
  }
  
  /// For web platforms, simulate progress updates
  void _setupWebProgressUpdates(String compressionId) {
    if (!kIsWeb) return; // Only needed for web
    
    // In a real implementation, this would interact with JavaScript
    // Based on the memory of the web implementation using HTML5 APIs
    // For now, we'll simulate progress
    
    double progress = 0.0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_updatesController.isClosed) {
        timer.cancel();
        return;
      }
      
      // Simulate non-linear progress that slows down as it approaches completion
      progress += (0.1 * (1.0 - progress/0.9));
      
      if (progress >= 0.99) {
        // We'll let the completion callback handle the final update
        timer.cancel();
        return;
      }
      
      final update = VideoCompressionUpdate(
        status: VideoCompressionStatus.processing,
        progress: progress,
        compressionId: compressionId,
      );
      
      _updatesController.add(update);
    });
  }
}
