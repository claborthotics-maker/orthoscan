import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import 'scan_screen.dart';

enum ScanType {
  impressionBox,
  directFoot,
}

class ScanSelectionScreen extends StatelessWidget {
  final Patient patient;

  const ScanSelectionScreen({super.key, required this.patient});

  String _cleanName(String s) {
    final noSpaces = s.trim().replaceAll(RegExp(r'\s+'), '');
    final kept = noSpaces.replaceAll(RegExp(r'[^\p{L}\p{N}-]', unicode: true), '');
    return kept.isEmpty ? 'Unknown' : kept;
  }

  Future<String> _autoName(String filePath, ScanType scanType) async {
    try {
      final file = File(filePath);
      if (file.existsSync() == false) return filePath;
      final dir = file.parent.path;
      final base = filePath.split('/').last.toLowerCase();
      String kind;
      if (scanType == ScanType.impressionBox) {
        kind = 'Impression';
      } else if (base.contains('right')) {
        kind = 'Direct_Right';
      } else {
        kind = 'Direct_Left';
      }
      final prefix = '${_cleanName(patient.lastName)}_${_cleanName(patient.firstName)}_$kind';
      final pattern = RegExp('^' + RegExp.escape(prefix) + r'_(\d+)\.stl$');
      var maxN = 0;
      for (final p in patient.scanFiles) {
        final m = pattern.firstMatch(p.split('/').last);
        if (m != null) {
          final n = int.parse(m.group(1) ?? '0');
          if (n > maxN) maxN = n;
        }
      }
      var next = maxN + 1;
      var newPath = '$dir/${prefix}_$next.stl';
      while (File(newPath).existsSync()) {
        next += 1;
        newPath = '$dir/${prefix}_$next.stl';
      }
      await file.rename(newPath);
      return newPath;
    } catch (e) {
      return filePath;
    }
  }

  Future<void> _startScan(BuildContext context, ScanType scanType) async {
    final filePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          patient: patient,
          scanType: scanType,
        ),
      ),
    );
    if (filePath != null && context.mounted) {
      final named = await _autoName(filePath, scanType);
      if (context.mounted) {
        Navigator.pop(context, named);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          'New Scan – ${patient.fullName}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            const Text(
              'Select Scan Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            const Text(
              'Choose how you would like to capture\nthe patient\'s foot data',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

           // ─── Impression Box ─────────────────────────────────────────
            _ScanOptionCard(
              icon: Icons.inventory_2,
              title: 'Scan Impression Box',
              description: 'Scan a foam impression box casting of the patient\'s feet as one 3D scan using the front camera.',
              color: const Color(0xFF4FC3F7),
              tags: ['3D scan', 'Front camera'],
              onTap: () => _startScan(context, ScanType.impressionBox),
              disabled: false,
            ),

            const SizedBox(height: 16),

            // ─── Direct Foot ─────────────────────────────────────────────
            _ScanOptionCard(
              icon: Icons.accessibility_new,
              title: 'Scan Foot Directly',
              description: 'Scan the patient\'s foot directly as a 3D scan using the front camera.',
              color: Colors.green,
              tags: ['3D scan', 'Front camera'],
              onTap: () => _startScan(context, ScanType.directFoot),
              disabled: false,
            ),


            const Spacer(),

            // ─── Info Box ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF4FC3F7), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure the area is well lit and the device '
                      'camera is clean before scanning.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Scan Option Card ──────────────────────────────────────────────────────────
class _ScanOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final List<String> tags;
  final VoidCallback? onTap;
  final bool disabled;

  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.tags,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled
          ? const Color(0xFF16213E).withOpacity(0.5)
          : const Color(0xFF16213E),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: disabled ? Colors.white12 : color.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: disabled ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: disabled ? Colors.white24 : Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withOpacity(0.3)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: disabled ? Colors.white24 : color,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                Icon(Icons.arrow_forward_ios,
                    color: color.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}