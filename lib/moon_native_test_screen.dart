import 'package:flutter/material.dart';
import 'package:moon_native/moon_native.dart';
import 'package:moon_native/widgets/image_compression_widget.dart';
import 'package:moon_native/widgets/video_processing_widget.dart';
import 'package:moon_native/widgets/video_compression_widget.dart';

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

  // Navigation mode information
  String _navigationModeInfo = 'Press the button to detect navigation mode';
  bool _isNavigationLoading = false;

  // Ringer mode information
  String _ringerModeInfo = 'Press the button to detect ringer mode';
  bool _isRingerLoading = false;

  // Beep sound testing information
  String _beepSoundInfo = 'Press the button to test beep sounds';
  bool _isBeepTesting = false;

  @override
  void dispose() {
    super.dispose();
  }

  // Get navigation mode information
  Future<void> _getNavigationMode() async {
    setState(() {
      _isNavigationLoading = true;
      _navigationModeInfo = 'Detecting navigation mode...';
    });

    try {
      final navigationMode = await MoonNative.getNavigationMode();

      if (navigationMode != null) {
        String modeDescription;
        bool isGestureNavigation;

        switch (navigationMode) {
          case MoonNavigationMode.threeButton:
            modeDescription = '3-button navigation (back, home, recents)';
            isGestureNavigation = false;
            break;
          case MoonNavigationMode.twoButton:
            modeDescription = '2-button navigation (back gesture, home pill)';
            isGestureNavigation = true;
            break;
          case MoonNavigationMode.fullGesture:
            modeDescription = 'Full gesture navigation';
            isGestureNavigation = true;
            break;
        }

        setState(() {
          _navigationModeInfo = 'Navigation Type: ${isGestureNavigation ? 'Gesture' : 'Button'}\n'
              'Navigation Mode: $modeDescription';
        });
      } else {
        setState(() {
          _navigationModeInfo = 'Could not detect navigation mode.\n'
              'This feature is only available on Android 10+';
        });
      }
    } catch (e) {
      setState(() {
        _navigationModeInfo = 'Error detecting navigation mode: $e';
      });
    } finally {
      setState(() {
        _isNavigationLoading = false;
      });
    }
  }

  // Get ringer mode information
  Future<void> _getRingerMode() async {
    setState(() {
      _isRingerLoading = true;
      _ringerModeInfo = 'Detecting ringer mode...';
    });

    try {
      final ringerInfo = await MoonNative.getRingerMode();

      if (ringerInfo != null) {
        final mode = ringerInfo['mode'] as MoonRingerMode;
        final hasSound = ringerInfo['hasSound'] as bool;
        final hasVibration = ringerInfo['hasVibration'] as bool;

        String modeDescription;
        switch (mode) {
          case MoonRingerMode.silent:
            modeDescription = 'Silent mode';
            break;
          case MoonRingerMode.vibrate:
            modeDescription = 'Vibrate mode';
            break;
          case MoonRingerMode.normal:
            modeDescription = 'Normal mode';
            break;
        }

        setState(() {
          _ringerModeInfo = 'Ringer Mode: $modeDescription\n'
              'Has Sound: ${hasSound ? 'Yes' : 'No'}\n'
              'Has Vibration: ${hasVibration ? 'Yes' : 'No'}';
        });
      } else {
        setState(() {
          _ringerModeInfo = 'Could not detect ringer mode.\n'
              'There was an error retrieving the device ringer mode.';
        });
      }
    } catch (e) {
      setState(() {
        _ringerModeInfo = 'Error detecting ringer mode: $e';
      });
    } finally {
      setState(() {
        _isRingerLoading = false;
      });
    }
  }

  // Play multiple beep sounds
  Future<void> _testBeepSounds() async {
    setState(() {
      _isBeepTesting = true;
      _beepSoundInfo = 'Testing beep sounds...';
    });

    try {
      // Play different beep sounds using real iOS system sound IDs
      await MoonNative.playBeep(soundId: 1016, frequency: 500, durationMs: 200); // Standard Trinity tone
      await Future.delayed(const Duration(milliseconds: 300));

      await MoonNative.playBeep(soundId: 1007, frequency: 1000, durationMs: 200); // Standard SMS tone
      await Future.delayed(const Duration(milliseconds: 300));

      await MoonNative.playBeep(soundId: 1004, frequency: 1500, durationMs: 200); // Standard New Mail tone
      await Future.delayed(const Duration(milliseconds: 300));

      await MoonNative.playBeep(soundId: 1103, frequency: 2000, durationMs: 500); // Standard Calendar Alert

      setState(() {
        _beepSoundInfo = 'Played iOS system sounds:\n'
            '- ID: 1016 - Trinity tone\n'
            '- ID: 1007 - SMS Alert\n'
            '- ID: 1004 - New Mail\n'
            '- ID: 1103 - Calendar Alert';
      });
    } catch (e) {
      setState(() {
        _beepSoundInfo = 'Error playing beep sounds: $e';
      });
    } finally {
      setState(() {
        _isBeepTesting = false;
      });
    }
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

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Video Compression Section
            const Text(
              'Video Compression',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Video Compression Widget
            VideoCompressionWidget(defaultVideoUrl: _fixedVideoUrl),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Navigation Mode Section
            const Text(
              'Navigation Mode Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Navigation Mode Widget
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detect if device uses gesture navigation or back button',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _navigationModeInfo,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isNavigationLoading ? null : _getNavigationMode,
                        child: _isNavigationLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Detect Navigation Mode'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Ringer Mode Section
            const Text(
              'Ringer Mode Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Ringer Mode Widget
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detect device ringer mode (silent, vibrate, or normal)',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _ringerModeInfo,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isRingerLoading ? null : _getRingerMode,
                        child: _isRingerLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Detect Ringer Mode'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Beep Sound Testing Section
            const Text(
              'Beep Sound Testing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Beep Sound Testing Widget
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test multiple beep sounds with different frequencies',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _beepSoundInfo,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isBeepTesting ? null : _testBeepSounds,
                        child: _isBeepTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Beep Sounds'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
