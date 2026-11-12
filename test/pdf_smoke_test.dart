import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orthoscan/models/patient.dart';
import 'package:orthoscan/models/work_order.dart';
import 'package:orthoscan/models/work_order_template.dart';
import 'package:orthoscan/screens/foot_diagram_widget.dart';
import 'package:orthoscan/services/pdf_service.dart';

Patient _patient({String first = 'Test', String last = 'Patient'}) =>
    Patient(id: 'p1', firstName: first, lastName: last, createdAt: DateTime(2026, 11, 1));

WorkOrder _wo(
  TemplateType? type, {
  int ql = 1,
  int qr = 1,
  bool pl = false,
  bool pr = false,
  String notes = '',
  bool accommodations = false,
  int submissions = 0,
  bool dates = true,
  String diagram = '',
  String clinic = 'Compass Orthotics and Prosthetics',
}) {
  final wo = WorkOrder(
    id: 'w${type?.index}_$ql$qr$pl$pr',
    patientId: 'p1',
    templateType: type,
    createdAt: DateTime(2026, 11, 2),
  );
  wo.name = 'x';
  wo.clinicName = clinic;
  wo.clinicianName = clinic.isEmpty ? '' : 'Chase Test';
  wo.quantityLeft = ql;
  wo.quantityRight = qr;
  wo.isPartialFootLeft = pl;
  wo.isPartialFootRight = pr;
  wo.toeFillerCountLeft = pl ? 2 : 0;
  wo.toeFillerCountRight = pr ? 1 : 0;
  wo.specialInstructions = notes;
  wo.shoeSize = '10';
  wo.shoeSizeLeft = '10';
  wo.shoeSizeRight = '10.5';
  wo.sameSizeForBothFeet = false;
  wo.diagramData = diagram;
  if (dates) {
    wo.dateOfService = DateTime(2026, 11, 12);
    wo.expectedDeliveryDate = DateTime(2026, 11, 26);
  }
  if (accommodations) {
    wo.heelPost = 'Extrinsic';
    wo.forefootPost = 'Lateral - B/L';
    wo.heelWedge = 'Medial - B/L';
    wo.forefootWedge = 'Lateral - B/L';
    wo.metPadFoot = 'B/L';
    wo.metPadSize = 'M';
    wo.heelLiftFoot = 'Left';
    wo.heelLiftHeight = '1/4"';
    wo.heelCup = 'Deep';
  }
  if (submissions > 0) {
    wo.submissionCount = submissions;
    wo.originalSubmittedAt = DateTime(2026, 11, 3, 9, 30);
    wo.submittedAt = DateTime(2026, 11, 10, 14, 5);
  }
  return wo;
}

String _busyDiagram() {
  final marks = <FootMark>[
    for (var i = 0; i < 12; i++)
      FootMark(
        position: Offset(0.2 + (i % 4) * 0.15, 0.15 + (i ~/ 4) * 0.25),
        type: MarkType.values[i % MarkType.values.length],
        note: i % 4 == 3 ? 'Note number $i about the callus under the metatarsal head' : null,
      ),
  ];
  final paths = <DrawPath>[
    DrawPath(
      points: [for (var i = 0; i < 40; i++) Offset(0.1 + i * 0.015, 0.3 + (i % 5) * 0.02)],
      color: Colors.blue,
    ),
  ];
  return DiagramData(
          leftMarks: marks, leftPaths: paths, rightMarks: marks, rightPaths: paths)
      .toJsonString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> check(String label, WorkOrder wo, {Patient? patient}) async {
    final bytes = await PdfService.generateWorkOrderPdf(
        wo: wo, patient: patient ?? _patient());
    expect(bytes.length, greaterThan(2000), reason: label);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: label);
  }

  final longNotes = List.generate(
      60, (i) => 'Line $i: patient reports pain at the first MTP joint when walking uphill.').join('\n');

  final cases = <String, WorkOrder Function()>{
    'rebound pair': () => _wo(TemplateType.rebound),
    'poly pair': () => _wo(TemplateType.polyShell),
    'partial foot type': () => _wo(TemplateType.partialFoot, pl: true, pr: true),
    'rebound mixed partial': () => _wo(TemplateType.rebound, pl: true),
    'rebound both partial flags': () => _wo(TemplateType.rebound, pl: true, pr: true),
    'rebound left only': () => _wo(TemplateType.rebound, qr: 0),
    'rebound right only': () => _wo(TemplateType.rebound, ql: 0),
    'poly left only': () => _wo(TemplateType.polyShell, qr: 0),
    'qty 3 and 2': () => _wo(TemplateType.rebound, ql: 3, qr: 2),
    'null type': () => _wo(null),
    'no dates': () => _wo(TemplateType.rebound, dates: false),
    'no clinic': () => _wo(TemplateType.rebound, clinic: ''),
    'resubmission': () => _wo(TemplateType.rebound, submissions: 2),
    'all accommodations rebound': () => _wo(TemplateType.rebound, accommodations: true),
    'all accommodations poly': () => _wo(TemplateType.polyShell, accommodations: true),
    'very long notes': () => _wo(TemplateType.rebound, notes: longNotes, accommodations: true),
    'busy diagram': () => _wo(TemplateType.polyShell, diagram: _busyDiagram(), accommodations: true),
    'long notes + busy diagram + resub': () => _wo(TemplateType.polyShell,
        notes: longNotes, diagram: _busyDiagram(), accommodations: true, submissions: 3),
  };

  cases.forEach((label, make) {
    test('PDF builds: $label', () async => check(label, make()));
  });

  test('PDF builds: very long patient name', () async {
    await check('long name', _wo(TemplateType.rebound),
        patient: _patient(first: 'Bartholomew-Maximilian' * 2, last: 'Featherstonehaugh-Cholmondeley' * 2));
  });

  test('DiagramData JSON round trip keeps marks and paths', () {
    final d = DiagramData.fromJsonString(_busyDiagram());
    expect(d.leftMarks.length, 12);
    expect(d.rightPaths.length, 1);
    expect(DiagramData.fromJsonString('').isEmpty, true);
    expect(DiagramData.fromJsonString('not json').isEmpty, true);
  });
}
