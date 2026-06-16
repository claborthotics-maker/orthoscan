import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/work_order.dart';
import '../models/patient.dart';
import '../models/work_order_template.dart';

class PdfService {
  static Future<Uint8List> generateWorkOrderPdf({
    required WorkOrder wo,
    required Patient patient,
    Uint8List? leftDiagramImage,
    Uint8List? rightDiagramImage,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pw.ImageProvider? leftImg;
    pw.ImageProvider? rightImg;
    if (leftDiagramImage != null) leftImg = pw.MemoryImage(leftDiagramImage);
    if (rightDiagramImage != null) rightImg = pw.MemoryImage(rightDiagramImage);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LAB ORDER',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 22, color: PdfColors.white)),
                    if (wo.clinicName.isNotEmpty)
                      pw.Text(wo.clinicName,
                          style: pw.TextStyle(
                              font: font, fontSize: 13, color: PdfColors.blueGrey200)),
                    if (wo.clinicianName.isNotEmpty)
                      pw.Text('Clinician: ${wo.clinicianName}',
                          style: pw.TextStyle(
                              font: font, fontSize: 12, color: PdfColors.blueGrey200)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (wo.dateOfService != null)
                      pw.Text('Date of Service: ${_fmtDate(wo.dateOfService)}',
                          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
                    if (wo.expectedDeliveryDate != null)
                      pw.Text('Expected Delivery: ${_fmtDate(wo.expectedDeliveryDate)}',
                          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
                    pw.Text('Submitted: ${_fmtDate(wo.submittedAt ?? DateTime.now())}',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Patient & Order
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildSection(
                  title: 'PATIENT',
                  fontBold: fontBold,
                  font: font,
                  rows: [
                    _rd('Name', patient.fullName),
                    if (patient.dateOfBirth.isNotEmpty) _rd('DOB', patient.dateOfBirth),
                    if (patient.patientId.isNotEmpty) _rd('Patient ID', patient.patientId),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildSection(
                  title: 'ORDER',
                  fontBold: fontBold,
                  font: font,
                  rows: [
                    _rd('Work Order', wo.displayName),
                    _rd('Type', _typeName(wo.templateType)),
                    _rd('Quantity', wo.quantityLabel),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Shoe Size
          _buildSection(
            title: 'SHOE SIZE',
            fontBold: fontBold,
            font: font,
            rows: [
              _rd('Gender', wo.shoeSizeGender),
              if (wo.sameSizeForBothFeet) ...[
                _rd('Size', wo.shoeSize),
                _rd('Width', wo.shoeWidth),
              ] else ...[
                _rd('Left Size', wo.shoeSizeLeft),
                _rd('Left Width', wo.shoeWidthLeft),
                _rd('Right Size', wo.shoeSizeRight),
                _rd('Right Width', wo.shoeWidthRight),
              ],
            ],
          ),
          pw.SizedBox(height: 12),

          if (_hasProductSpecs(wo)) ...[
            _buildSection(
              title: 'PRODUCT SPECS',
              fontBold: fontBold,
              font: font,
              rows: _productSpecRows(wo),
            ),
            pw.SizedBox(height: 12),
          ],

          if (wo.archModification != 0) ...[
            _buildSection(
              title: 'ARCH MODIFICATION',
              fontBold: fontBold,
              font: font,
              rows: [
                _rd('Arch Mod', wo.archModification > 0
                    ? '+${wo.archModification}' : '${wo.archModification}'),
              ],
            ),
            pw.SizedBox(height: 12),
          ],

          if (_hasAccommodations(wo)) ...[
            _buildSection(
              title: 'ACCOMMODATIONS',
              fontBold: fontBold,
              font: font,
              rows: _accommodationRows(wo),
            ),
            pw.SizedBox(height: 12),
          ],

          // Foot Diagram
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('FOOT DIAGRAM',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: PdfColors.blueGrey700,
                        letterSpacing: 1)),
                pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
                pw.SizedBox(height: 8),
                if (leftImg != null || rightImg != null)
                  pw.Row(
                    children: [
                      if (leftImg != null)
                        pw.Expanded(
                          child: pw.Column(children: [
                            pw.Text('Left Foot',
                                style: pw.TextStyle(font: fontBold, fontSize: 10,
                                    color: PdfColors.blueGrey600)),
                            pw.SizedBox(height: 4),
                            pw.Image(leftImg, height: 180),
                          ]),
                        ),
                      if (leftImg != null && rightImg != null)
                        pw.SizedBox(width: 16),
                      if (rightImg != null)
                        pw.Expanded(
                          child: pw.Column(children: [
                            pw.Text('Right Foot',
                                style: pw.TextStyle(font: fontBold, fontSize: 10,
                                    color: PdfColors.blueGrey600)),
                            pw.SizedBox(height: 4),
                            pw.Image(rightImg, height: 180),
                          ]),
                        ),
                    ],
                  )
                else
                  pw.Text('No diagram markings added',
                      style: pw.TextStyle(font: font, fontSize: 11,
                          color: PdfColors.blueGrey400)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Notes
          _buildSection(
            title: 'NOTES',
            fontBold: fontBold,
            font: font,
            rows: [
              _rd('', wo.specialInstructions.isEmpty ? 'None' : wo.specialInstructions),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSection({
    required String title,
    required pw.Font fontBold,
    required pw.Font font,
    required List<_RD?> rows,
  }) {
    final valid = rows.whereType<_RD>().toList();
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: 10,
                  color: PdfColors.blueGrey700, letterSpacing: 1)),
          pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
          pw.SizedBox(height: 4),
          ...valid.map((r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: r.label.isEmpty
                    ? pw.Text(r.value,
                        style: pw.TextStyle(font: font, fontSize: 11))
                    : pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 120,
                            child: pw.Text(r.label,
                                style: pw.TextStyle(font: fontBold, fontSize: 11,
                                    color: PdfColors.blueGrey600)),
                          ),
                          pw.Expanded(
                            child: pw.Text(r.value,
                                style: pw.TextStyle(font: font, fontSize: 11)),
                          ),
                        ],
                      ),
              )),
        ],
      ),
    );
  }

  static _RD? _rd(String label, String value) {
    if (value.isEmpty || value == 'None') return null;
    return _RD(label, value);
  }

  static bool _hasProductSpecs(WorkOrder wo) =>
      wo.baseThickness.isNotEmpty ||
      wo.shellThickness.isNotEmpty ||
      (wo.topCoverType.isNotEmpty && wo.topCoverType != 'None');

  static List<_RD?> _productSpecRows(WorkOrder wo) => [
        _rd('Base Thickness', wo.baseThickness),
        _rd('Base Grind', wo.baseGrind),
        if (wo.patientWeight != null) _RD('Patient Weight', '${wo.patientWeight} lbs'),
        _rd('Shell Thickness', wo.shellThickness),
        _rd('Base Shell Length', wo.baseShellLength),
        _rd('Mid Layer', wo.midLayerType),
        if (wo.midLayerType.isNotEmpty && wo.midLayerType != 'None')
          _rd('Mid Layer Thickness', wo.midLayerThickness),
        _rd('Top Cover', wo.topCoverType),
        if (wo.topCoverType.isNotEmpty &&
            wo.topCoverType != 'None' &&
            wo.topCoverType != 'P-Cell') ...[
          _rd('Cover Thickness', wo.topCoverThickness),
          _rd('Cover Color', wo.topCoverColor),
        ],
      ];

  static bool _hasAccommodations(WorkOrder wo) =>
      wo.heelPost != 'None' || wo.forefootPost != 'None' ||
      wo.heelWedge != 'None' || wo.forefootWedge != 'None' ||
      wo.metPadFoot != 'None' || wo.metBarFoot != 'None' ||
      wo.heelLiftFoot != 'None' || wo.heelCup != 'None';

  static List<_RD?> _accommodationRows(WorkOrder wo) => [
        _rd('Heel Post', wo.heelPost),
        _rd('Forefoot Post', wo.forefootPost),
        _rd('Heel Wedge', wo.heelWedge),
        _rd('Forefoot Wedge', wo.forefootWedge),
        _rd('Met Pad', wo.metPadFoot != 'None'
            ? '${wo.metPadFoot} (${wo.metPadSize})' : ''),
        _rd('Met Bar', wo.metBarFoot != 'None'
            ? '${wo.metBarFoot} (${wo.metBarSize})' : ''),
        _rd('Heel Lift', wo.heelLiftFoot != 'None'
            ? '${wo.heelLiftFoot}${wo.heelLiftHeight.isNotEmpty ? ' - ${wo.heelLiftHeight}' : ''}'
            : ''),
        _rd('Heel Cup', wo.heelCup),
      ];

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day}/${d.year}';
  }

  static String _typeName(TemplateType? type) {
    switch (type) {
      case TemplateType.rebound: return 'Rebound';
      case TemplateType.polyShell: return 'Poly Shell';
      case TemplateType.partialFoot: return 'Partial Foot';
      case null: return 'Unknown';
    }
  }
}

class _RD {
  final String label;
  final String value;
  _RD(this.label, this.value);
}
