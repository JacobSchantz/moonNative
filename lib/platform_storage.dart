import 'package:flutter/foundation.dart';

/// Abstract interface for platform-specific storage operations
abstract class PlatformStorage {
  /// Gets a path where we can store a video file
  Future<String> getVideoStoragePath(String filename);
  
  /// Saves data to a local file and returns the path
  Future<String> saveVideoData(List<int> data, String filename);
  
  /// Checks if a file exists at the given path
  bool fileExists(String path);
  
  /// Creates a controller for the video at the given path
  dynamic createVideoPlayerController(String videoPath);
  
  /// Factory constructor to get the right implementation
  factory PlatformStorage() {
    if (kIsWeb) {
      return WebPlatformStorage();
    } else {
      return IOPlatformStorage();
    }
  }
}

/// Web implementation
class WebPlatformStorage implements PlatformStorage {
  @override
  Future<String> getVideoStoragePath(String filename) async {
    // On web, we just return the filename as we'll use URLs
    return filename;
  }
  
  @override
  Future<String> saveVideoData(List<int> data, String filename) async {
    // On web, we can't save files locally in the same way
    // We'd typically use blob URLs, but for simplicity in this example
    // we'll just return the original filename
    return filename;
  }
  
  @override
  bool fileExists(String path) {
    // For web, if it's a URL, we'll assume it exists
    return path.startsWith('http');
  }
  
  @override
  dynamic createVideoPlayerController(String videoPath) {
    // Import here to avoid conflicts
    // ignore: undefined_function
    return _createNetworkController(Uri.parse(videoPath));
  }
  
  // This will be implemented by the actual import in the main file
  dynamic _createNetworkController(Uri uri) {
    throw UnimplementedError('This should be implemented by the consumer');
  }
}

/// IO implementation for mobile/desktop
class IOPlatformStorage implements PlatformStorage {
  @override
  Future<String> getVideoStoragePath(String filename) async {
    // Import here to avoid conflicts with web
    // ignore: undefined_function
    final appDir = await _getAppDirectory();
    // ignore: undefined_function
    return _joinPaths(appDir.path, filename);
  }
  
  @override
  Future<String> saveVideoData(List<int> data, String filename) async {
    final path = await getVideoStoragePath(filename);
    // ignore: undefined_function
    await _saveFile(path, data);
    return path;
  }
  
  @override
  bool fileExists(String path) {
    // ignore: undefined_function
    return _fileExists(path);
  }
  
  @override
  dynamic createVideoPlayerController(String videoPath) {
    // ignore: undefined_function
    return _createFileController(videoPath);
  }
  
  // These will be implemented by the actual imports in the main file
  dynamic _getAppDirectory() {
    throw UnimplementedError('This should be implemented by the consumer');
  }
  
  String _joinPaths(String a, String b) {
    throw UnimplementedError('This should be implemented by the consumer');
  }
  
  Future<void> _saveFile(String path, List<int> data) {
    throw UnimplementedError('This should be implemented by the consumer');
  }
  
  bool _fileExists(String path) {
    throw UnimplementedError('This should be implemented by the consumer');
  }
  
  dynamic _createFileController(String path) {
    throw UnimplementedError('This should be implemented by the consumer');
  }
}
