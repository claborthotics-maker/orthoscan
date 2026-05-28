import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../models/patient.dart';
import '../orthoscan_ffi.dart';
import 'scan_selection_screen.dart';

class ScanScreen extends StatefulWidget {
  final Patient patient;
  final ScanType scanType;

  const ScanScreen({
    super.key,
    required this.patient,
    required this.scanType,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.orthotics.orthoscan/arcore');

  bool _isScanning = false;
  int _pointCount = 0;
  String _status = 'Ready to Scan';
  Timer? _captureTimer;

  // Camera
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraError = false;
  String _cameraErrorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = 'No cameras found on device';
        });
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _cameraInitialized = true;
          _cameraError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = e.toString();
        });

        // Show permission dialog if camera permission denied
        if (e.toString().contains('permission') ||
            e.toString().contains('Permission')) {
          _showPermissionDialog();
        }
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Camera Permission Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'OrthoScan needs camera access to perform 3D scanning. '
          'Please grant camera permission in Settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Open app settings
              const MethodChannel('com.orthotics.orthoscan/settings')
                  .invokeMethod('openSettings');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3460)),
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String get _scanTypeLabel {
    switch (widget.scanType) {
      case ScanType.impressionBox:
        return 'Impression Box Scan';
      case ScanType.directFoot:
        return 'Direct Foot Scan';
    }
  }

  String get _scanInstructions {
    switch (widget.scanType) {
      case ScanType.impressionBox:
        return '1. Place the impression box on a flat surface\n'
            '2. Hold device 12-18 inches above the box\n'
            '3. Tap Start Scan and slowly move around the box\n'
            '4. Tap Stop when complete';
      case ScanType.directFoot:
        return '1. Have the patient sit with foot relaxed\n'
            '2. Hold device 12-18 inches above the foot\n'
            '3. Tap Start Scan and slowly move around the foot\n'
            '4. Tap Stop when complete';
    }
  }

  Color get _scanColor {
    switch (widget.scanType) {
      case ScanType.impressionBox:
        return const Color(0xFF4FC3F7);
      case ScanType.directFoot:
        return Colors.green;
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

      _captureTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _captureFrame(),
      );
    } catch (e) {
      setState(() {
        _status = 'Failed to start: $e';
      });
      if (e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        _showPermissionDialog();
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _captureTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (_cameraError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt,
                  color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Text(
                'Camera unavailable',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _cameraErrorMessage,
                style: const TextStyle(
                    color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4FC3F7),
          ),
        ),
      );
    }

    return ClipRRect(
      child: CameraPreview(_cameraController!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: Text(
          _scanTypeLabel,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              backgroundColor: _scanColor.withOpacity(0.15),
              label: Text(
                widget.patient.fullName,
                style: TextStyle(color: _scanColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [

          // ─── Full Screen Camera Preview ──────────────────────────────
          Positioned.fill(
            child: _buildCameraPreview(),
          ),

          // ─── Scanning Overlay ────────────────────────────────────────
          if (_isScanning)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _scanColor.withOpacity(0.6),
                    width: 3,
                  ),
                ),
                child: CustomPaint(
                  painter: _ScanOverlayPainter(color: _scanColor),
                ),
              ),
            ),

          // ─── Top Status Bar ──────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isScanning
                        ? _scanColor.withOpacity(0.5)
                        : Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isScanning ? Colors.red : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _scanColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_pointCount pts',
                      style: TextStyle(
                          color: _scanColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Instructions (before scan) ──────────────────────────────
          if (!_isScanning && _pointCount == 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 160,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _scanInstructions,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          // ─── Bottom Controls ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(children: [
                // Reset button
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white54, size: 20),
                  label: const Text('Reset',
                      style: TextStyle(color: Colors.white54)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(width: 12),

                // Start/Stop button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    icon: Icon(
                      _isScanning
                          ? Icons.stop_circle
                          : Icons.play_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: Text(
                      _isScanning ? 'Stop Scan' : 'Start Scan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning
                          ? Colors.red.shade800
                          : const Color(0xFF0F3460),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan Overlay Painter ─────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final Color color;
  _ScanOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Corner markers
    const cornerSize = 30.0;
    const cornerWidth = 3.0;
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke;

    // Top left
    canvas.drawLine(
        const Offset(0, cornerSize), const Offset(0, 0), cornerPaint);
    canvas.drawLine(
        const Offset(0, 0), Offset(cornerSize, 0), cornerPaint);

    // Top right
    canvas.drawLine(Offset(size.width - cornerSize, 0),
        Offset(size.width, 0), cornerPaint);
    canvas.drawLine(Offset(size.width, 0),
        Offset(size.width, cornerSize), cornerPaint);

    // Bottom left
    canvas.drawLine(Offset(0, size.height - cornerSize),
        Offset(0, size.height), cornerPaint);
    canvas.drawLine(Offset(0, size.height),
        Offset(cornerSize, size.height), cornerPaint);

    // Bottom right
    canvas.drawLine(Offset(size.width - cornerSize, size.height),
        Offset(size.width, size.height), cornerPaint);
    canvas.drawLine(Offset(size.width, size.height - cornerSize),
        Offset(size.width, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => false;
}