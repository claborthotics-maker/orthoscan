import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/work_order.dart';

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
  final _clinicianController = TextEditingController();
  final _clinicController = TextEditingController();
  final _productController = TextEditingController();
  final _materialsController = TextEditingController();
  final _instructionsController = TextEditingController();

  late FootSide _footSide;
  late WorkOrderStatus _status;

  @override
  void initState() {
    super.initState();
    _clinicianController.text = widget.workOrder.clinicianName;
    _clinicController.text = widget.workOrder.clinicName;
    _productController.text = widget.workOrder.productType;
    _materialsController.text = widget.workOrder.materials;
    _instructionsController.text = widget.workOrder.specialInstructions;
    _footSide = widget.workOrder.footSide;
    _status = widget.workOrder.status;
  }

  @override
  void dispose() {
    _clinicianController.dispose();
    _clinicController.dispose();
    _productController.dispose();
    _materialsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _save() {
    widget.workOrder.clinicianName = _clinicianController.text;
    widget.workOrder.clinicName = _clinicController.text;
    widget.workOrder.productType = _productController.text;
    widget.workOrder.materials = _materialsController.text;
    widget.workOrder.specialInstructions = _instructionsController.text;
    widget.workOrder.footSide = _footSide;
    widget.workOrder.status = _status;
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

  @override
  Widget build(BuildContext context) {
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
                  if (widget.patient.dateOfBirth.isNotEmpty)
                    Text(
                      'DOB: ${widget.patient.dateOfBirth}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Clinician Info ───────────────────────────────────────────
            _buildSection(
              title: 'Clinician',
              icon: Icons.medical_services,
              child: Column(
                children: [
                  _buildField('Clinician Name', _clinicianController),
                  const SizedBox(height: 12),
                  _buildField('Clinic Name', _clinicController),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _footSide = side),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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

            // ─── Product Details ──────────────────────────────────────────
            _buildSection(
              title: 'Product Details',
              icon: Icons.inventory,
              child: Column(
                children: [
                  _buildField('Product Type', _productController,
                      hint: 'e.g. Custom Diabetic Insert'),
                  const SizedBox(height: 12),
                  _buildField('Materials', _materialsController,
                      hint: 'e.g. EVA, Poron'),
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
                  hintText: 'Enter any special instructions for the lab...',
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