import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../models/clinician.dart';
import '../services/clinician_service.dart';
import '../services/database_service.dart';
import 'work_order_widgets.dart';
import 'foot_diagram_widget.dart';
import 'work_order_confirmation_screen.dart';

class WorkOrderScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final Patient patient;
  final Future<void> Function(WorkOrder) onSave;

  const WorkOrderScreen({
    super.key,
    required this.workOrder,
    required this.patient,
    required this.onSave,
  });

  @override
  State<WorkOrderScreen> createState() => _WorkOrderScreenState();
}

class _WorkOrderScreenState extends State<WorkOrderScreen> {
  final _clinicianService = ClinicianService();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _weightController = TextEditingController();
  final _heelLiftHeightController = TextEditingController();
  final _customShoeWidthController = TextEditingController();
  final _customShoeWidthLeftController = TextEditingController();
  final _customShoeWidthRightController = TextEditingController();

  bool _clinicianExpanded = false;
  bool _patientExpanded = false;
  bool _orthoticTypeExpanded = false;
  bool _datesExpanded = false;
  bool _shoeSizeExpanded = false;
  bool _quantityExpanded = false;
  bool _partialFootExpanded = false;
  bool _productSpecsExpanded = false;
  bool _archModExpanded = false;
  bool _accommodationsExpanded = false;
  bool _footDiagramExpanded = false;
  bool _notesExpanded = false;

  late WorkOrderStatus _status;
  late FootSide _footSide;
  late TemplateType? _orthoticType;
  late int _quantityLeft;
  late int _quantityRight;
  late bool _isPartialFootLeft;
  late bool _isPartialFootRight;
  late int _toeFillerCountLeft;
  late int _toeFillerCountRight;
  late String _baseThickness;
  late String _baseGrind;
  late String _topCoverType;
  late String _topCoverThickness;
  late String _topCoverColor;
  late String _shellThickness;
  late String _baseShellLength;
  late String _midLayerType;
  late String _midLayerThickness;
  late int _archModification;
  late String _heelPost;
  late String _forefootPost;
  late String _heelWedge;
  late String _forefootWedge;
  late String _metPadFoot;
  late String _metPadSize;
  late String _metBarFoot;
  late String _metBarSize;
  late String _heelLiftFoot;
  late String _heelCup;
  late String _shoeSize;
  late String _shoeSizeGender;
  late String _shoeWidth;
  late bool _sameSizeForBothFeet;
  late String _shoeSizeLeft;
  late String _shoeWidthLeft;
  late String _shoeSizeRight;
  late String _shoeWidthRight;

  DateTime? _dateOfService;
  DateTime? _expectedDeliveryDate;
  Clinician? _selectedClinician;
  bool _isDrawMode = false;
  final _leftDiagramKey = GlobalKey();
  final _rightDiagramKey = GlobalKey();
  String _diagramData = '';

  static const _maleSizes = [
    '6', '6.5', '7', '7.5', '8', '8.5', '9', '9.5',
    '10', '10.5', '11', '11.5', '12', '12.5', '13',
    '13.5', '14', '15', '16', '17',
  ];
  static const _femaleSizes = [
    '4', '4.5', '5', '5.5', '6', '6.5', '7', '7.5',
    '8', '8.5', '9', '9.5', '10', '10.5', '11',
    '11.5', '12', '13', '14', '15',
  ];

  List<String> _shoeSizes(String gender) =>
      gender == 'Female' ? _femaleSizes : _maleSizes;

  String _validSize(String size, String gender) {
    final sizes = _shoeSizes(gender);
    return sizes.contains(size) ? size : sizes.first;
  }

  String _widthOption(String width) =>
      (width == 'M' || width == 'W' || width == 'XW') ? width : 'Custom';

  bool get _isPolyShell => _orthoticType == TemplateType.polyShell;
  bool get _isRebound => _orthoticType == TemplateType.rebound;
  bool get _isPartialFoot => _orthoticType == TemplateType.partialFoot;
  bool get _showLeftFoot =>
      _footSide == FootSide.left || _footSide == FootSide.bilateral;
  bool get _showRightFoot =>
      _footSide == FootSide.right || _footSide == FootSide.bilateral;

