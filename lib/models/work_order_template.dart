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

  // Import FootSide from work_order.dart
  WorkOrder toWorkOrder({
    required String patientId,
    required String clinicianName,
  }) {
    return WorkOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      name: name,
      templateType: templateType,
      createdAt: DateTime.now(),
      productType: name,
      materials: topCover,
      specialInstructions: specialInstructions,
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

// Need to import WorkOrder after defining TemplateType

// ─── Default Templates ────────────────────────────────────────────────────────
class DefaultTemplates {
  static List<WorkOrderTemplate> getAll() {
    return [
      ..._reboundTemplates(),
      ..._polyShellTemplates(),
      ..._partialFootTemplates(),
    ];
  }

  static List<WorkOrderTemplate> _reboundTemplates() {
    return [
      WorkOrderTemplate(
        id: 'default_rebound_running',
        name: 'Running Rebound',
        templateType: TemplateType.rebound,
        description: 'Athletic full length rebound for running shoes',
        baseThickness: '3/16"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 1,
        heelCup: 'Deep',
        specialInstructions: 'Athletic use — running shoes',
      ),
      WorkOrderTemplate(
        id: 'default_rebound_dress',
        name: 'Dress Shoe Rebound',
        templateType: TemplateType.rebound,
        description: 'Low profile rebound for dress shoes',
        baseThickness: '3/16"',
        topCover: 'Microfiber Suede',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
        specialInstructions: 'Low profile for dress shoe fit',
      ),
      WorkOrderTemplate(
        id: 'default_rebound_casual',
        name: 'Casual/Walking Rebound',
        templateType: TemplateType.rebound,
        description: 'Everyday walking rebound',
        baseThickness: '3/16"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
        specialInstructions: 'General everyday use',
      ),
      WorkOrderTemplate(
        id: 'default_rebound_diabetic',
        name: 'Diabetic Rebound',
        templateType: TemplateType.rebound,
        description: 'Pressure relieving rebound for diabetic patients',
        baseThickness: '1/4"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'None',
        heelPost: 'None',
        specialInstructions:
            'Diabetic — pressure relief priority. No sharp edges.',
      ),
    ];
  }

  static List<WorkOrderTemplate> _polyShellTemplates() {
    return [
      WorkOrderTemplate(
        id: 'default_poly_athletic',
        name: 'Athletic Poly Shell',
        templateType: TemplateType.polyShell,
        description: '3D printed shell for athletic footwear',
        shellThickness: '1/8"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 1,
        heelCup: 'Deep',
        specialInstructions: 'Athletic use — firm shell',
      ),
      WorkOrderTemplate(
        id: 'default_poly_dress',
        name: 'Dress Shoe Poly Shell',
        templateType: TemplateType.polyShell,
        description: 'Slim 3D printed shell for dress shoes',
        shellThickness: '1/8"',
        topCover: 'Microfiber Suede',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
        specialInstructions: 'Slim profile for dress shoe fit',
      ),
      WorkOrderTemplate(
        id: 'default_poly_casual',
        name: 'Casual/Walking Poly Shell',
        templateType: TemplateType.polyShell,
        description: 'Everyday 3D printed shell',
        shellThickness: '3/32"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'Standard',
        specialInstructions: 'General everyday use',
      ),
      WorkOrderTemplate(
        id: 'default_poly_diabetic',
        name: 'Diabetic Poly Shell',
        templateType: TemplateType.polyShell,
        description: 'Pressure relieving shell for diabetic patients',
        shellThickness: '1/8"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'None',
        heelPost: 'None',
        specialInstructions:
            'Diabetic — pressure relief priority. No sharp edges.',
      ),
    ];
  }

  static List<WorkOrderTemplate> _partialFootTemplates() {
    return [
      WorkOrderTemplate(
        id: 'default_partial_standard',
        name: 'Standard Partial Foot',
        templateType: TemplateType.partialFoot,
        description: 'Rebound with toe filler for partial foot',
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
        specialInstructions: 'Partial foot — include toe filler',
      ),
      WorkOrderTemplate(
        id: 'default_partial_diabetic',
        name: 'Diabetic Partial Foot',
        templateType: TemplateType.partialFoot,
        description: 'Diabetic rebound with toe filler',
        baseThickness: '1/4"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/8"',
        topCoverColor: 'Blue',
        archModification: 0,
        heelCup: 'None',
        heelPost: 'None',
        isPartialFootLeft: true,
        isPartialFootRight: true,
        toeFillerCountLeft: 1,
        toeFillerCountRight: 1,
        specialInstructions:
            'Diabetic partial foot — pressure relief priority. No sharp edges.',
      ),
      WorkOrderTemplate(
        id: 'default_partial_athletic',
        name: 'Athletic Partial Foot',
        templateType: TemplateType.partialFoot,
        description: 'Athletic rebound with toe filler',
        baseThickness: '3/16"',
        topCover: 'Microcel Puff',
        topCoverThickness: '1/16"',
        topCoverColor: 'Blue',
        archModification: 1,
        heelCup: 'Deep',
        isPartialFootLeft: true,
        isPartialFootRight: true,
        toeFillerCountLeft: 1,
        toeFillerCountRight: 1,
        specialInstructions:
            'Athletic partial foot — include toe filler',
      ),
    ];
  }
}