import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import 'scan_selection_screen.dart';
import 'model_viewer_screen.dart';
import '../services/database_service.dart';

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

class _ScanScreenState extends State<ScanScreen> {
  static const _viewChannel =
      MethodChannel('com.orthotics.orthoscan/arcore_view');

  bool _isScanning = false;
  int _pointCount = 0;
  String _status = 'Ready to Scan';
  bool _scanComplete = false;
  Timer? _updateTimer;

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
      await _viewChannel.invokeMethod('startScan');
      setState(() {
        _isScanning = true;
        _pointCount = 0;
        _status = 'Scanning...';
        _scanComplete = false;
      });
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _updateCount(),
      );
    } catch (e) {
      setState(() => _status = 'Failed to start: $e');
    }
  }

  Future<void> _updateCount() async {
    try {
      final count =
          await _viewChannel.invokeMethod<int>('getPointCount') ?? 0;
      if (mounted && count != _pointCount) {
        setState(() {
          _pointCount = count;
          _status = 'Scanning... $_pointCount points';
        });
      }
    } catch (e) {
      debugPrint('Update count error: $e');
    }
  }

  Future<void> _stopScan() async {
  _updateTimer?.cancel();
  _updateTimer = null;
  try {
    await _viewChannel.invokeMethod('stopScan');
  } catch (e) {
    debugPrint('Stop error: $e');
  }
  if (!mounted) return;

  setState(() {
    _isScanning = false;
    _status = 'Scan complete — $_pointCount points captured';
    _scanComplete = true;
  });

    // Fetch the captured points and open the 3D viewer
  List<double> points = [];
  try {
    final raw = await _viewChannel.invokeMethod<List>('getPoints');
    final all = raw?.cast<double>() ?? [];
    points = _downsampleForViewer(all, 15000);
  } catch (e) {
    debugPrint('Get points error: $e');
  }

  if (points.length < 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No points captured. Try scanning again.'),
      ),
    );
    return;
  }

  if (!mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ModelViewerScreen(
        points: points,
        patientName: widget.patient.fullName,
        onFinish: () => _saveScan(points),
      ),
    ),
  );
}

// Reduce point count for smooth 3D preview rendering
List<double> _downsampleForViewer(List<double> flat, int maxPoints) {
  final total = flat.length ~/ 3;
  if (total <= maxPoints) return flat;
  final stride = (total / maxPoints).ceil();
  final out = <double>[];
  for (int i = 0; i < total; i += stride) {
    final base = i * 3;
    out.add(flat[base]);
    out.add(flat[base + 1]);
    out.add(flat[base + 2]);
  }
  return out;
}

Future<void> _saveScan(List<double> points) async {
  // Save scan to patient
  final scanLabel =
      'Scan ${DateTime.now().toString().substring(0, 16)} '
      '(${points.length ~/ 3} pts)';
  widget.patient.scanFiles.add(scanLabel);

  try {
    await DatabaseService().updatePatient(widget.patient);
  } catch (e) {
    debugPrint('Save scan error: $e');
  }

  if (!mounted) return;
  // Pop the viewer
  Navigator.pop(context);
  // Pop the scan screen back to patient
  Navigator.pop(context);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Scan saved to patient')),
  );
}

  Future<void> _reset() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    try {
      await _viewChannel.invokeMethod('reset');
    } catch (e) {
      debugPrint('Reset error: $e');
    }
    setState(() {
      _isScanning = false;
      _pointCount = 0;
      _status = 'Ready to Scan';
      _scanComplete = false;
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_scanTypeLabel,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              backgroundColor: _scanColor.withOpacity(0.15),
              label: Text(widget.patient.fullName,
                  style: TextStyle(color: _scanColor, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── ARCore View + Overlays ──────────────────────────────────
          Expanded(
            child: Stack(
              children: [

                // ARCore Native View
                Positioned.fill(
                  child: AndroidView(
                    viewType: 'arcore_view',
                    onPlatformViewCreated: (id) {
                      debugPrint('ARCore view created: $id');
                    },
                  ),
                ),

                // Scanning Border
                if (_isScanning)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: _scanColor.withOpacity(0.6),
                              width: 3),
                        ),
                        child: CustomPaint(
                          painter: _ScanOverlayPainter(
                              color: _scanColor),
                        ),
                      ),
                    ),
                  ),

                // Scan Complete Overlay
                if (_scanComplete)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: _scanColor, size: 80),
                              const SizedBox(height: 16),
                              Text(
                                '$_pointCount points captured',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('Scan complete!',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Top Status Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
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
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isScanning
                                    ? Colors.red
                                    : _scanComplete
                                        ? Colors.green
                                        : Colors.white24,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(_status,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w500)),
                            ),
                          ]),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _scanColor.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text('$_pointCount pts',
                                style: TextStyle(
                                    color: _scanColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Instructions
                if (!_isScanning && !_scanComplete)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white12),
                        ),
                        child: Text(_scanInstructions,
                            style: const TextStyle(
                                color: Colors.white70,
                                height: 1.6,
                                fontSize: 13)),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Controls (outside AndroidView) ─────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Row(children: [
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
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isScanning ? _stopScan : _startScan,
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
                        fontWeight: FontWeight.bold),
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
    const cornerSize = 30.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, cornerSize),
        const Offset(0, 0), paint);
    canvas.drawLine(
        const Offset(0, 0), Offset(cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width - cornerSize, 0),
        Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0),
        Offset(size.width, cornerSize), paint);
    canvas.drawLine(Offset(0, size.height - cornerSize),
        Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height),
        Offset(cornerSize, size.height), paint);
    canvas.drawLine(
        Offset(size.width - cornerSize, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(
        Offset(size.width, size.height - cornerSize),
        Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      false;
}