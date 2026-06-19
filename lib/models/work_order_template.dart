import 'work_order.dart';
enum TemplateType {
  rebound,
  polyShell,
  partialFoot,
}

class WorkOrderTemplate {
  final String id;
  String name;
  TemplateType templateType;
  bool isCustom;
  String clinicName;

  // Product specs
  String baseThickness;
  String topCover;
  String topCoverThickness;
  String topCoverColor;
  String shellThickness;

  // Arch modification
  int archModification;

  // Accommodations
  String heelPost;
  String forefootPost;
  String heelWedge;
  String forefootWedge;
  String metPad;
  String metBar;
  String heelLift;
  String heelCup;

  // Partial foot
  bool isPartialFootLeft;
  bool isPartialFootRight;
  int toeFillerCountLeft;
  int toeFillerCountRight;

  // Notes
  String specialInstructions;
  String description;

  WorkOrderTemplate({
    required this.id,
    required this.name,
    required this.templateType,
    this.isCustom = false,
    this.clinicName = '',
    this.baseThickness = '3/16"',
    this.topCover = 'Microcel Puff',
    this.topCoverThickness = '1/16"',
    this.topCoverColor = 'Blue',
    this.shellThickness = '1/8"',
    this.archModification = 0,
    this.heelPost = 'None',
    this.forefootPost = '',
    this.heelWedge = '',
    this.forefootWedge = '',
    this.metPad = '',
    this.metBar = '',
    this.heelLift = '',
    this.heelCup = 'None',
    this.isPartialFootLeft = false,
    this.isPartialFootRight = false,
    this.toeFillerCountLeft = 1,
    this.toeFillerCountRight = 1,
    this.specialInstructions = '',
    this.description = '',
  });

  WorkOrder toWorkOrder({
    required String patientId,
    required String clinicianName,
  }) {
    return WorkOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      name: name,
      lastTemplateName: name,
      templateType: templateType,
      createdAt: DateTime.now(),
      productType: name,
      materials: topCover,
      specialInstructions: '',
      clinicianName: clinicianName,
      clinicName: clinicName,
      isPartialFootLeft: isPartialFootLeft,
      isPartialFootRight: isPartialFootRight,
      toeFillerCountLeft: toeFillerCountLeft,
      toeFillerCountRight: toeFillerCountRight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'templateType': templateType.index,
      'isCustom': isCustom,
      'clinicName': clinicName,
      'baseThickness': baseThickness,
      'topCover': topCover,
      'topCoverThickness': topCoverThickness,
      'topCoverColor': topCoverColor,
      'shellThickness': shellThickness,
      'archModification': archModification,
      'heelPost': heelPost,
      'forefootPost': forefootPost,
      'heelWedge': heelWedge,
      'forefootWedge': forefootWedge,
      'metPad': metPad,
      'metBar': metBar,
      'heelLift': heelLift,
      'heelCup': heelCup,
      'isPartialFootLeft': isPartialFootLeft,
      'isPartialFootRight': isPartialFootRight,
      'toeFillerCountLeft': toeFillerCountLeft,
      'toeFillerCountRight': toeFillerCountRight,
      'specialInstructions': specialInstructions,
      'description': description,
    };
  }

  factory WorkOrderTemplate.fromMap(Map<String, dynamic> map) {
    return WorkOrderTemplate(
      id: map['id'],
      name: map['name'],
      templateType: TemplateType.values[map['templateType']],
      isCustom: map['isCustom'] ?? false,
      clinicName: map['clinicName'] ?? '',
      baseThickness: map['baseThickness'] ?? '3/16"',
      topCover: map['topCover'] ?? 'Microcel Puff',
      topCoverThickness: map['topCoverThickness'] ?? '1/16"',
      topCoverColor: map['topCoverColor'] ?? 'Blue',
      shellThickness: map['shellThickness'] ?? '1/8"',
      archModification: map['archModification'] ?? 0,
      heelPost: map['heelPost'] ?? 'None',
      forefootPost: map['forefootPost'] ?? '',
      heelWedge: map['heelWedge'] ?? '',
      forefootWedge: map['forefootWedge'] ?? '',
      metPad: map['metPad'] ?? '',
      metBar: map['metBar'] ?? '',
      heelLift: map['heelLift'] ?? '',
      heelCup: map['heelCup'] ?? 'None',
      isPartialFootLeft: map['isPartialFootLeft'] ?? false,
      isPartialFootRight: map['isPartialFootRight'] ?? false,
      toeFillerCountLeft: map['toeFillerCountLeft'] ?? 1,
      toeFillerCountRight: map['toeFillerCountRight'] ?? 1,
      specialInstructions: map['specialInstructions'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

// ─── Default Templates ─────────────────────────────────────────────────────
class DefaultTemplates {
  static List<WorkOrderTemplate> getAll() {
    return [
      WorkOrderTemplate(
        id: 'default_rebound',
        name: 'Rebound',
        templateType: TemplateType.rebound,
        description: 'Standard rebound orthotic',
        baseThickness: '3/16"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
      ),
      WorkOrderTemplate(
        id: 'default_poly_shell',
        name: 'Poly Shell',
        templateType: TemplateType.polyShell,
        description: 'Standard poly shell orthotic',
        shellThickness: '1/8"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
      ),
      WorkOrderTemplate(
        id: 'default_partial_foot',
        name: 'Partial Foot',
        templateType: TemplateType.partialFoot,
        description: 'Standard partial foot rebound with toe filler',
        baseThickness: '3/16"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
        isPartialFootLeft: true,
        isPartialFootRight: true,
        toeFillerCountLeft: 1,
        toeFillerCountRight: 1,
      ),
    ];
  }

  static String defaultNameForType(TemplateType type) {
    final all = getAll();
    try {
      return all.firstWhere((t) => t.templateType == type).name;
    } catch (_) {
      return '';
    }
  }
}

