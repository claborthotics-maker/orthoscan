import 'dart:typed_data';
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
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('LAB ORDER',
                            style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.white)),
                        if (wo.clinicName.isNotEmpty)
                          pw.Text(wo.clinicName,
                              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.blueGrey200)),
                        if (wo.clinicianName.isNotEmpty)
                          pw.Text('Clinician: ${wo.clinicianName}',
                              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.blueGrey200)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (wo.dateOfService != null)
                          pw.Text('Service: ${_fmtDate(wo.dateOfService)}',
                              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
                        if (wo.expectedDeliveryDate != null)
                          pw.Text('Delivery: ${_fmtDate(wo.expectedDeliveryDate)}',
                              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
                        pw.Text('Submitted: ${_fmtDate(wo.submittedAt ?? DateTime.now())}',
                            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Two column layout
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _sec('PATIENT', fontBold, font, [
                          _rd('Name', patient.fullName),
                          if (patient.dateOfBirth.isNotEmpty) _rd('DOB', patient.dateOfBirth),
                          if (patient.patientId.isNotEmpty) _rd('ID', patient.patientId),
                        ]),
                        pw.SizedBox(height: 5),
                        _sec('ORDER', fontBold, font, [
                          _rd('Work Order', wo.displayName),
                          _rd('Type', _typeName(wo.templateType)),
                          _rd('Quantity', wo.quantityLabel),
                        ]),
                        pw.SizedBox(height: 5),
                        _sec('SHOE SIZE', fontBold, font, [
                          _rd('Gender', wo.shoeSizeGender),
                          if (wo.sameSizeForBothFeet) ...[
                            _rd('Size', wo.shoeSize),
                            _rd('Width', wo.shoeWidth),
                          ] else ...[
                            _rd('L Size', wo.shoeSizeLeft),
                            _rd('L Width', wo.shoeWidthLeft),
                            _rd('R Size', wo.shoeSizeRight),
                            _rd('R Width', wo.shoeWidthRight),
                          ],
                        ]),
                        pw.SizedBox(height: 5),
                        _sec('NOTES', fontBold, font, [
                          _rd('', wo.specialInstructions.isEmpty
                              ? 'None' : wo.specialInstructions),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Right column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (_hasProductSpecs(wo)) ...[
                          _sec('PRODUCT SPECS', fontBold, font, _productSpecRows(wo)),
                          pw.SizedBox(height: 5),
                        ],
                        if (wo.archModification != 0) ...[
                          _sec('ARCH MOD', fontBold, font, [
                            _rd('', wo.archModification > 0
                                ? '+${wo.archModification}' : '${wo.archModification}'),
                          ]),
                          pw.SizedBox(height: 5),
                        ],
                        if (_hasAccommodations(wo))
                          _sec('ACCOMMODATIONS', fontBold, font, _accommodationRows(wo)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Foot Diagram - full width
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOOT DIAGRAM',
                        style: pw.TextStyle(font: fontBold, fontSize: 8,
                            color: PdfColors.blueGrey700, letterSpacing: 0.5)),
                    pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
                    pw.SizedBox(height: 4),
                    if (leftImg != null || rightImg != null)
                      pw.Row(
                        children: [
                          if (leftImg != null)
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('Left Foot',
                                    style: pw.TextStyle(font: fontBold, fontSize: 8,
                                        color: PdfColors.blueGrey600)),
                                pw.SizedBox(height: 2),
                                pw.Image(leftImg, height: 90, width: 100,
                                    fit: pw.BoxFit.contain),
                              ],
                            ),
                          if (leftImg != null && rightImg != null)
                            pw.SizedBox(width: 12),
                          if (rightImg != null)
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('Right Foot',
                                    style: pw.TextStyle(font: fontBold, fontSize: 8,
                                        color: PdfColors.blueGrey600)),
                                pw.SizedBox(height: 2),
                                pw.Image(rightImg, height: 90, width: 100,
                                    fit: pw.BoxFit.contain),
                              ],
                            ),
                        ],
                      )
                    else
                      pw.Text('No diagram markings added',
                          style: pw.TextStyle(font: font, fontSize: 9,
                              color: PdfColors.blueGrey400)),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      _legendDot(PdfColors.red, 'Pressure', font),
                      pw.SizedBox(width: 8),
                      _legendDot(PdfColors.green, 'Relief', font),
                      pw.SizedBox(width: 8),
                      _legendDot(PdfColors.orange, 'Missing Toe', font),
                      pw.SizedBox(width: 8),
                      _legendDot(PdfColors.grey, 'Note', font),
                    ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sec(String title, pw.Font fontBold, pw.Font font, List<_RD?> rows) {
    final valid = rows.whereType<_RD>().toList();
    if (valid.isEmpty) return pw.SizedBox.shrink();
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: 7,
                  color: PdfColors.blueGrey700, letterSpacing: 0.5)),
          pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
          pw.SizedBox(height: 2),
          ...valid.map((r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: r.label.isEmpty
                    ? pw.Text(r.value,
                        style: pw.TextStyle(font: font, fontSize: 8))
                    : pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 65,
                            child: pw.Text(r.label,
                                style: pw.TextStyle(font: fontBold, fontSize: 8,
                                    color: PdfColors.blueGrey600)),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(r.value,
                                style: pw.TextStyle(font: font, fontSize: 8)),
                          ),
                        ],
                      ),
              )),
        ],
      ),
    );
  }

  static pw.Widget _legendDot(PdfColor color, String label, pw.Font font) {
    return pw.Row(children: [
      pw.Container(
        width: 6, height: 6,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      ),
      pw.SizedBox(width: 3),
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: 7,
          color: PdfColors.blueGrey700)),
    ]);
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
        _rd('Base', wo.baseThickness),
        _rd('Grind', wo.baseGrind),
        if (wo.patientWeight != null) _RD('Weight', '${wo.patientWeight} lbs'),
        _rd('Shell', wo.shellThickness),
        _rd('Shell Len', wo.baseShellLength),
        _rd('Mid Layer', wo.midLayerType),
        if (wo.midLayerType.isNotEmpty && wo.midLayerType != 'None')
          _rd('Mid Thick', wo.midLayerThickness),
        _rd('Top Cover', wo.topCoverType),
        if (wo.topCoverType.isNotEmpty &&
            wo.topCoverType != 'None' &&
            wo.topCoverType != 'P-Cell') ...[
          _rd('Cover Thk', wo.topCoverThickness),
          _rd('Color', wo.topCoverColor),
        ],
      ];

  static bool _hasAccommodations(WorkOrder wo) =>
      wo.heelPost != 'None' || wo.forefootPost != 'None' ||
      wo.heelWedge != 'None' || wo.forefootWedge != 'None' ||
      wo.metPadFoot != 'None' || wo.metBarFoot != 'None' ||
      wo.heelLiftFoot != 'None' || wo.heelCup != 'None';

  static List<_RD?> _accommodationRows(WorkOrder wo) => [
        _rd('Heel Post', wo.heelPost),
        _rd('FF Post', wo.forefootPost),
        _rd('Heel Wedge', wo.heelWedge),
        _rd('FF Wedge', wo.forefootWedge),
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
