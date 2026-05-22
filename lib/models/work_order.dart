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
  WorkOrderStatus status;
  FootSide footSide;
  String productType;
  String materials;
  String specialInstructions;
  String clinicianName;
  String clinicName;
  DateTime createdAt;
  DateTime? submittedAt;
  DateTime? completedAt;
  List<String> scanFiles;

  WorkOrder({
    required this.id,
    required this.patientId,
    this.status = WorkOrderStatus.draft,
    this.footSide = FootSide.bilateral,
    this.productType = '',
    this.materials = '',
    this.specialInstructions = '',
    this.clinicianName = '',
    this.clinicName = '',
    required this.createdAt,
    this.submittedAt,
    this.completedAt,
    this.scanFiles = const [],
  });

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'status': status.index,
      'footSide': footSide.index,
      'productType': productType,
      'materials': materials,
      'specialInstructions': specialInstructions,
      'clinicianName': clinicianName,
      'clinicName': clinicName,
      'createdAt': createdAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'scanFiles': scanFiles,
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'],
      patientId: map['patientId'],
      status: WorkOrderStatus.values[map['status'] ?? 0],
      footSide: FootSide.values[map['footSide'] ?? 2],
      productType: map['productType'] ?? '',
      materials: map['materials'] ?? '',
      specialInstructions: map['specialInstructions'] ?? '',
      clinicianName: map['clinicianName'] ?? '',
      clinicName: map['clinicName'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
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