  @override
  void initState() {
    super.initState();
    final wo = widget.workOrder;
    _nameController.text = wo.name;
    _instructionsController.text = wo.specialInstructions;
    _weightController.text = wo.patientWeight?.toString() ?? '';
    _heelLiftHeightController.text = wo.heelLiftHeight;
    _status = wo.status;
    _footSide = wo.footSide;
    _orthoticType = wo.templateType;
    _quantityLeft = wo.quantityLeft;
    _quantityRight = wo.quantityRight;
    _isPartialFootLeft = wo.isPartialFootLeft;
    _isPartialFootRight = wo.isPartialFootRight;
    _toeFillerCountLeft = wo.toeFillerCountLeft;
    _toeFillerCountRight = wo.toeFillerCountRight;
    _baseThickness = wo.baseThickness;
    _baseGrind = wo.baseGrind;
    _topCoverType = wo.topCoverType;
    _topCoverThickness = wo.topCoverThickness;
    _topCoverColor = wo.topCoverColor;
    _shellThickness = wo.shellThickness;
    _baseShellLength = wo.baseShellLength;
    _midLayerType = wo.midLayerType;
    _midLayerThickness = wo.midLayerThickness;
    _archModification = wo.archModification;
    _heelPost = wo.heelPost;
    _forefootPost = wo.forefootPost;
    _heelWedge = wo.heelWedge;
    _forefootWedge = wo.forefootWedge;
    _metPadFoot = wo.metPadFoot;
    _metPadSize = wo.metPadSize;
    _metBarFoot = wo.metBarFoot;
    _metBarSize = wo.metBarSize;
    _heelLiftFoot = wo.heelLiftFoot;
    _heelCup = wo.heelCup;
    _shoeSizeGender = wo.shoeSizeGender.isEmpty ? 'Male' : wo.shoeSizeGender;
    _shoeSize = _validSize(wo.shoeSize, _shoeSizeGender);
    _shoeWidth = wo.shoeWidth.isEmpty ? 'M' : wo.shoeWidth;
    _sameSizeForBothFeet = wo.sameSizeForBothFeet;
    _shoeSizeLeft = _validSize(wo.shoeSizeLeft, _shoeSizeGender);
    _shoeWidthLeft = wo.shoeWidthLeft.isEmpty ? 'M' : wo.shoeWidthLeft;
    _shoeSizeRight = _validSize(wo.shoeSizeRight, _shoeSizeGender);
    _shoeWidthRight = wo.shoeWidthRight.isEmpty ? 'M' : wo.shoeWidthRight;
    if (_widthOption(_shoeWidth) == 'Custom')
      _customShoeWidthController.text = _shoeWidth;
    if (_widthOption(_shoeWidthLeft) == 'Custom')
      _customShoeWidthLeftController.text = _shoeWidthLeft;
    if (_widthOption(_shoeWidthRight) == 'Custom')
      _customShoeWidthRightController.text = _shoeWidthRight;
    _dateOfService = wo.dateOfService;
    _expectedDeliveryDate = wo.expectedDeliveryDate;
    _diagramData = wo.diagramData;
    if (wo.clinicianId.isNotEmpty) {
      try {
        _selectedClinician = _clinicianService.all
            .firstWhere((c) => c.id == wo.clinicianId);
      } catch (_) {
        _selectedClinician = _clinicianService.defaultClinician;
      }
    } else {
      _selectedClinician = _clinicianService.defaultClinician;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _weightController.dispose();
    _heelLiftHeightController.dispose();
    _customShoeWidthController.dispose();
    _customShoeWidthLeftController.dispose();
    _customShoeWidthRightController.dispose();
    super.dispose();
  }

  String get _quantityLabel {
    if (_quantityLeft == 0 && _quantityRight == 0) return 'None';
    if (_quantityLeft == 0) return '$_quantityRight Right';
    if (_quantityRight == 0) return '$_quantityLeft Left';
    if (_quantityLeft == _quantityRight)
      return '$_quantityLeft Pair${_quantityLeft > 1 ? 's' : ''}';
    return '$_quantityLeft L / $_quantityRight R';
  }

  void _updateShellThicknessFromWeight(String weightStr) {
    final weight = double.tryParse(weightStr);
    if (weight == null) return;
    setState(() {
      if (weight <= 170) _shellThickness = '1/8"';
      else if (weight <= 210) _shellThickness = '5/32"';
      else if (weight <= 250) _shellThickness = '3/16"';
      else _shellThickness = '1/4"';
    });
  }

  String _resolveWidth(String widthOption, TextEditingController custom) {
    if (widthOption == 'Custom') return custom.text.trim();
    return widthOption;
  }

  void _applyStateToWorkOrder(WorkOrder wo) {
    wo.name = _nameController.text.trim();
    wo.specialInstructions = _instructionsController.text;
    wo.status = _status;
    wo.footSide = _footSide;
    wo.templateType = _orthoticType;
    wo.quantityLeft = _quantityLeft;
    wo.quantityRight = _quantityRight;
    wo.isPartialFootLeft = _isPartialFootLeft;
    wo.isPartialFootRight = _isPartialFootRight;
    wo.toeFillerCountLeft = _toeFillerCountLeft;
    wo.toeFillerCountRight = _toeFillerCountRight;
    wo.baseThickness = _baseThickness;
    wo.baseGrind = _baseGrind;
    wo.topCoverType = _topCoverType;
    wo.topCoverThickness = _topCoverThickness;
    wo.topCoverColor = _topCoverColor;
    wo.patientWeight = double.tryParse(_weightController.text);
    wo.shellThickness = _shellThickness;
    wo.baseShellLength = _baseShellLength;
    wo.midLayerType = _midLayerType;
    wo.midLayerThickness = _midLayerThickness;
    wo.archModification = _archModification;
    wo.heelPost = _heelPost;
    wo.forefootPost = _forefootPost;
    wo.heelWedge = _heelWedge;
    wo.forefootWedge = _forefootWedge;
    wo.metPadFoot = _metPadFoot;
    wo.metPadSize = _metPadSize;
    wo.metBarFoot = _metBarFoot;
    wo.metBarSize = _metBarSize;
    wo.heelLiftFoot = _heelLiftFoot;
    wo.heelLiftHeight = _heelLiftHeightController.text.trim();
    wo.heelCup = _heelCup;
    wo.shoeSizeGender = _shoeSizeGender;
    wo.sameSizeForBothFeet = _sameSizeForBothFeet;
    wo.diagramData = _diagramData;
    if (_sameSizeForBothFeet) {
      wo.shoeSize = _shoeSize;
      wo.shoeWidth = _resolveWidth(_widthOption(_shoeWidth), _customShoeWidthController);
      wo.shoeSizeLeft = _shoeSize;
      wo.shoeWidthLeft = wo.shoeWidth;
      wo.shoeSizeRight = _shoeSize;
      wo.shoeWidthRight = wo.shoeWidth;
    } else {
      wo.shoeSize = _shoeSizeLeft;
      wo.shoeWidth = _resolveWidth(_widthOption(_shoeWidthLeft), _customShoeWidthLeftController);
      wo.shoeSizeLeft = _shoeSizeLeft;
      wo.shoeWidthLeft = wo.shoeWidth;
      wo.shoeSizeRight = _shoeSizeRight;
      wo.shoeWidthRight = _resolveWidth(_widthOption(_shoeWidthRight), _customShoeWidthRightController);
    }
    wo.dateOfService = _dateOfService;
    wo.expectedDeliveryDate = _expectedDeliveryDate;
    if (_selectedClinician != null) {
      wo.clinicianId = _selectedClinician!.id;
      wo.clinicianName = _selectedClinician!.name;
      wo.clinicName = ClinicianService().activeClinic?.name ?? '';
    }
  }

   Future<void> _save() async {
    _applyStateToWorkOrder(widget.workOrder);
    await widget.onSave(widget.workOrder);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work order saved')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_orthoticType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an orthotic type before saving as a template.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Save as Template',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will save the current product specs, arch modification, and accommodations as a reusable template.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g. My Custom Diabetic Rebound',
                labelStyle: TextStyle(color: Colors.white54),
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4FC3F7))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: const Text('Save Template', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final template = WorkOrderTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      templateType: _orthoticType!,
      isCustom: true,
      baseThickness: _baseThickness,
      topCover: _topCoverType,
      topCoverThickness: _topCoverThickness,
      topCoverColor: _topCoverColor,
      shellThickness: _shellThickness,
      archModification: _archModification,
      heelPost: _heelPost,
      forefootPost: _forefootPost,
      heelWedge: _heelWedge,
      forefootWedge: _forefootWedge,
      metPad: _metPadFoot,
      metBar: _metBarFoot,
      heelLift: _heelLiftFoot,
      heelCup: _heelCup,
      isPartialFootLeft: _isPartialFootLeft,
      isPartialFootRight: _isPartialFootRight,
      toeFillerCountLeft: _toeFillerCountLeft,
      toeFillerCountRight: _toeFillerCountRight,
      description: 'Custom template',
    );

