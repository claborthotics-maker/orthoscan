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

  // Quantity
  int quantityLeft;
  int quantityRight;

  // Partial foot
  bool isPartialFootLeft;
  bool isPartialFootRight;
  int toeFillerCountLeft;
  int toeFillerCountRight;

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
    this.quantityLeft = 1,
    this.quantityRight = 1,
    this.isPartialFootLeft = false,
    this.isPartialFootRight = false,
    this.toeFillerCountLeft = 1,
    this.toeFillerCountRight = 1,
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
      quantityLeft: quantityLeft,
      quantityRight: quantityRight,
      isPartialFootLeft: isPartialFootLeft,
      isPartialFootRight: isPartialFootRight,
      toeFillerCountLeft: toeFillerCountLeft,
      toeFillerCountRight: toeFillerCountRight,
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
      'quantityLeft': quantityLeft,
      'quantityRight': quantityRight,
      'isPartialFootLeft': isPartialFootLeft,
      'isPartialFootRight': isPartialFootRight,
      'toeFillerCountLeft': toeFillerCountLeft,
      'toeFillerCountRight': toeFillerCountRight,
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
      quantityLeft: map['quantityLeft'] ?? 1,
      quantityRight: map['quantityRight'] ?? 1,
      isPartialFootLeft: map['isPartialFootLeft'] ?? false,
      isPartialFootRight: map['isPartialFootRight'] ?? false,
      toeFillerCountLeft: map['toeFillerCountLeft'] ?? 1,
      toeFillerCountRight: map['toeFillerCountRight'] ?? 1,
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