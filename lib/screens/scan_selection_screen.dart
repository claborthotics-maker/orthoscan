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

  void _startScan(BuildContext context, ScanType scanType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          patient: patient,
          scanType: scanType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          'New Scan â€” ${patient.fullName}',
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

           // â”€â”€â”€ Impression Box (Coming Soon) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _ScanOptionCard(
              icon: Icons.inventory_2,
              title: 'Scan Impression Box',
              description: 'Coming soon â€” scan a foam impression box '
                  'casting of the patient\'s foot.',
              color: Colors.white24,
              tags: ['Coming Soon'],
              onTap: null,
              disabled: true,
            ),

            const SizedBox(height: 16),

            // â”€â”€â”€ Direct Foot (Coming Soon) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _ScanOptionCard(
              icon: Icons.accessibility_new,
              title: 'Scan Foot Directly',
              description: 'Coming soon â€” scan the patient\'s foot '
                  'directly using the device camera.',
              color: Colors.white24,
              tags: ['Coming Soon'],
              onTap: null,
              disabled: true,
            ),

            const SizedBox(height: 16),

            // â”€â”€â”€ Prosthetic (Coming Soon) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _ScanOptionCard(
              icon: Icons.medical_services,
              title: 'Scan Prosthetic',
              description: 'Coming soon â€” scan prosthetic limb for custom '
                  'orthotic fabrication.',
              color: Colors.white24,
              tags: ['Coming Soon'],
              onTap: null,
              disabled: true,
            ),

            const Spacer(),

            // â”€â”€â”€ Info Box â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€â”€ Scan Option Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
