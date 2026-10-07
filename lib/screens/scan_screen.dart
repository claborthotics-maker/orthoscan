import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import 'scan_selection_screen.dart';

class ScanScreen extends StatefulWidget {
  final Patient patient;
  final ScanType scanType;
  const ScanScreen({super.key, required this.patient, required this.scanType});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _channel = MethodChannel('com.orthotics.orthoscan/scan');
  bool _isLiDARAvailable = false;
  bool _isScanning = false;
  String? _scannedFilePath;

@override
  void initState() {
    super.initState();
    _checkLiDAR();
  }

   Future<void> _checkLiDAR() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final available = await _channel.invokeMethod<bool>('isLiDARAvailable') ?? false;
      debugPrint('LiDAR check result: $available');
      setState(() => _isLiDARAvailable = available);
    } catch (e) {
      debugPrint('LiDAR check failed: $e');
      setState(() => _isLiDARAvailable = false);
    }
  }

  Future<void> _startScan() async {
    if (!_isLiDARAvailable) return;
    setState(() => _isScanning = true);
    try {
      final filePath = await _channel.invokeMethod<String>('startScan', {
        'scanType': widget.scanType == ScanType.directFoot ? 'directFoot' : 'impressionBox',
      });
      setState(() {
        _scannedFilePath = filePath;
        _isScanning = false;
      });
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan captured successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.scanType == ScanType.directFoot ? 'Direct Foot Scan' : 'Impression Box Scan';
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isLiDARAvailable ? Icons.view_in_ar : Icons.no_photography,
                size: 80,
                color: _isLiDARAvailable ? const Color(0xFF4FC3F7) : Colors.red,
              ),
              const SizedBox(height: 24),
              if (!_isLiDARAvailable) ...[
                const Text(
                  'LiDAR Not Available',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '3D scanning requires a LiDAR-equipped device (iPhone 12 Pro or newer, iPad Pro).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ] else if (_scannedFilePath != null) ...[
                const Text(
                  'Scan Complete!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Icon(Icons.check_circle, color: Color(0xFF4FC3F7), size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Your scan has been saved and will be included with the work order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _startScan,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
                  child: const Text('Rescan', style: TextStyle(color: Colors.white)),
                ),
              ] else ...[
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Position the foot in frame and tap Start Scan. Move slowly around the foot to capture all angles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 32),
                _isScanning
                    ? const CircularProgressIndicator(color: Color(0xFF4FC3F7))
                    : ElevatedButton.icon(
                        onPressed: _startScan,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
                        icon: const Icon(Icons.view_in_ar, color: Colors.white),
                        label: const Text('Start Scan', style: TextStyle(color: Colors.white)),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

