import 'work_order_template.dart';

enum WorkOrderStatus {
  draft,
  submitted,
  inProgress,
  completed,
  shipped,
}

enum FootSide {
  left,
  right,
  bilateral,
}

class WorkOrder {
  final String id;
  final String patientId;
  String name;
  TemplateType? templateType;
  WorkOrderStatus status;
  FootSide footSide;
  String productType;
  String materials;
  String specialInstructions;
  String clinicianName;
  String clinicName;
  String clinicianId;
  String clinicId;

  // Quantity
  int quantityLeft;
  int quantityRight;

  // Partial foot
  bool isPartialFootLeft;
  bool isPartialFootRight;
  int toeFillerCountLeft;
  int toeFillerCountRight;

  // ─── Rebound Specs ───────────────────────────────────────────
  String baseThickness;
  String baseGrind;
  String topCoverType;
  String topCoverThickness;
  String topCoverColor;

  // ─── Poly Shell Specs ─────────────────────────────────────────
  double? patientWeight;
  String shellThickness;
  String baseShellLength;
  String midLayerType;
  String midLayerThickness;

  // ─── Arch Modification ───────────────────────────────────────
  int archModification;

  // ─── Accommodations ──────────────────────────────────────────
  String heelPost;
  String forefootPost;
  String heelWedge;
  String forefootWedge;
  String metPadFoot;
  String metPadSize;
  String metBarFoot;
  String metBarSize;
  String heelLiftFoot;
  String heelLiftHeight;
  String heelCup;

  // Dates
  DateTime createdAt;
  DateTime? dateOfService;
  DateTime? expectedDeliveryDate;
  DateTime? submittedAt;
  DateTime? completedAt;

  List<String> scanFiles;

  WorkOrder({
    required this.id,
    required this.patientId,
    this.name = '',
    this.templateType,
    this.status = WorkOrderStatus.draft,
    this.footSide = FootSide.bilateral,
    this.productType = '',
    this.materials = '',
    this.specialInstructions = '',
    this.clinicianName = '',
    this.clinicName = '',
    this.clinicianId = '',
    this.clinicId = '',
    this.quantityLeft = 1,
    this.quantityRight = 1,
    this.isPartialFootLeft = false,
    this.isPartialFootRight = false,
    this.toeFillerCountLeft = 1,
    this.toeFillerCountRight = 1,
    this.baseThickness = '3/16"',
    this.baseGrind = 'None',
    this.topCoverType = 'Microcel Puff',
    this.topCoverThickness = 'None',
    this.topCoverColor = 'None',
    this.patientWeight,
    this.shellThickness = '1/8"',
    this.baseShellLength = 'None',
    this.midLayerType = 'None',
    this.midLayerThickness = 'None',
    this.archModification = 0,
    this.heelPost = 'None',
    this.forefootPost = 'None',
    this.heelWedge = 'None',
    this.forefootWedge = 'None',
    this.metPadFoot = 'None',
    this.metPadSize = 'None',
    this.metBarFoot = 'None',
    this.metBarSize = 'None',
    this.heelLiftFoot = 'None',
    this.heelLiftHeight = '',
    this.heelCup = 'Standard',
    required this.createdAt,
    this.dateOfService,
    this.expectedDeliveryDate,
    this.submittedAt,
    this.completedAt,
    this.scanFiles = const [],
  });

  int get totalQuantity => quantityLeft + quantityRight;

  String get displayName =>
      name.isNotEmpty ? name : (productType.isNotEmpty ? productType : 'Work Order');

  // Auto-suggest shell thickness based on weight
  String get suggestedShellThickness {
    if (patientWeight == null) return '1/8"';
    if (patientWeight! <= 170) return '1/8"';
    if (patientWeight! <= 210) return '5/32"';
    if (patientWeight! <= 250) return '3/16"';
    return '1/4"';
  }

  String get statusLabel {
    switch (status) {
      case WorkOrderStatus.draft:
        return 'Draft';
      case WorkOrderStatus.submitted:
        return 'Submitted';
      case WorkOrderStatus.inProgress:
        return 'In Progress';
      case WorkOrderStatus.completed:
        return 'Completed';
      case WorkOrderStatus.shipped:
        return 'Shipped';
    }
  }

  String get footSideLabel {
    switch (footSide) {
      case FootSide.left:
        return 'Left';
      case FootSide.right:
        return 'Right';
      case FootSide.bilateral:
        return 'Bilateral';
    }
  }

  String get quantityLabel {
    if (quantityLeft == 0 && quantityRight == 0) return 'None';
    if (quantityLeft == 0) return '$quantityRight Right';
    if (quantityRight == 0) return '$quantityLeft Left';
    if (quantityLeft == quantityRight) {
      return '$quantityLeft Pair${quantityLeft > 1 ? 's' : ''}';
    }
    return '$quantityLeft L / $quantityRight R';
  }

