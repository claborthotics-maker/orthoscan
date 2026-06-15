import 'package:flutter/material.dart';
import '../models/work_order.dart';
import '../models/patient.dart';
import 'foot_diagram_widget.dart';

class WorkOrderConfirmationScreen extends StatelessWidget {
  final WorkOrder workOrder;
  final Patient patient;
  final VoidCallback onConfirm;

  const WorkOrderConfirmationScreen({
    super.key,
    required this.workOrder,
    required this.patient,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final fields = _collectFields();
    final accommodations = _collectAccommodations();
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Review Work Order',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF4FC3F7).withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.assignment,
                    color: Color(0xFF4FC3F7), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workOrder.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text(patient.fullName,
                          style: const TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontSize: 14)),
                      if (patient.dateOfBirth.isNotEmpty)
                        Text('DOB: ${patient.dateOfBirth}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      if (patient.patientId.isNotEmpty)
                        Text('ID: ${patient.patientId}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Clinician & Dates
            _buildSection('Clinician & Dates', Icons.medical_services, [
              if (workOrder.clinicianName.isNotEmpty)
                _row('Clinician', workOrder.clinicianName),
              if (workOrder.clinicName.isNotEmpty)
                _row('Clinic', workOrder.clinicName),
              if (workOrder.dateOfService != null)
                _row('Date of Service', _fmtDate(workOrder.dateOfService)),
              if (workOrder.expectedDeliveryDate != null)
                _row('Expected Delivery',
                    _fmtDate(workOrder.expectedDeliveryDate)),
            ]),

            const SizedBox(height: 16),

            // Shoe Size
            _buildSection('Shoe Size', Icons.straighten, [
              _row('Gender', workOrder.shoeSizeGender),
              if (workOrder.sameSizeForBothFeet) ...[
                _row('Size', workOrder.shoeSize),
                _row('Width', workOrder.shoeWidth),
              ] else ...[
                _row('Left Size', workOrder.shoeSizeLeft),
                _row('Left Width', workOrder.shoeWidthLeft),
                _row('Right Size', workOrder.shoeSizeRight),
                _row('Right Width', workOrder.shoeWidthRight),
              ],
            ]),

            const SizedBox(height: 16),

            // Quantity
            _buildSection('Quantity', Icons.numbers, [
              _row('Quantity', workOrder.quantityLabel),
            ]),

            const SizedBox(height: 16),

            // Product Specs
            if (fields.isNotEmpty)
              _buildSection('Product Specs', Icons.layers, fields),

            const SizedBox(height: 16),

            // Arch Modification
            if (workOrder.archModification != 0) ...[
              _buildSection('Arch Modification', Icons.architecture, [
                _row('Arch Mod',
                    workOrder.archModification > 0
                        ? '+${workOrder.archModification}'
                        : '${workOrder.archModification}'),
              ]),
              const SizedBox(height: 16),
            ],

            // Accommodations
            _buildSection('Accommodations', Icons.tune, accommodations),

            const SizedBox(height: 16),

            // Foot Diagram — always shown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF4FC3F7).withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw,
                      color: Color(0xFF4FC3F7), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Foot Diagram',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(height: 4),
                      Text(
                        'Foot diagram markings and notes will be included with this submission.',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Notes — always shown
            _buildSection('Notes', Icons.note_alt, [
              _row('', workOrder.specialInstructions.isEmpty
                  ? 'None'
                  : workOrder.specialInstructions),
            ]),

            const SizedBox(height: 24),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Once submitted, the work order will be marked as Submitted.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Confirm & Submit to Lab',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3460),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(value,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day}/${d.year}';
  }

  List<Widget> _collectFields() {
    final rows = <Widget>[];
    void add(String label, String value) {
      if (value.isNotEmpty && value != 'None') rows.add(_row(label, value));
    }
    add('Base Thickness', workOrder.baseThickness);
    add('Base Grind', workOrder.baseGrind);
    add('Top Cover', workOrder.topCoverType);
    if (workOrder.topCoverType != 'None' &&
        workOrder.topCoverType != 'P-Cell') {
      add('Cover Thickness', workOrder.topCoverThickness);
      add('Cover Color', workOrder.topCoverColor);
    }
    if (workOrder.patientWeight != null)
      rows.add(_row('Patient Weight', '${workOrder.patientWeight} lbs'));
    add('Shell Thickness', workOrder.shellThickness);
    add('Base Shell Length', workOrder.baseShellLength);
    add('Mid Layer', workOrder.midLayerType);
    if (workOrder.midLayerType != 'None')
      add('Mid Layer Thickness', workOrder.midLayerThickness);
    return rows;
  }

  List<Widget> _collectAccommodations() {
    final rows = <Widget>[];
    void add(String label, String value) {
      if (value.isNotEmpty && value != 'None') rows.add(_row(label, value));
    }
    add('Heel Post', workOrder.heelPost);
    add('Forefoot Post', workOrder.forefootPost);
    add('Heel Wedge', workOrder.heelWedge);
    add('Forefoot Wedge', workOrder.forefootWedge);
    add('Met Pad Foot', workOrder.metPadFoot);
    add('Met Pad Size', workOrder.metPadSize);
    add('Met Bar Foot', workOrder.metBarFoot);
    add('Met Bar Size', workOrder.metBarSize);
    add('Heel Lift Foot', workOrder.heelLiftFoot);
    if (workOrder.heelLiftHeight.isNotEmpty)
      rows.add(_row('Heel Lift Height', workOrder.heelLiftHeight));
    add('Heel Cup', workOrder.heelCup);
    if (rows.isEmpty) rows.add(_row('', 'No accommodations selected'));
    return rows;
  }
}

// Placeholder showing foot diagram was included
class _FootDiagramPlaceholder extends StatelessWidget {
  const _FootDiagramPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(children: [
        Icon(Icons.draw, color: Color(0xFF4FC3F7), size: 20),
        SizedBox(width: 12),
        Text(
          'Foot diagram and markings included with submission',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ]),
    );
  }
}
