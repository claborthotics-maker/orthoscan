import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../models/clinician.dart';
import '../services/clinician_service.dart';
import 'work_order_widgets.dart';
import 'foot_diagram_widget.dart';

class WorkOrderScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final Patient patient;
  final Function(WorkOrder) onSave;

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

  late WorkOrderStatus _status;
  late FootSide _footSide;
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

  DateTime? _dateOfService;
  DateTime? _expectedDeliveryDate;
  Clinician? _selectedClinician;
  bool _isDrawMode = false;

  // Shoe size lists
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

  String get _shoeSizeDropdownValue {
    final sizes = _shoeSizes(_shoeSizeGender);
    return sizes.contains(_shoeSize) ? _shoeSize : sizes.first;
  }

  bool get _isPolyShell =>
      widget.workOrder.templateType == TemplateType.polyShell;
  bool get _isRebound =>
      widget.workOrder.templateType == TemplateType.rebound;
  bool get _isPartialFoot =>
      widget.workOrder.templateType == TemplateType.partialFoot;
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
    final sizes = _shoeSizes(_shoeSizeGender);
    _shoeSize = sizes.contains(wo.shoeSize) ? wo.shoeSize : sizes.first;
    _shoeWidth = wo.shoeWidth.isEmpty ? 'M' : wo.shoeWidth;
    if (_shoeWidth != 'M' && _shoeWidth != 'L' &&
        _shoeWidth != 'XL') {
      _customShoeWidthController.text = _shoeWidth;
      _shoeWidth = 'Custom';
    }
    _dateOfService = wo.dateOfService;
    _expectedDeliveryDate = wo.expectedDeliveryDate;

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

  void _save() {
    final wo = widget.workOrder;
    wo.name = _nameController.text.trim();
    wo.specialInstructions = _instructionsController.text;
    wo.status = _status;
    wo.footSide = _footSide;
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
    wo.shoeSize = _shoeSize;
    wo.shoeSizeGender = _shoeSizeGender;
    wo.shoeWidth = _shoeWidth == 'Custom'
        ? _customShoeWidthController.text.trim()
        : _shoeWidth;
    wo.dateOfService = _dateOfService;
    wo.expectedDeliveryDate = _expectedDeliveryDate;

    if (_selectedClinician != null) {
      wo.clinicianId = _selectedClinician!.id;
      wo.clinicianName = _selectedClinician!.name;
      wo.clinicName = ClinicianService().activeClinic?.name ?? '';
    }

    widget.onSave(wo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Work order saved')),
    );
    Navigator.pop(context);
  }

  void _submit() {
    setState(() {
      _status = WorkOrderStatus.submitted;
      widget.workOrder.submittedAt = DateTime.now();
    });
    _save();
  }

  Future<void> _pickDate({required bool isDelivery}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isDelivery ? now.add(const Duration(days: 14)) : now,
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

  @override
  Widget build(BuildContext context) {
    final clinicians = _clinicianService.all;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Work Order',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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

            // ─── Status ───────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _statusColor(_status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(_status)),
                ),
                child: Text(widget.workOrder.statusLabel,
                    style: TextStyle(
                        color: _statusColor(_status),
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(
                'Created ${_formatDate(widget.workOrder.createdAt)}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ]),

            const SizedBox(height: 16),

            // ─── Name ─────────────────────────────────────────────────
            _buildSection(
              title: 'Work Order Name',
              icon: Icons.label,
              child: _buildField('Name', _nameController,
                  hint: 'e.g. Running Rebound'),
            ),

            const SizedBox(height: 16),

            // ─── Patient ──────────────────────────────────────────────
            _buildSection(
              title: 'Patient',
              icon: Icons.person,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.patient.fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  if (widget.patient.patientId.isNotEmpty)
                    Text('ID: ${widget.patient.patientId}',
                        style: const TextStyle(
                            color: Color(0xFF4FC3F7), fontSize: 13)),
                  if (widget.patient.dateOfBirth.isNotEmpty)
                    Text('DOB: ${widget.patient.dateOfBirth}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Clinician ────────────────────────────────────────────
            _buildSection(
              title: 'Clinician',
              icon: Icons.medical_services,
              child: clinicians.isEmpty
                  ? const Text(
                      'No clinician profiles. Add one in Settings.',
                      style: TextStyle(color: Colors.white54))
                  : DropdownButtonFormField<Clinician>(
                      value: _selectedClinician,
                      dropdownColor: const Color(0xFF16213E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0xFF4FC3F7))),
                      ),
                      items: clinicians
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.fullLabel,
                                  style: const TextStyle(
                                      color: Colors.white))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedClinician = v),
                    ),
            ),

            const SizedBox(height: 16),

            // ─── Dates ────────────────────────────────────────────────
            _buildSection(
              title: 'Dates',
              icon: Icons.calendar_today,
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

            // ─── Shoe Size ────────────────────────────────────────────
            _buildSection(
              title: 'Shoe Size',
              icon: Icons.straighten,
              child: Column(children: [
                OptionRow(
                  label: 'Gender',
                  options: const ['Male', 'Female'],
                  selected: _shoeSizeGender,
                  onChanged: (v) => setState(() {
                    _shoeSizeGender = v;
                    _shoeSize = _shoeSizes(v).first;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _shoeSizeDropdownValue,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Shoe Size',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Color(0xFF4FC3F7))),
                  ),
                  items: _shoeSizes(_shoeSizeGender)
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style: const TextStyle(
                                    color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _shoeSize = v ?? _shoeSize),
                ),
                const SizedBox(height: 12),
                OptionRow(
                  label: 'Width',
                  options: const ['M', 'L', 'XL', 'Custom'],
                  selected: _shoeWidth,
                  onChanged: (v) => setState(() {
                    _shoeWidth = v;
                    if (v != 'Custom')
                      _customShoeWidthController.clear();
                  }),
                ),
                if (_shoeWidth == 'Custom') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customShoeWidthController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Custom Width',
                      labelStyle:
                          TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color(0xFF4FC3F7))),
                    ),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 16),

            // ─── Quantity ─────────────────────────────────────────────
            _buildSection(
              title: 'Quantity',
              icon: Icons.numbers,
              child: Column(children: [
                Row(children: [
                  if (_showLeftFoot)
                    Expanded(
                        child: QuantitySelector(
                            label: 'Left',
                            value: _quantityLeft,
                            color: Colors.blue,
                            onChanged: (v) =>
                                setState(() => _quantityLeft = v))),
                  if (_showLeftFoot && _showRightFoot)
                    const SizedBox(width: 16),
                  if (_showRightFoot)
                    Expanded(
                        child: QuantitySelector(
                            label: 'Right',
                            value: _quantityRight,
                            color: Colors.orange,
                            onChanged: (v) =>
                                setState(() => _quantityRight = v))),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(color: Colors.white54)),
                      Text(_quantityLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ─── Partial Foot ─────────────────────────────────────────
            if (!_isPolyShell && (_showLeftFoot || _showRightFoot))
              _buildSection(
                title: 'Partial Foot',
                icon: Icons.accessibility_new,
                child: Column(children: [
                  if (_showLeftFoot)
                    PartialFootRow(
                      label: 'Left Foot is Partial',
                      isChecked: _isPartialFootLeft,
                      toeCount: _toeFillerCountLeft,
                      onChanged: (v) =>
                          setState(() => _isPartialFootLeft = v),
                      onToeCountChanged: (v) =>
                          setState(() => _toeFillerCountLeft = v),
                    ),
                  if (_showLeftFoot && _showRightFoot)
                    const SizedBox(height: 8),
                  if (_showRightFoot)
                    PartialFootRow(
                      label: 'Right Foot is Partial',
                      isChecked: _isPartialFootRight,
                      toeCount: _toeFillerCountRight,
                      onChanged: (v) =>
                          setState(() => _isPartialFootRight = v),
                      onToeCountChanged: (v) =>
                          setState(() => _toeFillerCountRight = v),
                    ),
                ]),
              ),

            const SizedBox(height: 16),

            // ─── Rebound Product Specs ────────────────────────────────
            if (_isRebound || _isPartialFoot)
              _buildSection(
                title: 'Product Specs',
                icon: Icons.layers,
                child: Column(children: [
                  OptionRow(
                    label: 'Base Thickness',
                    options: const ['3/16"', '1/4"'],
                    selected: _baseThickness,
                    onChanged: (v) =>
                        setState(() => _baseThickness = v),
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Base Grind',
                    options: const [
                      'None', 'Narrow', 'Standard', 'Wide'
                    ],
                    selected: _baseGrind,
                    onChanged: (v) =>
                        setState(() => _baseGrind = v),
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
                      onChanged: (v) =>
                          setState(() => _topCoverThickness = v),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Cover Color',
                      options: const [
                        'Solid Blue', 'Solid Black',
                        'Swirl Blue', 'Swirl Black',
                        'Swirl Purple', 'Swirl Pink',
                      ],
                      selected: _topCoverColor,
                      onChanged: (v) =>
                          setState(() => _topCoverColor = v),
                      wrap: true,
                    ),
                  ],
                  if (_topCoverType == 'P-Cell') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF4FC3F7), size: 16),
                        SizedBox(width: 8),
                        Text('P-Cell: 1/8" Solid Black only',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13)),
                      ]),
                    ),
                  ],
                ]),
              ),

            // ─── Poly Shell Product Specs ─────────────────────────────
            if (_isPolyShell) ...[
              _buildSection(
                title: 'Product Specs',
                icon: Icons.view_in_ar,
                child: Column(children: [
                  TextField(
                    controller: _weightController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Patient Weight (lbs)',
                      labelStyle:
                          TextStyle(color: Colors.white54),
                      suffixText: 'lbs',
                      suffixStyle:
                          TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color(0xFF4FC3F7))),
                    ),
                    onChanged: _updateShellThicknessFromWeight,
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Shell Thickness',
                    options: const [
                      '1/8"', '5/32"', '3/16"', '1/4"'
                    ],
                    selected: _shellThickness,
                    onChanged: (v) =>
                        setState(() => _shellThickness = v),
                    subtitle: _weightController.text.isNotEmpty
                        ? 'Auto-suggested from weight'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Base Shell Length',
                    options: const [
                      'None', 'Mets', 'Sulcus', 'Full'
                    ],
                    selected: _baseShellLength,
                    onChanged: (v) =>
                        setState(() => _baseShellLength = v),
                  ),
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Mid Layer',
                    options: const [
                      'None', 'Microcel Puff', 'Poron'
                    ],
                    selected: _midLayerType,
                    onChanged: (v) {
                      setState(() {
                        _midLayerType = v;
                        _midLayerThickness =
                            v == 'None' ? 'None' : '1/16"';
                      });
                    },
                  ),
                  if (_midLayerType != 'None') ...[
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Mid Layer Thickness',
                      options: const ['1/16"', '1/8"'],
                      selected: _midLayerThickness,
                      onChanged: (v) =>
                          setState(() => _midLayerThickness = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OptionRow(
                    label: 'Top Cover',
                    options: const [
                      'None', 'Microcel Puff',
                      'Neoprene w/Nylon', 'Microfiber Suede',
                      'Vinyl',
                    ],
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
                      onChanged: (v) =>
                          setState(() => _topCoverThickness = v),
                    ),
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Cover Color',
                      options: const [
                        'Solid Blue', 'Solid Black',
                        'Swirl Blue', 'Swirl Black',
                        'Swirl Purple', 'Swirl Pink',
                      ],
                      selected: _topCoverColor,
                      onChanged: (v) =>
                          setState(() => _topCoverColor = v),
                      wrap: true,
                    ),
                  ],
                  if (_topCoverType == 'Neoprene w/Nylon') ...[
                    const SizedBox(height: 12),
                    OptionRow(
                      label: 'Cover Thickness',
                      options: const ['1/16"', '1/8"'],
                      selected: _topCoverThickness,
                      onChanged: (v) =>
                          setState(() => _topCoverThickness = v),
                    ),
                  ],
                ]),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Arch Modification ────────────────────────────────────
            _buildSection(
              title: 'Arch Modification',
              icon: Icons.architecture,
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Decrease',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    Text(
                      _archModification == 0
                          ? 'As Cast (0)'
                          : _archModification > 0
                              ? 'Increase +$_archModification'
                              : 'Decrease $_archModification',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('Increase',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _archModification.toDouble(),
                  min: -3, max: 3, divisions: 6,
                  activeColor: const Color(0xFF4FC3F7),
                  inactiveColor: Colors.white24,
                  label: _archModification == 0
                      ? 'As Cast' : '$_archModification',
                  onChanged: (v) =>
                      setState(() => _archModification = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final val = i - 3;
                    return Text('$val',
                        style: TextStyle(
                            color: _archModification == val
                                ? const Color(0xFF4FC3F7)
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: _archModification == val
                                ? FontWeight.bold
                                : FontWeight.normal));
                  }),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ─── Accommodations ───────────────────────────────────────
            _buildSection(
              title: 'Accommodations',
              icon: Icons.tune,
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
                  onChanged: (v) =>
                      setState(() => _forefootPost = v),
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
                  onChanged: (v) =>
                      setState(() => _forefootWedge = v),
                ),
                const SizedBox(height: 12),
                FootAccommodationRow(
                  label: 'Met Pad',
                  footValue: _metPadFoot,
                  sizeValue: _metPadSize,
                  onFootChanged: (v) =>
                      setState(() => _metPadFoot = v),
                  onSizeChanged: (v) =>
                      setState(() => _metPadSize = v),
                ),
                const SizedBox(height: 12),
                FootAccommodationRow(
                  label: 'Met Bar',
                  footValue: _metBarFoot,
                  sizeValue: _metBarSize,
                  onFootChanged: (v) =>
                      setState(() => _metBarFoot = v),
                  onSizeChanged: (v) =>
                      setState(() => _metBarSize = v),
                ),
                const SizedBox(height: 12),
                HeelLiftRow(
                  footValue: _heelLiftFoot,
                  heightController: _heelLiftHeightController,
                  onFootChanged: (v) =>
                      setState(() => _heelLiftFoot = v),
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

            // ─── Foot Diagram ─────────────────────────────────────────
            _buildSection(
              title: 'Foot Diagram',
              icon: Icons.draw,
              child: FootDiagramWidget(
                onDrawModeChanged: (isDrawing) =>
                    setState(() => _isDrawMode = isDrawing),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Special Instructions ─────────────────────────────────
            _buildSection(
              title: 'Special Instructions',
              icon: Icons.note_alt,
              child: TextField(
                controller: _instructionsController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Enter any special instructions for the lab...',
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF4FC3F7))),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Submit ───────────────────────────────────────────────
            if (_status == WorkOrderStatus.draft)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('Submit to Lab',
                      style: TextStyle(
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
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {String? hint}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4FC3F7))),
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