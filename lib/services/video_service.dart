import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoService {
  Future<String> downloadVideo(String videoUrl) async {
    final response = await http.get(Uri.parse(videoUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download video: ${response.statusCode}');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'downloaded_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = path.join(tempDir.path, fileName);

    await File(filePath).writeAsBytes(response.bodyBytes);
    return filePath;
  }
}
