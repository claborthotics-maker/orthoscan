import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../orthoscan_ffi.dart';

class ScanScreen extends StatefulWidget {
  final Patient patient;

  const ScanScreen({super.key, required this.patient});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _channel = MethodChannel('com.orthotics.orthoscan/arcore');

  bool _isScanning = false;
  int _pointCount = 0;
  String _status = 'Ready to Scan';
  Timer? _captureTimer;

  Future<void> _startScan() async {
    try {
      await _channel.invokeMethod('startScan');
      orthoscanStartSession();

      setState(() {
        _isScanning = true;
        _pointCount = 0;
        _status = 'Scanning impression box...';
      });

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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          'Scan — ${widget.patient.fullName}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ─── Scan Status Card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isScanning
                      ? const Color(0xFF4FC3F7)
                      : Colors.white12,
                ),
              ),
              child: Column(
                children: [
                  // Animated icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isScanning ? Icons.radar : Icons.document_scanner,
                      key: ValueKey(_isScanning),
                      size: 100,
                      color: _isScanning
                          ? const Color(0xFF4FC3F7)
                          : Colors.white24,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Point count
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_pointCount points captured',
                      style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ─── Instructions ─────────────────────────────────────────────
            if (!_isScanning && _pointCount == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Place the impression box on a flat surface\n'
                      '2. Hold device 12-18 inches above the box\n'
                      '3. Tap Start Scan and slowly move around the box\n'
                      '4. Tap Stop when complete',
                      style: TextStyle(
                        color: Colors.white54,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // ─── Start/Stop Button ────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(
                _isScanning ? Icons.stop_circle : Icons.play_circle,
                color: Colors.white,
                size: 28,
              ),
              label: Text(
                _isScanning ? 'Stop Scan' : 'Start Scan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isScanning ? Colors.red.shade800 : const Color(0xFF0F3460),
                padding: const EdgeInsets.all(18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── Reset Button ─────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white54),
              label: const Text(
                'Reset',
                style: TextStyle(color: Colors.white54),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}