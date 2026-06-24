import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../models/patient.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';

class WorkOrderConfirmationScreen extends StatelessWidget {
  final WorkOrder workOrder;
  final Patient patient;
  final VoidCallback onConfirm;
  final Uint8List? leftDiagramImage;
  final Uint8List? rightDiagramImage;

  const WorkOrderConfirmationScreen({
    super.key,
    required this.workOrder,
    required this.patient,
    required this.onConfirm,
    this.leftDiagramImage,
    this.rightDiagramImage,
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
                              color: Color(0xFF4FC3F7), fontSize: 14)),
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

            _buildSection('Clinician & Dates', Icons.medical_services, [
              if (workOrder.clinicianName.isNotEmpty)
                _row('Clinician', workOrder.clinicianName),
              if (workOrder.clinicName.isNotEmpty)
                _row('Clinic', workOrder.clinicName),
              if (workOrder.dateOfService != null)
                _row('Date of Service', _fmtDate(workOrder.dateOfService)),
              if (workOrder.expectedDeliveryDate != null)
                _row('Expected Delivery', _fmtDate(workOrder.expectedDeliveryDate)),
            ]),

            const SizedBox(height: 16),

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

            _buildSection('Quantity', Icons.numbers, [
              _row('Quantity', workOrder.quantityLabel),
            ]),

            const SizedBox(height: 16),

            if (fields.isNotEmpty) ...[
              _buildSection('Product Specs', Icons.layers, fields),
              const SizedBox(height: 16),
            ],

            if (workOrder.archModification != 0) ...[
              _buildSection('Arch Modification', Icons.architecture, [
                _row('Arch Mod',
                    workOrder.archModification > 0
                        ? '+${workOrder.archModification}'
                        : '${workOrder.archModification}'),
              ]),
              const SizedBox(height: 16),
            ],

            _buildSection('Accommodations', Icons.tune, accommodations),

            const SizedBox(height: 16),

            // Foot Diagram
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.draw, color: Color(0xFF4FC3F7), size: 20),
                    SizedBox(width: 8),
                    Text('Foot Diagram',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ]),
                  const SizedBox(height: 12),
                  if (leftDiagramImage != null || rightDiagramImage != null)
                    Row(children: [
                      if (leftDiagramImage != null)
                        Expanded(
                          child: Column(children: [
                            const Text('Left Foot',
                                style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(leftDiagramImage!,
                                  fit: BoxFit.contain),
                            ),
                          ]),
                        ),
                      if (leftDiagramImage != null && rightDiagramImage != null)
                        const SizedBox(width: 8),
                      if (rightDiagramImage != null)
                        Expanded(
                          child: Column(children: [
                            const Text('Right Foot',
                                style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(rightDiagramImage!,
                                  fit: BoxFit.contain),
                            ),
                          ]),
                        ),
                    ])
                  else
                    const Row(children: [
                      Icon(Icons.draw, color: Color(0xFF4FC3F7), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No diagram markings added',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
 // Confirm & Submit button — marks as submitted AND opens share sheet
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // First confirm/submit
                  onConfirm();
                  // Then generate and share PDF
                  final bytes = await PdfService.generateWorkOrderPdf(
                    wo: workOrder,
                    patient: patient,
                    leftDiagramImage: leftDiagramImage,
                    rightDiagramImage: rightDiagramImage,
                  );
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename:
                        '${workOrder.displayName.replaceAll(' ', '_')}_lab_order.pdf',
                  );
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
    final isPolyShell = workOrder.templateType == TemplateType.polyShell;
    if (!isPolyShell) add('Base Thickness', workOrder.baseThickness);
    if (!isPolyShell) add('Base Grind', workOrder.baseGrind);
    if (isPolyShell) add('Shell Thickness', workOrder.shellThickness);
    if (isPolyShell) add('Base Shell Length', workOrder.baseShellLength);
    if (isPolyShell && workOrder.patientWeight != null)
      rows.add(_row('Patient Weight', '${workOrder.patientWeight} lbs'));
    if (isPolyShell) add('Mid Layer', workOrder.midLayerType);
    if (isPolyShell && workOrder.midLayerType != 'None')
      add('Mid Layer Thickness', workOrder.midLayerThickness);
    add('Top Cover', workOrder.topCoverType);
    if (workOrder.topCoverType != 'None' && workOrder.topCoverType != 'P-Cell') {
      add('Cover Thickness', workOrder.topCoverThickness);
      add('Cover Color', workOrder.topCoverColor);
    }
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



