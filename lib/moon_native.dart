import 'moon_native_platform_interface.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
// import 'package:moon_native/moon_native.dart';

class MoonNative {
  Future<String?> getPlatformVersion() {
    return MoonNativePlatform.instance.getPlatformVersion();
  }

  /// Performs a calculation on the native side
  ///
  /// Each platform implements this differently to demonstrate
  /// native code integration.
  ///
  /// Parameters:
  ///   a - First operand
  ///   b - Second operand
  ///
  /// Returns the result of the platform-specific calculation.
  Future<double> performNativeCalculation(double a, double b) {
    return MoonNativePlatform.instance.performNativeCalculation(a, b);
  }

  /// Trims a video to the specified duration
  ///
  /// Parameters:
  /// - videoPath: Path to the input video file
  /// - startTime: Start time in seconds
  /// - endTime: End time in seconds
  ///
  /// Returns the path to the trimmed video file or null if trimming failed
  Future<String?> trimVideo(String videoPath, double startTime, double endTime) {
    return MoonNativePlatform.instance.trimVideo(videoPath, startTime, endTime);
  }
}

class MoonNativeTestScreen extends StatefulWidget {
  const MoonNativeTestScreen({super.key});

  @override
  State<MoonNativeTestScreen> createState() => _MoonNativeTestScreenState();
}

class _MoonNativeTestScreenState extends State<MoonNativeTestScreen> {
  String _platformVersion = 'Unknown';
  String _calculationResult = 'Not calculated yet';
  String _videoTrimResult = 'No video trimmed yet';
  final _moonNativePlugin = MoonNative();

  // Values for the calculation
  final TextEditingController _valueAController = TextEditingController(text: '5');
  final TextEditingController _valueBController = TextEditingController(text: '2');

  // Values for video trimming
  final TextEditingController _videoPathController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController(text: '0.0');
  final TextEditingController _endTimeController = TextEditingController(text: '5.0');

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _valueAController.dispose();
    _valueBController.dispose();
    _videoPathController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _moonNativePlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _trimVideo() async {
    try {
      final String videoPath = _videoPathController.text;
      if (videoPath.isEmpty) {
        setState(() {
          _videoTrimResult = 'Error: Please enter a valid video path';
        });
        return;
      }

      final double startTime = double.parse(_startTimeController.text);
      final double endTime = double.parse(_endTimeController.text);

      if (startTime >= endTime) {
        setState(() {
          _videoTrimResult = 'Error: End time must be greater than start time';
        });
        return;
      }

      setState(() {
        _videoTrimResult = 'Trimming video...';
      });

      final String? result = await _moonNativePlugin.trimVideo(videoPath, startTime, endTime);

      setState(() {
        _videoTrimResult = result != null ? 'Video trimmed successfully!\nOutput: $result' : 'Error: Trim operation returned null';
      });
    } on FormatException catch (e) {
      setState(() {
        _videoTrimResult = 'Error: Invalid time format - ${e.message}';
      });
    } on PlatformException catch (e) {
      setState(() {
        _videoTrimResult = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _videoTrimResult = 'Error: $e';
      });
    }
  }

  Future<void> _performNativeCalculation() async {
    try {
      final double valueA = double.parse(_valueAController.text);
      final double valueB = double.parse(_valueBController.text);

      final double result = await _moonNativePlugin.performNativeCalculation(valueA, valueB);

      setState(() {
        _calculationResult = 'Result: $result\n\nNote: Each platform performs a different calculation:\n'
            '• iOS: (a * b) + 10\n'
            '• Android: a^b (power)\n'
            '• macOS: ((a + b) / 2) * CPU cores\n'
            '• Windows: (a - b)²\n';
      });
    } on PlatformException catch (e) {
      setState(() {
        _calculationResult = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _calculationResult = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MoonNative Plugin Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Running on: $_platformVersion\n',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Native Calculation Example:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueAController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Value A',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _valueBController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Value B',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performNativeCalculation,
                child: const Text('Calculate on Native Side'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_calculationResult),
              ),
              const SizedBox(height: 30),
              const Text(
                'Video Trimming Example:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _videoPathController,
                decoration: const InputDecoration(
                  labelText: 'Video Path',
                  hintText: '/path/to/video.mp4',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startTimeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Start Time (s)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _endTimeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'End Time (s)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _trimVideo,
                child: const Text('Trim Video'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_videoTrimResult),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
