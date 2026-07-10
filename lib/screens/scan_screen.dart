import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../services/database_service.dart';
import 'scan_selection_screen.dart';
import 'model_viewer_screen.dart';

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
      _status = 'Scan complete â€” $_pointCount points captured';
      _scanComplete = true;
    });

    // Build a mesh from the scan; fall back to raw points if meshing fails
    List<double> meshTris = [];
    List<double> points = [];
    try {
      final rawMesh = await _viewChannel.invokeMethod<List>('buildMesh');
      meshTris = rawMesh?.cast<double>() ?? [];
    } catch (e) {
      debugPrint('Build mesh error: $e');
    }

    if (meshTris.length < 9) {
      try {
        final raw = await _viewChannel.invokeMethod<List>('getPoints');
        points = _downsampleForViewer(raw?.cast<double>() ?? [], 15000);
      } catch (e) {
        debugPrint('Get points error: $e');
      }
    }

    if (meshTris.length < 9 && points.length < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No surface captured. Try scanning again.'),
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
          mesh: meshTris,
          patientName: widget.patient.fullName,
          onFinish: () => _saveScan(meshTris.isNotEmpty
              ? meshTris.length ~/ 9
              : points.length ~/ 3),
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

  Future<void> _saveScan(int featureCount) async {
    final scanLabel =
        'Scan ${DateTime.now().toString().substring(0, 16)} ($featureCount)';
    widget.patient.scanFiles.add(scanLabel);

    try {
      await DatabaseService().updatePatient(widget.patient);
    } catch (e) {
      debugPrint('Save scan error: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // close viewer
    Navigator.pop(context); // back to patient
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
          // Status Bar
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 8, height: 8,
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
                  Text(_status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scanColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
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

          // ARCore View
          Expanded(
            child: AndroidView(
              viewType: 'arcore_view',
              onPlatformViewCreated: (id) {
                debugPrint('ARCore view created: $id');
              },
            ),
          ),

          // Instructions
          if (!_isScanning && !_scanComplete)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Text(_scanInstructions,
                  style: const TextStyle(
                      color: Colors.white70,
                      height: 1.6,
                      fontSize: 13)),
            ),

          // Scan Complete
          if (_scanComplete)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _scanColor, size: 32),
                  const SizedBox(width: 12),
                  Text('$_pointCount points captured',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // Controls
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
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(
                    _isScanning ? Icons.stop_circle : Icons.play_circle,
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
