import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../models/patient.dart';
import '../services/pdf_service.dart';
import '../services/database_service.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

class WorkOrderConfirmationScreen extends StatelessWidget {
  final WorkOrder workOrder;
  final Patient patient;
  final VoidCallback onConfirm;
  final Uint8List? leftDiagramImage;
  final Uint8List? rightDiagramImage;
  final List<String> packetLabels;
  final List<WorkOrder> packetOrders;

  const WorkOrderConfirmationScreen({
    super.key,
    required this.workOrder,
    required this.patient,
    required this.onConfirm,
    this.leftDiagramImage,
    this.rightDiagramImage,
    this.packetLabels = const [],
    this.packetOrders = const [],
  });

  String _safeName(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), '_');
    final k = t.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    return k.isEmpty ? 'work_order' : k;
  }

  String _kindOf(String name) {
    final n = name.toLowerCase();
    if (n.contains('impression')) return 'Impression';
    if (n.contains('right')) return 'Right foot (direct scan)';
    if (n.contains('left')) return 'Left foot (direct scan)';
    return 'Scan';
  }

  Future<String?> _resolveScan(String path) async {
    if (File(path).existsSync()) return path;
    final name = path.split('/').last;
    final dbDir = await getDatabasesPath();
    final alt = dbDir + '/' + name;
    if (File(alt).existsSync()) return alt;
    return null;
  }

  Future<void> _shareZip(Uint8List pdfBytes, Rect origin,
      [List<MapEntry<String, Uint8List>> extraPdfs = const []]) async {
    final base = _safeName(patient.lastName + '_' + patient.firstName + '_' + workOrder.displayName);
    final pdfName = base + '_lab_order.pdf';
    final archive = Archive();
    archive.addFile(ArchiveFile(pdfName, pdfBytes.length, pdfBytes));
    for (final e in extraPdfs) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    final lines = <String>[
      'Work order: ' + workOrder.displayName,
      'Patient: ' + patient.fullName,
      'Created: ' + DateTime.now().toIso8601String(),
      '',
      'Files in this zip:',
      pdfName + '  -  work order PDF',
    ];
    for (final e in extraPdfs) {
      lines.add(e.key + '  -  work order PDF');
    }
    final missing = <String>[];
    for (final p in workOrder.scanFiles) {
      final name = p.split('/').last;
      final real = await _resolveScan(p);
      if (real == null) {
        missing.add(name);
        continue;
      }
      final data = await File(real).readAsBytes();
      archive.addFile(ArchiveFile(name, data.length, data));
      lines.add(name + '  -  ' + _kindOf(name));
    }
    if (missing.isNotEmpty) {
      lines.add('');
      lines.add('Linked scans that could not be found on this device:');
      for (final m in missing) {
        lines.add(m);
      }
    }
    final manifest = Uint8List.fromList(lines.join('\n').codeUnits);
    archive.addFile(ArchiveFile('manifest.txt', manifest.length, manifest));
    final zipData = ZipEncoder().encode(archive);
    final zipBytes = List<int>.from(zipData as Iterable<int>);
    final dir = await Directory.systemTemp.createTemp('clab_zip');
    final zipFile = File(dir.path + '/' + base + (extraPdfs.isEmpty ? '' : '_packet') + '_lab_order.zip');
    await zipFile.writeAsBytes(zipBytes);
    await Share.shareXFiles(
      [XFile(zipFile.path)],
      subject: 'Lab order - ' + (packetLabels.length > 1 ? packetLabels.join(' + ') : workOrder.displayName),
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(packetLabels.length > 1 ? packetLabels.join(' + ') : workOrder.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text(patient.fullName,
                          style: const TextStyle(
                              color: Color(0xFF4FC3F7), fontSize: 14)),
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
                      if (leftDiagramImage != null && rightDiagramImage != null)
                        const SizedBox(width: 8),
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

            ..._productBlocks(),

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
            if (workOrder.scanFiles.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: const Text(
                    'Warning: no scans are linked to this work order. It will be sent with the PDF only.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
              )
            else
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Text(
                    workOrder.scanFiles.length.toString() +
                        ' scan(s) will be sent in the zip with the PDF.',
                    style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 13)),
              ),
            if (packetLabels.length > 1)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                ),
                child: Text(
                    'This order has ${packetLabels.length} products (${packetLabels.join(' + ')}). '
                    'The zip will contain one PDF per product, all submitted together.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final screen = MediaQuery.of(context).size;
                  final origin = Rect.fromLTWH(screen.width / 2, screen.height / 2, 1, 1);
                  // First confirm/submit
                  onConfirm();
                  // Then generate and share PDF
                  final bytes = await PdfService.generateWorkOrderPdf(
                    wo: workOrder,
                    patient: patient,
                    leftDiagramImage: leftDiagramImage,
                    rightDiagramImage: rightDiagramImage,
                  );
                  final extra = <MapEntry<String, Uint8List>>[];
                  try {
                    if (workOrder.packetId.isNotEmpty) {
                      final all = await DatabaseService().getPacketMembers(workOrder.packetId);
                      for (final s in all) {
                        if (s.id == workOrder.id) continue;
                        final now = DateTime.now();
                        if (s.submissionCount == 0) s.originalSubmittedAt = now;
                        s.submissionCount += 1;
                        s.status = WorkOrderStatus.submitted;
                        s.submittedAt = now;
                        await DatabaseService().updateWorkOrder(s);
                        final sb = await PdfService.generateWorkOrderPdf(
                          wo: s,
                          patient: patient,
                          leftDiagramImage: leftDiagramImage,
                          rightDiagramImage: rightDiagramImage,
                        );
                        extra.add(MapEntry(
                            _safeName(patient.lastName + '_' + patient.firstName + '_' + s.displayName) + '_lab_order.pdf',
                            sb));
                      }
                    }
                    await _shareZip(bytes, origin, extra);
                  } catch (e, st) {
                    print('ZIP ERROR: ' + e.toString());
                    print(st.toString());
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 30),
                        content: Text('ZIP ERROR: ' + e.toString()),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(workOrder.submissionCount > 0 ? 'Confirm & Re-Submit to Lab' : 'Confirm & Submit to Lab',
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

  List<Widget> _productBlocks() {
    final orders = packetOrders.isEmpty ? <WorkOrder>[workOrder] : packetOrders;
    final out = <Widget>[];
    for (final w in orders) {
      final fields = _collectFields(w);
      final acc = _collectAccommodations(w);
      out.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.5)),
        ),
        child: Text(w.displayName.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
      ));
      out.add(const SizedBox(height: 12));
      out.add(_buildSection('Quantity', Icons.numbers, [_row('Quantity', w.quantityLabel)]));
      out.add(const SizedBox(height: 16));
      if (fields.isNotEmpty) {
        out.add(_buildSection('Product Specs', Icons.layers, fields));
        out.add(const SizedBox(height: 16));
      }
      if (w.archModification != 0) {
        out.add(_buildSection('Arch Modification', Icons.architecture, [
          _row('Arch Mod', w.archModification > 0 ? '+${w.archModification}' : '${w.archModification}'),
        ]));
        out.add(const SizedBox(height: 16));
      }
      out.add(_buildSection('Accommodations', Icons.tune, acc));
      if (w.isPartialFootLeft || w.isPartialFootRight) {
        out.add(const SizedBox(height: 16));
        out.add(_buildSection('Partial Foot', Icons.accessibility_new, [
          if (w.isPartialFootLeft)
            _row('Left', w.toeFillerCountLeft > 0
                ? '${w.toeFillerCountLeft} toe filler${w.toeFillerCountLeft > 1 ? "s" : ""}'
                : 'Partial foot - no toe fillers'),
          if (w.isPartialFootRight)
            _row('Right', w.toeFillerCountRight > 0
                ? '${w.toeFillerCountRight} toe filler${w.toeFillerCountRight > 1 ? "s" : ""}'
                : 'Partial foot - no toe fillers'),
          _row('Pricing', 'Partial Foot costs more than a standard Rebound.'),
        ]));
      }
      out.add(const SizedBox(height: 16));
      out.add(_buildSection('Notes for the lab', Icons.note_alt, [
        _row('', w.specialInstructions.isEmpty ? 'None' : w.specialInstructions),
      ]));
      out.add(const SizedBox(height: 24));
    }
    return out;
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

  List<Widget> _collectFields([WorkOrder? w]) {
    final workOrder = w ?? this.workOrder;
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

  List<Widget> _collectAccommodations([WorkOrder? w]) {
    final workOrder = w ?? this.workOrder;
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