    await DatabaseService().insertTemplate(template);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template "${template.name}" saved')),
      );
    }
  }

  Future<void> _submit() async {    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a work order name before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final wo = widget.workOrder;
    _applyStateToWorkOrder(wo);
    await widget.onSave(wo);
    if (!mounted) {      return;
    }

    // Capture foot diagram
    Uint8List? leftImg;
    Uint8List? rightImg;
    try {
      if (!_footDiagramExpanded) {
        setState(() => _footDiagramExpanded = true);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final leftBoundary = _leftDiagramKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (leftBoundary != null) {
        final img = await leftBoundary.toImage(pixelRatio: 2.0);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        leftImg = bytes?.buffer.asUint8List();
      }
      final rightBoundary = _rightDiagramKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (rightBoundary != null) {
        final img = await rightBoundary.toImage(pixelRatio: 2.0);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        rightImg = bytes?.buffer.asUint8List();
      }
    } catch (e) {
        print('DEBUG diagram capture error: $e');
      }
      print('DEBUG leftImg: ${leftImg?.length} bytes, rightImg: ${rightImg?.length} bytes');
      Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderConfirmationScreen(
          workOrder: wo,
          patient: widget.patient,
          leftDiagramImage: leftImg,
          rightDiagramImage: rightImg,
          onConfirm: () {            final now = DateTime.now();
            if (wo.submissionCount == 0) {
              wo.originalSubmittedAt = now;
            }
            wo.submissionCount += 1;
            wo.status = WorkOrderStatus.submitted;
            wo.submittedAt = now;
            setState(() => _status = WorkOrderStatus.submitted);
            widget.onSave(wo);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _changeOrthoticType(TemplateType newType) {
    if (newType == _orthoticType) return;
    final oldType = _orthoticType;
    final lost = <String>[];
    final transferred = <String>[];
    if (oldType == TemplateType.polyShell && newType != TemplateType.polyShell) {
      lost.addAll(['Patient Weight', 'Shell Thickness', 'Base Shell Length', 'Mid Layer']);
      transferred.addAll(['Top Cover', 'Arch Modification', 'All Accommodations', 'Shoe Size', 'Quantity', 'Dates', 'Clinician', 'Notes']);
    } else if (oldType != TemplateType.polyShell && newType == TemplateType.polyShell) {
      lost.addAll(['Base Thickness', 'Base Grind']);
      transferred.addAll(['Top Cover', 'Arch Modification', 'All Accommodations', 'Shoe Size', 'Quantity', 'Dates', 'Clinician', 'Notes']);
    } else {
      transferred.addAll(['Base Thickness', 'Base Grind', 'Top Cover', 'Arch Modification', 'All Accommodations', 'Shoe Size', 'Quantity', 'Dates', 'Clinician', 'Notes']);
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text('Change to ${_typeName(newType)}?',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transferred.isNotEmpty) ...[
                const Text('Will transfer:',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                ...transferred.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        const Icon(Icons.check, color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    )),
              ],
              if (lost.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Will be lost:',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                ...lost.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        const Icon(Icons.close, color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (newType == TemplateType.polyShell) {
                  _weightController.clear();
                  _shellThickness = '1/8"';
                  _baseShellLength = 'None';
                  _midLayerType = 'None';
                  _midLayerThickness = 'None';
                }
                if (oldType == TemplateType.polyShell) {
                  _baseThickness = '3/16"';
                  _baseGrind = 'Standard';
                }
                 if (oldType == TemplateType.polyShell && newType != TemplateType.polyShell) {
                    _heelPost = 'None';
                  }
                  // Sync name only if it still matches the last applied template name
                  if (_nameController.text.trim() == widget.workOrder.lastTemplateName.trim() &&
                      widget.workOrder.lastTemplateName.isNotEmpty) {
                    final newDefaultName = DefaultTemplates.defaultNameForType(newType);
                    _nameController.text = newDefaultName;
                    widget.workOrder.lastTemplateName = newDefaultName;
                  }
                  _orthoticType = newType;
                  widget.workOrder.templateType = newType;
                  _productSpecsExpanded = true;
                });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: const Text('Confirm Change', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _typeName(TemplateType? type) {
    switch (type) {
      case TemplateType.rebound: return 'Rebound';
      case TemplateType.polyShell: return 'Poly Shell';
      case TemplateType.partialFoot: return 'Partial Foot';
      case null: return 'Unknown';
    }
  }

  Future<void> _pickDate({required bool isDelivery}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDelivery ? now.add(const Duration(days: 25)) : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4FC3F7),
            surface: Color(0xFF16213E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDelivery) _expectedDeliveryDate = picked;
        else _dateOfService = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tap to set';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _shoeSizeColumn({
    required String label,
    required String size,
    required String gender,
    required String widthOption,
    required TextEditingController customWidthController,
    required Function(String) onSizeChanged,
    required Function(String) onWidthChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _validSize(size, gender),
          dropdownColor: const Color(0xFF16213E),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Size',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
          ),
          items: _shoeSizes(gender)
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (v) => onSizeChanged(v ?? size),
        ),
        const SizedBox(height: 8),
        OptionRow(
          label: 'Width',
          options: const ['M', 'W', 'XW', 'Custom'],
          selected: _widthOption(widthOption),
          onChanged: (v) {
            onWidthChanged(v);
            if (v != 'Custom') customWidthController.clear();
          },
        ),
        if (_widthOption(widthOption) == 'Custom') ...[
          const SizedBox(height: 8),
          TextField(
            controller: customWidthController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Custom Width',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicians = _clinicianService.all;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _applyStateToWorkOrder(widget.workOrder);
        await widget.onSave(widget.workOrder);
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Work Order', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              _applyStateToWorkOrder(widget.workOrder);
              await widget.onSave(widget.workOrder);
              if (mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFF4FC3F7)),
              tooltip: 'Save as Template',
              onPressed: _saveAsTemplate,
            ),
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(color: Color(0xFF4FC3F7))),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: _isDrawMode
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(_status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(_status)),
                  ),
                  child: Text(widget.workOrder.statusLabel,
                      style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text('Created ${_formatDate(widget.workOrder.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Clinician',
                icon: Icons.medical_services,
                isExpanded: _clinicianExpanded,
                onToggle: () => setState(() => _clinicianExpanded = !_clinicianExpanded),
                summary: _selectedClinician?.name ?? 'Not selected',
                child: clinicians.isEmpty
                    ? const Text('No clinician profiles. Add one in Settings.',
                        style: TextStyle(color: Colors.white54))
                    : DropdownButtonFormField<Clinician>(
                        value: _selectedClinician,
                        dropdownColor: const Color(0xFF16213E),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                        ),
                        items: clinicians
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.fullLabel,
                                    style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedClinician = v),
                      ),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Patient',
                icon: Icons.person,
                isExpanded: _patientExpanded,
                onToggle: () => setState(() => _patientExpanded = !_patientExpanded),
                summary: widget.patient.fullName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.patient.fullName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (widget.patient.patientId.isNotEmpty)
                      Text('ID: ${widget.patient.patientId}',
                          style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13)),
                    if (widget.patient.dateOfBirth.isNotEmpty)
                      Text('DOB: ${widget.patient.dateOfBirth}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
           ),

                if (widget.patient.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3460).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note_alt, color: Color(0xFF4FC3F7), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Clinical Notes',
                                  style: TextStyle(color: Color(0xFF4FC3F7),
                                      fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(widget.patient.notes,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                _buildSection(
                  title: 'Work Order Name / Number',
                icon: Icons.label,
                child: _buildField('Name / Number', _nameController,
                    hint: 'e.g. John Doe 1234'),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Orthotic Type',
                icon: Icons.category,
                isExpanded: _orthoticTypeExpanded,
                onToggle: () => setState(() => _orthoticTypeExpanded = !_orthoticTypeExpanded),
                summary: _typeName(_orthoticType),
                child: DropdownButtonFormField<TemplateType>(
                  value: _orthoticType,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TemplateType.rebound,
                      child: Text('Rebound', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: TemplateType.polyShell,
                      child: Text('Poly Shell', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: TemplateType.partialFoot,
                      child: Text('Partial Foot', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (v) { if (v != null) _changeOrthoticType(v); },
                ),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Dates',
                icon: Icons.calendar_today,
                isExpanded: _datesExpanded,
                onToggle: () => setState(() => _datesExpanded = !_datesExpanded),
                summary: _dateOfService != null || _expectedDeliveryDate != null
                    ? '${_formatDate(_dateOfService)} → ${_formatDate(_expectedDeliveryDate)}'
                    : 'Not set',
                child: Column(children: [
                  WorkOrderDateRow(
                      label: 'Date of Service',
                      value: _formatDate(_dateOfService),
                      onTap: () => _pickDate(isDelivery: false),
                      color: const Color(0xFF4FC3F7)),
                  const SizedBox(height: 12),
                  WorkOrderDateRow(
                      label: 'Expected Delivery',
                      value: _formatDate(_expectedDeliveryDate),
                      onTap: () => _pickDate(isDelivery: true),
                      color: Colors.green),
                ]),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Shoe Size',
                icon: Icons.straighten,
                isExpanded: _shoeSizeExpanded,
                onToggle: () => setState(() => _shoeSizeExpanded = !_shoeSizeExpanded),
                summary: '$_shoeSizeGender · ${_sameSizeForBothFeet ? '$_shoeSize / $_shoeWidth' : 'L:$_shoeSizeLeft R:$_shoeSizeRight'}',
                child: Column(children: [
                  OptionRow(
                    label: 'Gender',
                    options: const ['Male', 'Female'],
                    selected: _shoeSizeGender,
                    onChanged: (v) => setState(() {
                      _shoeSizeGender = v;
                      _shoeSize = _shoeSizes(v).first;
                      _shoeSizeLeft = _shoeSizes(v).first;
                      _shoeSizeRight = _shoeSizes(v).first;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Same size for both feet',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Switch(
                        value: _sameSizeForBothFeet,
                        activeColor: const Color(0xFF4FC3F7),
                        onChanged: (v) => setState(() => _sameSizeForBothFeet = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_sameSizeForBothFeet) ...[
                    DropdownButtonFormField<String>(
                      value: _validSize(_shoeSize, _shoeSizeGender),
                      dropdownColor: const Color(0xFF16213E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Shoe Size',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                      ),
                      items: _shoeSizes(_shoeSizeGender)
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, style: const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _shoeSize = v ?? _shoeSize),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Width',
                      options: const ['M', 'W', 'XW', 'Custom'],
                      selected: _widthOption(_shoeWidth),
                      onChanged: (v) => setState(() {
                        _shoeWidth = v;
                        if (v != 'Custom') _customShoeWidthController.clear();
                      }),
                    ),
                    if (_widthOption(_shoeWidth) == 'Custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customShoeWidthController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Custom Width',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _shoeSizeColumn(
                            label: 'Left Foot',
                            size: _shoeSizeLeft,
                            gender: _shoeSizeGender,
                            widthOption: _shoeWidthLeft,
                            customWidthController: _customShoeWidthLeftController,
                            onSizeChanged: (v) => setState(() => _shoeSizeLeft = v),
                            onWidthChanged: (v) => setState(() => _shoeWidthLeft = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _shoeSizeColumn(
                            label: 'Right Foot',
                            size: _shoeSizeRight,
                            gender: _shoeSizeGender,
                            widthOption: _shoeWidthRight,
                            customWidthController: _customShoeWidthRightController,
                            onSizeChanged: (v) => setState(() => _shoeSizeRight = v),
                            onWidthChanged: (v) => setState(() => _shoeWidthRight = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Quantity',
                icon: Icons.numbers,
                isExpanded: _quantityExpanded,
                onToggle: () => setState(() => _quantityExpanded = !_quantityExpanded),
                summary: _quantityLabel,
                child: Column(children: [
                  Row(children: [
                    if (_showLeftFoot)
                      Expanded(
                          child: QuantitySelector(
                              label: 'Left',
                              value: _quantityLeft,
                              color: Colors.blue,
                              onChanged: (v) => setState(() => _quantityLeft = v))),
                    if (_showLeftFoot && _showRightFoot) const SizedBox(width: 16),
                    if (_showRightFoot)
                      Expanded(
                          child: QuantitySelector(
                              label: 'Right',
                              value: _quantityRight,
                              color: Colors.orange,
                              onChanged: (v) => setState(() => _quantityRight = v))),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(color: Colors.white54)),
                        Text(_quantityLabel,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              if (!_isPolyShell && (_showLeftFoot || _showRightFoot)) ...[
                _CollapsibleSection(
                  title: 'Partial Foot',
                  icon: Icons.accessibility_new,
                  isExpanded: _partialFootExpanded,
                  onToggle: () => setState(() => _partialFootExpanded = !_partialFootExpanded),
                  summary: (_isPartialFootLeft || _isPartialFootRight) ? 'Yes' : 'No',
                  child: Column(children: [
                    if (_showLeftFoot)
                      PartialFootRow(
                        label: 'Left Foot is Partial',
                        isChecked: _isPartialFootLeft,
                        toeCount: _toeFillerCountLeft,
                        onChanged: (v) => setState(() => _isPartialFootLeft = v),
                        onToeCountChanged: (v) => setState(() => _toeFillerCountLeft = v),
                      ),
                    if (_showLeftFoot && _showRightFoot) const SizedBox(height: 8),
                    if (_showRightFoot)
                      PartialFootRow(
                        label: 'Right Foot is Partial',
                        isChecked: _isPartialFootRight,
                        toeCount: _toeFillerCountRight,
                        onChanged: (v) => setState(() => _isPartialFootRight = v),
                        onToeCountChanged: (v) => setState(() => _toeFillerCountRight = v),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (_isRebound || _isPartialFoot)
                _CollapsibleSection(
                  title: 'Product Specs',
                  icon: Icons.layers,
                  isExpanded: _productSpecsExpanded,
                  onToggle: () => setState(() => _productSpecsExpanded = !_productSpecsExpanded),
                  summary: '$_baseThickness · $_topCoverType',
                  child: Column(children: [
                    OptionRow(
                      label: 'Base Thickness',
                      options: const ['3/16"', '1/4"'],
                      selected: _baseThickness,
                      onChanged: (v) => setState(() => _baseThickness = v),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Base Grind',
                      options: const ['None', 'Narrow', 'Standard', 'Wide'],
                      selected: _baseGrind,
                      onChanged: (v) => setState(() => _baseGrind = v),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Top Cover',
                      options: const ['Microcel Puff', 'P-Cell'],
                      selected: _topCoverType,
                      onChanged: (v) {
                        setState(() {
                          _topCoverType = v;
                          if (v == 'P-Cell') {
                            _topCoverThickness = '1/8"';
                            _topCoverColor = 'Solid Black';
                          } else {
                            _topCoverThickness = '1/16"';
                            _topCoverColor = 'Solid Blue';
                          }
                        });
                      },
                    ),
                    if (_topCoverType == 'Microcel Puff') ...[
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Cover Thickness',
                        options: const ['1/16"', '1/8"'],
                        selected: _topCoverThickness,
                        onChanged: (v) => setState(() => _topCoverThickness = v),
                      ),
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Cover Color',
                        options: const [
                          'Solid Blue', 'Solid Black', 'Swirl Blue',
                          'Swirl Black', 'Swirl Purple', 'Swirl Pink',
                        ],
                        selected: _topCoverColor,
                        onChanged: (v) => setState(() => _topCoverColor = v),
                        wrap: true,
                      ),
                    ],
                    if (_topCoverType == 'P-Cell') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: Color(0xFF4FC3F7), size: 16),
                          SizedBox(width: 8),
                          Text('P-Cell: 1/8" Solid Black only',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ]),
                ),

              if (_isPolyShell)
                _CollapsibleSection(
                  title: 'Product Specs',
                  icon: Icons.view_in_ar,
                  isExpanded: _productSpecsExpanded,
                  onToggle: () => setState(() => _productSpecsExpanded = !_productSpecsExpanded),
                  summary: '$_shellThickness · $_topCoverType',
                  child: Column(children: [
                    TextField(
                      controller: _weightController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Patient Weight (lbs)',
                        labelStyle: TextStyle(color: Colors.white54),
                        suffixText: 'lbs',
                        suffixStyle: TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                      ),
                      onChanged: _updateShellThicknessFromWeight,
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Shell Thickness',
                      options: const ['1/8"', '5/32"', '3/16"', '1/4"'],
                      selected: _shellThickness,
                      onChanged: (v) => setState(() => _shellThickness = v),
                      subtitle: _weightController.text.isNotEmpty ? 'Auto-suggested from weight' : null,
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Base Shell Length',
                      options: const ['None', 'Mets', 'Sulcus', 'Full'],
                      selected: _baseShellLength,
                      onChanged: (v) => setState(() => _baseShellLength = v),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Mid Layer',
                      options: const ['None', 'Microcel Puff', 'Poron'],
                      selected: _midLayerType,
                      onChanged: (v) {
                        setState(() {
                          _midLayerType = v;
                          _midLayerThickness = v == 'None' ? 'None' : '1/16"';
                        });
                      },
                    ),
                    if (_midLayerType != 'None') ...[
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Mid Layer Thickness',
                        options: const ['1/16"', '1/8"'],
                        selected: _midLayerThickness,
                        onChanged: (v) => setState(() => _midLayerThickness = v),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Top Cover',
                      options: const ['None', 'Microcel Puff', 'Neoprene w/Nylon', 'Microfiber Suede', 'Vinyl'],
                      selected: _topCoverType,
                      onChanged: (v) {
                        setState(() {
                          _topCoverType = v;
                          if (v == 'Microcel Puff') {
                            _topCoverThickness = '1/16"';
                            _topCoverColor = 'Solid Blue';
                          } else if (v == 'Neoprene w/Nylon') {
                            _topCoverThickness = '1/16"';
                            _topCoverColor = 'None';
                          } else {
                            _topCoverThickness = 'None';
                            _topCoverColor = 'Black';
                          }
                        });
                      },
                      wrap: true,
                    ),
                    if (_topCoverType == 'Microcel Puff') ...[
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Cover Thickness',
                        options: const ['1/16"', '1/8"'],
                        selected: _topCoverThickness,
                        onChanged: (v) => setState(() => _topCoverThickness = v),
                      ),
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Cover Color',
                        options: const [
                          'Solid Blue', 'Solid Black', 'Swirl Blue',
                          'Swirl Black', 'Swirl Purple', 'Swirl Pink',
                        ],
                        selected: _topCoverColor,
                        onChanged: (v) => setState(() => _topCoverColor = v),
                        wrap: true,
                      ),
                    ],
                    if (_topCoverType == 'Neoprene w/Nylon') ...[
                      const SizedBox(height: 12),
                      OptionRow(
                        label: 'Cover Thickness',
                        options: const ['1/16"', '1/8"'],
                        selected: _topCoverThickness,
                        onChanged: (v) => setState(() => _topCoverThickness = v),
                      ),
                    ],
                  ]),
                ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Arch Modification',
                icon: Icons.architecture,
                isExpanded: _archModExpanded,
                onToggle: () => setState(() => _archModExpanded = !_archModExpanded),
                summary: _archModification == 0 ? 'As Cast' : _archModification > 0 ? '+$_archModification' : '$_archModification',
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Decrease', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(
                        _archModification == 0 ? 'As Cast (0)' : _archModification > 0 ? 'Increase +$_archModification' : 'Decrease $_archModification',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text('Increase', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: _archModification.toDouble(),
                    min: -3, max: 3, divisions: 6,
                    activeColor: const Color(0xFF4FC3F7),
                    inactiveColor: Colors.white24,
                    label: _archModification == 0 ? 'As Cast' : '$_archModification',
                    onChanged: (v) => setState(() => _archModification = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final val = i - 3;
                      return Text('$val',
                          style: TextStyle(
                              color: _archModification == val ? const Color(0xFF4FC3F7) : Colors.white38,
                              fontSize: 12,
                              fontWeight: _archModification == val ? FontWeight.bold : FontWeight.normal));
                    }),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Accommodations',
                icon: Icons.tune,
                isExpanded: _accommodationsExpanded,
                onToggle: () => setState(() => _accommodationsExpanded = !_accommodationsExpanded),
                summary: () {
                  final items = [
                    if (_heelPost != 'None') 'Heel Post',
                    if (_forefootPost != 'None') 'FF Post',
                    if (_heelWedge != 'None') 'Heel Wedge',
                    if (_forefootWedge != 'None') 'FF Wedge',
                    if (_metPadFoot != 'None') 'Met Pad',
                    if (_metBarFoot != 'None') 'Met Bar',
                    if (_heelLiftFoot != 'None') 'Heel Lift',
                    if (_heelCup != 'None') 'Heel Cup',
                  ];
                  return items.isEmpty ? 'None selected' : items.join(' · ');
                }(),
                child: Column(children: [
                  if (_isPolyShell) ...[
                    OptionRow(
                      label: 'Heel Post',
                      options: const ['None', 'Intrinsic', 'Extrinsic'],
                      selected: _heelPost,
                      onChanged: (v) => setState(() => _heelPost = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OptionRow(
                    label: 'Forefoot Post',
                    options: const ['None', 'Lateral', 'Medial'],
                    selected: _forefootPost,
                    onChanged: (v) => setState(() => _forefootPost = v),
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Heel Wedge',
                    options: const ['None', 'Lateral', 'Medial'],
                    selected: _heelWedge,
                    onChanged: (v) => setState(() => _heelWedge = v),
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Forefoot Wedge',
                    options: const ['None', 'Lateral', 'Medial'],
                    selected: _forefootWedge,
                    onChanged: (v) => setState(() => _forefootWedge = v),
                  ),
                  const SizedBox(height: 12),
                  FootAccommodationRow(
                    label: 'Met Pad',
                    footValue: _metPadFoot,
                    sizeValue: _metPadSize,
                    onFootChanged: (v) => setState(() => _metPadFoot = v),
                    onSizeChanged: (v) => setState(() => _metPadSize = v),
                  ),
                  const SizedBox(height: 12),
                  FootAccommodationRow(
                    label: 'Met Bar',
                    footValue: _metBarFoot,
                    sizeValue: _metBarSize,
                    onFootChanged: (v) => setState(() => _metBarFoot = v),
                    onSizeChanged: (v) => setState(() => _metBarSize = v),
                  ),
                  const SizedBox(height: 12),
                  HeelLiftRow(
                    footValue: _heelLiftFoot,
                    heightController: _heelLiftHeightController,
                    onFootChanged: (v) => setState(() => _heelLiftFoot = v),
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Heel Cup',
                    options: const ['None', 'Standard', 'Deep'],
                    selected: _heelCup,
                    onChanged: (v) => setState(() => _heelCup = v),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Foot Diagram',
                icon: Icons.draw,
                isExpanded: _footDiagramExpanded,
                onToggle: () => setState(() => _footDiagramExpanded = !_footDiagramExpanded),
                summary: 'Tap to open diagram',
                child: FootDiagramWidget(
                  initialData: _diagramData,
                  leftRepaintKey: _leftDiagramKey,
                  rightRepaintKey: _rightDiagramKey,
                  onDrawModeChanged: (isDrawing) =>
                      setState(() => _isDrawMode = isDrawing),
                  onDataChanged: (data) =>
                      _diagramData = data.toJsonString(),
                ),
              ),

              const SizedBox(height: 16),

              _CollapsibleSection(
                title: 'Notes',
                icon: Icons.note_alt,
                isExpanded: _notesExpanded,
                onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
                summary: _instructionsController.text.isEmpty ? 'No notes' : _instructionsController.text,
                child: TextField(
                 controller: _instructionsController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    hintText: 'Enter any notes or special instructions for the lab...',
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: Text(
                      _status == WorkOrderStatus.submitted
                          ? 'Re-Submit to Lab' : 'Submit to Lab',
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
      ),
    );
  }

  Color _statusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.draft: return Colors.orange;
      case WorkOrderStatus.submitted: return Colors.blue;
      case WorkOrderStatus.inProgress: return Colors.purple;
      case WorkOrderStatus.completed: return Colors.green;
      case WorkOrderStatus.shipped: return const Color(0xFF4FC3F7);
    }
  }
}

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String summary;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.summary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (!isExpanded) ...[
                        const SizedBox(height: 2),
                        Text(summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white38,
                ),
              ]),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}




