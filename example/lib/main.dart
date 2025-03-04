import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moon_native/moon_native.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _calculationResult = 'Not calculated yet';
  final _moonNativePlugin = MoonNative();
  
  // Values for the calculation
  final TextEditingController _valueAController = TextEditingController(text: '5');
  final TextEditingController _valueBController = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _valueAController.dispose();
    _valueBController.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _moonNativePlugin.getPlatformVersion() ?? 'Unknown platform version';
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
              Text('Running on: $_platformVersion\n', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text('Native Calculation Example:', 
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
            ],
          ),
        ),
      ),
    );
  }
}
