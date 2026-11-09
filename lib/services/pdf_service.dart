import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/work_order.dart';
import '../models/patient.dart';
import '../models/work_order_template.dart';
import '../screens/foot_diagram_widget.dart';

/// Black-and-white-first lab sheet, US Letter.
/// Black text, thin dark borders, bold values, bundled Roboto font.
/// Foot diagram keeps its colours but every mark also carries a letter
/// (P / R / X) or a note number so it still reads in grayscale.
class PdfService {
  static final PdfColor _ink = PdfColors.black;
  static final PdfColor _label = PdfColor.fromInt(0xFF2B2B2B);

  static Future<Uint8List> generateWorkOrderPdf({
    required WorkOrder wo,
    required Patient patient,
    Uint8List? leftDiagramImage,
    Uint8List? rightDiagramImage,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    pw.ImageProvider? leftImg;
    pw.ImageProvider? rightImg;
    if (leftDiagramImage != null) leftImg = pw.MemoryImage(leftDiagramImage);
    if (rightDiagramImage != null) rightImg = pw.MemoryImage(rightDiagramImage);

    final diagram = DiagramData.fromJsonString(wo.diagramData);

    pw.TextStyle reg(double size, {PdfColor? color}) =>
        pw.TextStyle(font: font, fontSize: size, color: color ?? _ink);
    pw.TextStyle bld(double size, {PdfColor? color}) =>
        pw.TextStyle(font: bold, fontSize: size, color: color ?? _ink);

    pw.Widget caps(String s) =>
        pw.Text(s.toUpperCase(), style: bld(8.5).copyWith(letterSpacing: 0.4));

    pw.Widget box({required pw.Widget child, double pad = 10, double width = 0.8}) =>
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(pad),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: width)),
          child: child,
        );

    pw.Widget gap([double h = 8]) => pw.SizedBox(height: h);

    // ---------- header ----------
    final due = wo.expectedDeliveryDate;
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Text('LAB ORDER', style: bld(24)),
                    if (wo.submissionCount > 1) ...[
                      pw.SizedBox(width: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _ink, width: 1.2)),
                        child: pw.Text('RESUBMISSION #${wo.submissionCount - 1}',
                            style: bld(9)),
                      ),
                    ],
                  ]),
                  pw.SizedBox(height: 4),
                  if (wo.clinicName.isNotEmpty)
                    pw.Text(wo.clinicName, style: reg(11)),
                  if (wo.clinicianName.isNotEmpty)
                    pw.Text('Clinician: ${wo.clinicianName}', style: reg(10)),
                ],
              ),
            ),
            // Lab number: fillable field
            pw.Container(
              width: 130,
              height: 56,
              padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  caps('Lab #'),
                  pw.SizedBox(height: 3),
                  pw.TextField(
                    name: 'lab_number',
                    width: 114,
                    height: 34,
                    maxLength: 12,
                    textStyle: bld(20),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 124,
              height: 56,
              padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  caps('Due'),
                  pw.SizedBox(height: 3),
                  pw.Text(due == null ? '-' : _fmtDate(due), style: bld(17)),
                  if (wo.dateOfService != null)
                    pw.Text('Service ${_fmtDate(wo.dateOfService)}',
                        style: reg(8.5, color: _label)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.2, color: _ink),
      ],
    );

    // ---------- patient ----------
    final patientBox = box(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              caps('Patient'),
              pw.SizedBox(height: 4),
              pw.Text(patient.fullName, style: bld(15)),
            ]),
          ),
          if (patient.patientId.isNotEmpty)
            pw.Expanded(
              flex: 3,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                caps('Patient ID'),
                pw.SizedBox(height: 4),
                pw.Text(patient.patientId, style: bld(13)),
              ]),
            ),
          pw.Expanded(
            flex: 4,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              caps('Shoe size'),
              pw.SizedBox(height: 4),
              pw.Text(_shoeSize(wo), style: bld(13)),
            ]),
          ),
        ],
      ),
    );

    // ---------- product banner + per-foot line ----------
    final banner = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: _ink,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_bannerName(wo).toUpperCase(),
              style: bld(15, color: PdfColors.white)),
          pw.Text(wo.quantityLabel, style: bld(12, color: PdfColors.white)),
        ],
      ),
    );
    final feetLine = _feetLine(wo);
    final feetBox = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
          border: pw.Border(
              left: pw.BorderSide(color: _ink, width: 0.8),
              right: pw.BorderSide(color: _ink, width: 0.8),
              bottom: pw.BorderSide(color: _ink, width: 0.8))),
      child: pw.Text(feetLine, style: bld(11)),
    );

    // ---------- specs + accommodations ----------
    final specs = _productSpecRows(wo);
    final accs = _accommodationRows(wo);
    pw.Widget rowsCol(String title, List<_RD> rows, {bool rule = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: rule
            ? pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: _ink, width: 0.6)))
            : null,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            caps(title),
            pw.SizedBox(height: 5),
            if (rows.isEmpty) pw.Text('None', style: bld(11)),
            ...rows.map((r) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 82, child: pw.Text(r.label, style: reg(9, color: _label))),
                      pw.Expanded(child: pw.Text(r.value, style: bld(11))),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    final specsBox = pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8)),
      child: pw.SizedBox(
        height: 38 + (specs.length > accs.length ? specs.length : accs.length).clamp(1, 20).toDouble() * 16.5,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: rowsCol('Product specs', specs, rule: true)),
            pw.Expanded(child: rowsCol('Accommodations', accs)),
          ],
        ),
      ),
    );

    // ---------- notes ----------
    pw.Widget notesBox(String title, String body) => box(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              caps(title),
              pw.SizedBox(height: 5),
              pw.Text(body, style: reg(10.5)),
            ],
          ),
        );
    final labNotes = wo.specialInstructions.trim();
    final clinNotes = patient.notes.trim();

    // ---------- diagram ----------
    pw.Widget footCol(String label, pw.ImageProvider img) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(img, height: 150, width: 100, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 2),
            pw.Text(label.toUpperCase(), style: bld(9)),
          ],
        );

    pw.Widget legendItem(PdfColor fill, String ch, PdfColor chColor, String label) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.Container(
              width: 13,
              height: 13,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                  color: fill,
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _ink, width: 0.8)),
              child: pw.Text(ch, style: bld(8, color: chColor)),
            ),
            pw.SizedBox(width: 6),
            pw.Text(label, style: reg(9.5)),
          ]),
        );

    final noteLines = <String>[];
    void collectNotes(String foot, List<FootMark> marks) {
      var n = 0;
      for (final m in marks) {
        if (m.type != MarkType.general) continue;
        n++;
        final t = (m.note ?? '').trim();
        if (t.isNotEmpty) noteLines.add('$foot $n   $t');
      }
    }
    collectNotes('Right', diagram.rightMarks);
    collectNotes('Left', diagram.leftMarks);

    final diagramBox = box(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          caps('Foot diagram'),
          pw.SizedBox(height: 6),
          if (leftImg != null || rightImg != null)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (rightImg != null) footCol('Right', rightImg),
                if (leftImg != null && rightImg != null) pw.SizedBox(width: 40),
                if (leftImg != null) footCol('Left', leftImg),
                pw.SizedBox(width: 40),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    legendItem(PdfColors.red, 'P', PdfColors.white, 'Pressure'),
                    legendItem(PdfColors.green, 'R', PdfColors.black, 'Relief'),
                    legendItem(PdfColors.orange, 'X', PdfColors.black, 'Missing toe'),
                    legendItem(PdfColors.white, '1', PdfColors.black, 'Note (numbered)'),
                  ],
                ),
              ],
            )
          else
            pw.Text('No diagram markings added', style: reg(10)),
          if (noteLines.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            ...noteLines.map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.5),
                  child: pw.Text(l, style: reg(9.5)),
                )),
          ],
        ],
      ),
    );

    final submitted = wo.submissionCount <= 1
        ? 'Submitted ${_fmtDateTime(wo.submittedAt ?? DateTime.now())}'
        : 'Originally ${_fmtDateTime(wo.originalSubmittedAt ?? wo.submittedAt ?? DateTime.now())}'
            '  ·  Resubmitted ${_fmtDateTime(wo.submittedAt ?? DateTime.now())}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 30),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _ink, width: 0.6))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}   ·   $submitted',
                  style: reg(8.5, color: _label)),
            ],
          ),
        ),
        // Separate top-level widgets so content can flow to a 2nd page
        // instead of failing when something is too tall.
        build: (context) => [
          header,
          gap(10),
          patientBox,
          gap(),
          banner,
          feetBox,
          gap(),
          specsBox,
          gap(),
          notesBox('Notes for the lab', labNotes.isEmpty ? 'None' : labNotes),
          if (clinNotes.isNotEmpty) ...[
            gap(),
            notesBox('Clinical notes', clinNotes),
          ],
          gap(),
          diagramBox,
        ],
      ),
    );

    return pdf.save();
  }

  // ---------- helpers ----------

  static String _shoeSize(WorkOrder wo) {
    String part(String size, String width) =>
        [size, width].where((s) => s.isNotEmpty && s != 'None').join(' ');
    final g = wo.shoeSizeGender;
    if (wo.sameSizeForBothFeet) {
      final s = part(wo.shoeSize, wo.shoeWidth);
      return s.isEmpty ? '-' : '${g.isEmpty ? '' : '$g  '}$s';
    }
    final l = part(wo.shoeSizeLeft, wo.shoeWidthLeft);
    final r = part(wo.shoeSizeRight, wo.shoeWidthRight);
    return '${g.isEmpty ? '' : '$g  '}L ${l.isEmpty ? '-' : l}   R ${r.isEmpty ? '-' : r}';
  }

  static String _footProduct(WorkOrder wo, bool left) {
    final partial = wo.templateType == TemplateType.partialFoot ||
        (left ? wo.isPartialFootLeft : wo.isPartialFootRight);
    if (!partial) return _typeName(wo.templateType == TemplateType.partialFoot
        ? TemplateType.rebound : wo.templateType);
    final n = left ? wo.toeFillerCountLeft : wo.toeFillerCountRight;
    return n > 0
        ? 'Partial Foot ($n toe filler${n > 1 ? "s" : ""})'
        : 'Partial Foot';
  }

  static String _feetLine(WorkOrder wo) {
    final parts = <String>[];
    if (wo.quantityLeft > 0) parts.add('Left: ${_footProduct(wo, true)}');
    if (wo.quantityRight > 0) parts.add('Right: ${_footProduct(wo, false)}');
    return parts.isEmpty ? 'Quantity not set' : parts.join('      ');
  }

  static _RD? _rd(String label, String value) {
    if (value.isEmpty || value == 'None') return null;
    return _RD(label, value);
  }

  static List<_RD> _clean(List<_RD?> rows) => rows.whereType<_RD>().toList();

  static List<_RD> _productSpecRows(WorkOrder wo) {
    final isPolyShell = wo.templateType == TemplateType.polyShell;
    return _clean([
      if (!isPolyShell) _rd('Base', wo.baseThickness),
      if (!isPolyShell) _rd('Grind', wo.baseGrind),
      if (isPolyShell) _rd('Shell thk', wo.shellThickness),
      if (isPolyShell) _rd('Shell len', wo.baseShellLength),
      if (isPolyShell && wo.patientWeight != null) _RD('Weight', '${wo.patientWeight} lbs'),
      if (isPolyShell) _rd('Mid layer', wo.midLayerType),
      if (isPolyShell && wo.midLayerType.isNotEmpty && wo.midLayerType != 'None')
        _rd('Mid thk', wo.midLayerThickness),
      _rd('Top cover', wo.topCoverType),
      if (wo.topCoverType.isNotEmpty &&
          wo.topCoverType != 'None' &&
          wo.topCoverType != 'P-Cell') ...[
        _rd('Cover thk', wo.topCoverThickness),
        _rd('Color', wo.topCoverColor),
      ],
      if (wo.archModification != 0)
        _RD('Arch mod',
            wo.archModification > 0 ? '+${wo.archModification}' : '${wo.archModification}'),
    ]);
  }

  static List<_RD> _accommodationRows(WorkOrder wo) => _clean([
        _rd('Heel post', wo.heelPost),
        _rd('FF post', wo.forefootPost),
        _rd('Heel wedge', wo.heelWedge),
        _rd('FF wedge', wo.forefootWedge),
        _rd('Met pad', wo.metPadFoot != 'None' ? '${wo.metPadFoot} (${wo.metPadSize})' : ''),
        _rd('Met bar', wo.metBarFoot != 'None' ? '${wo.metBarFoot} (${wo.metBarSize})' : ''),
        _rd(
            'Heel lift',
            wo.heelLiftFoot != 'None'
                ? '${wo.heelLiftFoot}${wo.heelLiftHeight.isNotEmpty ? ' - ${wo.heelLiftHeight}' : ''}'
                : ''),
        _rd('Heel cup', wo.heelCup),
      ]);

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day/${d.year}';
  }

  static String _fmtDateTime(DateTime? d) {
    if (d == null) return '';
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${_fmtDate(d)} $hour:$min $ampm';
  }

  static String _bannerName(WorkOrder wo) {
    if (wo.templateType == null) return 'Unknown';
    if (wo.templateType == TemplateType.polyShell) return 'Poly Shell';
    final isPT = wo.templateType == TemplateType.partialFoot;
    final partials = <bool>[
      if (wo.quantityLeft > 0) isPT || wo.isPartialFootLeft,
      if (wo.quantityRight > 0) isPT || wo.isPartialFootRight,
    ];
    if (partials.isNotEmpty && partials.every((p) => p)) return 'Partial Foot';
    return 'Rebound';
  }

  static String _typeName(TemplateType? type) {
    switch (type) {
      case TemplateType.rebound:
        return 'Rebound';
      case TemplateType.polyShell:
        return 'Poly Shell';
      case TemplateType.partialFoot:
        return 'Partial Foot';
      case null:
        return 'Unknown';
    }
  }
}

class _RD {
  final String label;
  final String value;
  _RD(this.label, this.value);
}
