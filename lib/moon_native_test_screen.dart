import 'package:flutter/material.dart';
import 'package:moon_native/widgets/image_compression_widget.dart';
import 'package:moon_native/widgets/video_processing_widget.dart';

/// Main test screen for the Moon Native plugin.
/// This screen demonstrates the image compression and video processing capabilities.
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

/// Stateful widget that contains the test components
class MoonNativeTestWidget extends StatefulWidget {
  const MoonNativeTestWidget({super.key});

  @override
  State<MoonNativeTestWidget> createState() => _MoonNativeTestWidgetState();
}

class _MoonNativeTestWidgetState extends State<MoonNativeTestWidget> {
  // Sample URLs for testing
  final String _fixedVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';
  final String _fixedImageUrl = 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=2070&auto=format&fit=crop';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Compression Section
            const Text(
              'Image Compression',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Image Compression Widget
            ImageCompressionWidget(defaultImageUrl: _fixedImageUrl),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Video Processing Section
            const Text(
              'Video Processing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Video Processing Widget
            VideoProcessingWidget(defaultVideoUrl: _fixedVideoUrl),
          ],
        ),
      ),
    );
  }
}
