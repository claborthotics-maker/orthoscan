import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/clinician.dart';
import '../services/clinician_service.dart';

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
  final _productController = TextEditingController();
  final _materialsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _nameController = TextEditingController();

  late WorkOrderStatus _status;
  late FootSide _footSide;
  late int _quantityLeft;
  late int _quantityRight;
  late bool _isPartialFootLeft;
  late bool _isPartialFootRight;
  late int _toeFillerCountLeft;
  late int _toeFillerCountRight;
  DateTime? _dateOfService;
  DateTime? _expectedDeliveryDate;
  Clinician? _selectedClinician;

  @override
  void initState() {
    super.initState();
    _productController.text = widget.workOrder.productType;
    _materialsController.text = widget.workOrder.materials;
    _instructionsController.text = widget.workOrder.specialInstructions;
    _nameController.text = widget.workOrder.name;
    _status = widget.workOrder.status;
    _footSide = widget.workOrder.footSide;
    _quantityLeft = widget.workOrder.quantityLeft;
    _quantityRight = widget.workOrder.quantityRight;
    _isPartialFootLeft = widget.workOrder.isPartialFootLeft;
    _isPartialFootRight = widget.workOrder.isPartialFootRight;
    _toeFillerCountLeft = widget.workOrder.toeFillerCountLeft;
    _toeFillerCountRight = widget.workOrder.toeFillerCountRight;
    _dateOfService = widget.workOrder.dateOfService;
    _expectedDeliveryDate = widget.workOrder.expectedDeliveryDate;

    if (widget.workOrder.clinicianId.isNotEmpty) {
      try {
        _selectedClinician = _clinicianService.all.firstWhere(
          (c) => c.id == widget.workOrder.clinicianId,
        );
      } catch (_) {
        _selectedClinician = _clinicianService.defaultClinician;
      }
    } else {
      _selectedClinician = _clinicianService.defaultClinician;
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    _materialsController.dispose();
    _instructionsController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _quantityLabel {
    if (_quantityLeft == 0 && _quantityRight == 0) return 'None';
    if (_quantityLeft == 0) return '$_quantityRight Right';
    if (_quantityRight == 0) return '$_quantityLeft Left';
    if (_quantityLeft == _quantityRight) {
      return '$_quantityLeft Pair${_quantityLeft > 1 ? 's' : ''}';
    }
    return '$_quantityLeft L / $_quantityRight R';
  }

  bool get _showLeftFoot =>
      _footSide == FootSide.left || _footSide == FootSide.bilateral;

  bool get _showRightFoot =>
      _footSide == FootSide.right || _footSide == FootSide.bilateral;

  void _save() {
    widget.workOrder.name = _nameController.text.trim();
    widget.workOrder.productType = _productController.text;
    widget.workOrder.materials = _materialsController.text;
    widget.workOrder.specialInstructions = _instructionsController.text;
    widget.workOrder.status = _status;
    widget.workOrder.footSide = _footSide;
    widget.workOrder.quantityLeft = _quantityLeft;
    widget.workOrder.quantityRight = _quantityRight;
    widget.workOrder.isPartialFootLeft = _isPartialFootLeft;
    widget.workOrder.isPartialFootRight = _isPartialFootRight;
    widget.workOrder.toeFillerCountLeft = _toeFillerCountLeft;
    widget.workOrder.toeFillerCountRight = _toeFillerCountRight;
    widget.workOrder.dateOfService = _dateOfService;
    widget.workOrder.expectedDeliveryDate = _expectedDeliveryDate;

    if (_selectedClinician != null) {
      widget.workOrder.clinicianId = _selectedClinician!.id;
      widget.workOrder.clinicianName = _selectedClinician!.name;
      widget.workOrder.clinicName = _selectedClinician!.clinicName;
    }

    widget.onSave(widget.workOrder);
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FC3F7),
              surface: Color(0xFF16213E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDelivery) {
          _expectedDeliveryDate = picked;
        } else {
          _dateOfService = picked;
        }
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
        title: const Text(
          'Work Order',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF4FC3F7)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── Status Badge ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(_status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(_status)),
                  ),
                  child: Text(
                    widget.workOrder.statusLabel,
                    style: TextStyle(
                      color: _statusColor(_status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Created ${_formatDate(widget.workOrder.createdAt)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Work Order Name ──────────────────────────────────────────
            _buildSection(
              title: 'Work Order Name',
              icon: Icons.label,
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Running Rebound',
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4FC3F7)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Patient Info ─────────────────────────────────────────────
            _buildSection(
              title: 'Patient',
              icon: Icons.person,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patient.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.patient.patientId.isNotEmpty)
                    Text(
                      'ID: ${widget.patient.patientId}',
                      style: const TextStyle(
                          color: Color(0xFF4FC3F7), fontSize: 13),
                    ),
                  if (widget.patient.dateOfBirth.isNotEmpty)
                    Text(
                      'DOB: ${widget.patient.dateOfBirth}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Clinician ────────────────────────────────────────────────
            _buildSection(
              title: 'Clinician',
              icon: Icons.medical_services,
              child: clinicians.isEmpty
                  ? const Text(
                      'No clinician profiles. Add one in Settings.',
                      style: TextStyle(color: Colors.white54),
                    )
                  : DropdownButtonFormField<Clinician>(
                      value: _selectedClinician,
                      dropdownColor: const Color(0xFF16213E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color(0xFF4FC3F7)),
                        ),
                      ),
                      items: clinicians.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.fullLabel,
                              style: const TextStyle(
                                  color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedClinician = value);
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // ─── Dates ────────────────────────────────────────────────────
            _buildSection(
              title: 'Dates',
              icon: Icons.calendar_today,
              child: Column(
                children: [
                  _DateRow(
                    label: 'Date of Service',
                    value: _formatDate(_dateOfService),
                    onTap: () => _pickDate(isDelivery: false),
                    color: const Color(0xFF4FC3F7),
                  ),
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Expected Delivery',
                    value: _formatDate(_expectedDeliveryDate),
                    onTap: () => _pickDate(isDelivery: true),
                    color: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Foot Side ────────────────────────────────────────────────
            _buildSection(
              title: 'Foot Side',
              icon: Icons.swap_horiz,
              child: Row(
                children: FootSide.values.map((side) {
                  final labels = ['Left', 'Right', 'Bilateral'];
                  final isSelected = _footSide == side;
                  return Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _footSide = side;
                            // Reset partial foot if foot removed
                            if (side == FootSide.right) {
                              _isPartialFootLeft = false;
                            }
                            if (side == FootSide.left) {
                              _isPartialFootRight = false;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0F3460)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4FC3F7)
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            labels[side.index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Quantity ─────────────────────────────────────────────────
            _buildSection(
              title: 'Quantity',
              icon: Icons.numbers,
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_showLeftFoot)
                        Expanded(
                          child: _QuantitySelector(
                            label: 'Left',
                            value: _quantityLeft,
                            color: Colors.blue,
                            onChanged: (val) =>
                                setState(() => _quantityLeft = val),
                          ),
                        ),
                      if (_showLeftFoot && _showRightFoot)
                        const SizedBox(width: 16),
                      if (_showRightFoot)
                        Expanded(
                          child: _QuantitySelector(
                            label: 'Right',
                            value: _quantityRight,
                            color: Colors.orange,
                            onChanged: (val) =>
                                setState(() => _quantityRight = val),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style:
                                TextStyle(color: Colors.white54)),
                        Text(
                          _quantityLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Partial Foot ─────────────────────────────────────────────
            if (_showLeftFoot || _showRightFoot)
              _buildSection(
                title: 'Partial Foot',
                icon: Icons.accessibility_new,
                child: Column(
                  children: [
                    // Left foot partial
                    if (_showLeftFoot) ...[
                      _PartialFootRow(
                        label: 'Left Foot is Partial',
                        isChecked: _isPartialFootLeft,
                        toeCount: _toeFillerCountLeft,
                        onChanged: (val) => setState(
                            () => _isPartialFootLeft = val),
                        onToeCountChanged: (val) => setState(
                            () => _toeFillerCountLeft = val),
                      ),
                    ],

                    if (_showLeftFoot && _showRightFoot)
                      const SizedBox(height: 8),

                    // Right foot partial
                    if (_showRightFoot) ...[
                      _PartialFootRow(
                        label: 'Right Foot is Partial',
                        isChecked: _isPartialFootRight,
                        toeCount: _toeFillerCountRight,
                        onChanged: (val) => setState(
                            () => _isPartialFootRight = val),
                        onToeCountChanged: (val) => setState(
                            () => _toeFillerCountRight = val),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ─── Product Details ──────────────────────────────────────────
            _buildSection(
              title: 'Product Details',
              icon: Icons.inventory,
              child: Column(
                children: [
                  _buildField('Product Type', _productController,
                      hint: 'e.g. Diabetic Rebound'),
                  const SizedBox(height: 12),
                  _buildField('Materials', _materialsController,
                      hint: 'e.g. Microcel Puff 1/16"'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Special Instructions ─────────────────────────────────────
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
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Color(0xFF4FC3F7)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Submit Button ────────────────────────────────────────────
            if (_status == WorkOrderStatus.draft)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text(
                    'Submit to Lab',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4FC3F7)),
        ),
      ),
    );
  }

  Color _statusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.draft:
        return Colors.orange;
      case WorkOrderStatus.submitted:
        return Colors.blue;
      case WorkOrderStatus.inProgress:
        return Colors.purple;
      case WorkOrderStatus.completed:
        return Colors.green;
      case WorkOrderStatus.shipped:
        return const Color(0xFF4FC3F7);
    }
  }
}

// ─── Partial Foot Row ─────────────────────────────────────────────────────────
class _PartialFootRow extends StatelessWidget {
  final String label;
  final bool isChecked;
  final int toeCount;
  final Function(bool) onChanged;
  final Function(int) onToeCountChanged;

  const _PartialFootRow({
    required this.label,
    required this.isChecked,
    required this.toeCount,
    required this.onChanged,
    required this.onToeCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox row
        GestureDetector(
          onTap: () => onChanged(!isChecked),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isChecked
                      ? const Color(0xFF4FC3F7).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isChecked
                        ? const Color(0xFF4FC3F7)
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check,
                        color: Color(0xFF4FC3F7), size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isChecked ? Colors.white : Colors.white54,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        // Toe filler dropdown — only shows when checked
        if (isChecked) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 36),
              const Text(
                'Number of toe fillers:',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.4)),
                ),
                child: DropdownButton<int>(
                  value: toeCount,
                  dropdownColor: const Color(0xFF16213E),
                  underline: const SizedBox(),
                  style: const TextStyle(
                      color: Colors.orange, fontSize: 15),
                  items: List.generate(5, (i) => i + 1).map((n) {
                    return DropdownMenuItem(
                      value: n,
                      child: Text(
                        '$n toe${n > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) onToeCountChanged(val);
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Quantity Selector ────────────────────────────────────────────────────────
class _QuantitySelector extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Function(int) onChanged;

  const _QuantitySelector({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (value > 0) onChanged(value - 1);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.remove, color: color, size: 18),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (value < 9) onChanged(value + 1);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: color, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Date Row ─────────────────────────────────────────────────────────────────
class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color color;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.edit,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}