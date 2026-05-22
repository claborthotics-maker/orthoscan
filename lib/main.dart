import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'orthoscan_ffi.dart';

void main() {
  runApp(const OrthoScanApp());
}

class OrthoScanApp extends StatelessWidget {
  const OrthoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrthoScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _channel = MethodChannel('com.orthotics.orthoscan/arcore');

  bool _isScanning = false;
  int _pointCount = 0;
  String _status = 'Ready to Scan';
  Timer? _captureTimer;

  Future<void> _checkArCore() async {
    try {
      final result = await _channel.invokeMethod('isArCoreSupported');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ARCore supported: $result')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ARCore check failed: $e')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    try {
      await _channel.invokeMethod('startScan');
      orthoscanStartSession();

      setState(() {
        _isScanning = true;
        _pointCount = 0;
        _status = 'Scanning...';
      });

      // Capture depth frames every 100ms (10 times per second)
      _captureTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _captureFrame(),
      );
    } catch (e) {
      setState(() {
        _status = 'Failed to start: $e';
      });
    }
  }

  Future<void> _captureFrame() async {
    try {
      await _channel.invokeMethod('captureFrame');
      if (mounted) {
        setState(() {
          _pointCount = orthoscanGetPointCount();
        });
      }
    } catch (e) {
      debugPrint('Frame capture error: $e');
    }
  }

  Future<void> _stopScan() async {
    _captureTimer?.cancel();
    _captureTimer = null;

    try {
      await _channel.invokeMethod('stopScan');
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }

    orthoscanStopSession();
    setState(() {
      _isScanning = false;
      _status = 'Scan complete — $_pointCount points captured';
    });
  }

  void _reset() {
    _captureTimer?.cancel();
    _captureTimer = null;
    orthoscanReset();
    setState(() {
      _isScanning = false;
      _pointCount = 0;
      _status = 'Ready to Scan';
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OrthoScan'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isScanning
                    ? Colors.green.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _isScanning ? Icons.radar : Icons.scanner,
                    size: 80,
                    color: _isScanning ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Points captured: $_pointCount',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
              label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: _isScanning ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _checkArCore,
              icon: const Icon(Icons.view_in_ar),
              label: const Text('Check ARCore'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}