  WorkOrder copyWith({String? newId, String? newName}) {
    return WorkOrder(
      id: newId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      name: newName ?? 'Copy of $displayName',
      templateType: templateType,
      status: WorkOrderStatus.draft,
      footSide: footSide,
      productType: productType,
      materials: materials,
      specialInstructions: specialInstructions,
      clinicianName: clinicianName,
      clinicName: clinicName,
      clinicianId: clinicianId,
      clinicId: clinicId,
      quantityLeft: quantityLeft,
      quantityRight: quantityRight,
      isPartialFootLeft: isPartialFootLeft,
      isPartialFootRight: isPartialFootRight,
      toeFillerCountLeft: toeFillerCountLeft,
      toeFillerCountRight: toeFillerCountRight,
      baseThickness: baseThickness,
      baseGrind: baseGrind,
      topCoverType: topCoverType,
      topCoverThickness: topCoverThickness,
      topCoverColor: topCoverColor,
      patientWeight: patientWeight,
      shellThickness: shellThickness,
      baseShellLength: baseShellLength,
      midLayerType: midLayerType,
      midLayerThickness: midLayerThickness,
      archModification: archModification,
      heelPost: heelPost,
      forefootPost: forefootPost,
      heelWedge: heelWedge,
      forefootWedge: forefootWedge,
      metPadFoot: metPadFoot,
      metPadSize: metPadSize,
      metBarFoot: metBarFoot,
      metBarSize: metBarSize,
      heelLiftFoot: heelLiftFoot,
      heelLiftHeight: heelLiftHeight,
      heelCup: heelCup,
      createdAt: DateTime.now(),
      dateOfService: dateOfService,
      expectedDeliveryDate: expectedDeliveryDate,
      scanFiles: List<String>.from(scanFiles),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'name': name,
      'templateType': templateType?.index,
      'status': status.index,
      'footSide': footSide.index,
      'productType': productType,
      'materials': materials,
      'specialInstructions': specialInstructions,
      'clinicianName': clinicianName,
      'clinicName': clinicName,
      'clinicianId': clinicianId,
      'clinicId': clinicId,
      'quantityLeft': quantityLeft,
      'quantityRight': quantityRight,
      'isPartialFootLeft': isPartialFootLeft,
      'isPartialFootRight': isPartialFootRight,
      'toeFillerCountLeft': toeFillerCountLeft,
      'toeFillerCountRight': toeFillerCountRight,
      'baseThickness': baseThickness,
      'baseGrind': baseGrind,
      'topCoverType': topCoverType,
      'topCoverThickness': topCoverThickness,
      'topCoverColor': topCoverColor,
      'patientWeight': patientWeight,
      'shellThickness': shellThickness,
      'baseShellLength': baseShellLength,
      'midLayerType': midLayerType,
      'midLayerThickness': midLayerThickness,
      'archModification': archModification,
      'heelPost': heelPost,
      'forefootPost': forefootPost,
      'heelWedge': heelWedge,
      'forefootWedge': forefootWedge,
      'metPadFoot': metPadFoot,
      'metPadSize': metPadSize,
      'metBarFoot': metBarFoot,
      'metBarSize': metBarSize,
      'heelLiftFoot': heelLiftFoot,
      'heelLiftHeight': heelLiftHeight,
      'heelCup': heelCup,
      'createdAt': createdAt.toIso8601String(),
      'dateOfService': dateOfService?.toIso8601String(),
      'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'scanFiles': scanFiles,
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'],
      patientId: map['patientId'],
      name: map['name'] ?? '',
      templateType: map['templateType'] != null
          ? TemplateType.values[map['templateType']]
          : null,
      status: WorkOrderStatus.values[map['status'] ?? 0],
      footSide: FootSide.values[map['footSide'] ?? 2],
      productType: map['productType'] ?? '',
      materials: map['materials'] ?? '',
      specialInstructions: map['specialInstructions'] ?? '',
      clinicianName: map['clinicianName'] ?? '',
      clinicName: map['clinicName'] ?? '',
      clinicianId: map['clinicianId'] ?? '',
      clinicId: map['clinicId'] as String? ?? '',
      quantityLeft: map['quantityLeft'] ?? 1,
      quantityRight: map['quantityRight'] ?? 1,
      isPartialFootLeft: map['isPartialFootLeft'] ?? false,
      isPartialFootRight: map['isPartialFootRight'] ?? false,
      toeFillerCountLeft: map['toeFillerCountLeft'] ?? 1,
      toeFillerCountRight: map['toeFillerCountRight'] ?? 1,
      baseThickness: map['baseThickness'] ?? '3/16"',
      baseGrind: map['baseGrind'] ?? 'None',
      topCoverType: map['topCoverType'] ?? 'None',
      topCoverThickness: map['topCoverThickness'] ?? 'None',
      topCoverColor: map['topCoverColor'] ?? 'None',
      patientWeight: map['patientWeight']?.toDouble(),
      shellThickness: map['shellThickness'] ?? '1/8"',
      baseShellLength: map['baseShellLength'] ?? 'None',
      midLayerType: map['midLayerType'] ?? 'None',
      midLayerThickness: map['midLayerThickness'] ?? 'None',
      archModification: map['archModification'] ?? 0,
      heelPost: map['heelPost'] ?? 'None',
      forefootPost: map['forefootPost'] ?? 'None',
      heelWedge: map['heelWedge'] ?? 'None',
      forefootWedge: map['forefootWedge'] ?? 'None',
      metPadFoot: map['metPadFoot'] ?? 'None',
      metPadSize: map['metPadSize'] ?? 'None',
      metBarFoot: map['metBarFoot'] ?? 'None',
      metBarSize: map['metBarSize'] ?? 'None',
      heelLiftFoot: map['heelLiftFoot'] ?? 'None',
      heelLiftHeight: map['heelLiftHeight'] ?? '',
      heelCup: map['heelCup'] ?? 'Standard',
      createdAt: DateTime.parse(map['createdAt']),
      dateOfService: map['dateOfService'] != null
          ? DateTime.parse(map['dateOfService'])
          : null,
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? DateTime.parse(map['expectedDeliveryDate'])
          : null,
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      scanFiles: List<String>.from(map['scanFiles'] ?? []),
    );
  }
}