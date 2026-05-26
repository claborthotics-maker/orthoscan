import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../utils/input_formatters.dart';
import 'scan_selection_screen.dart';
import 'work_order_screen.dart';
import 'template_selection_screen.dart';

class PatientScreen extends StatefulWidget {
  final Patient patient;

  const PatientScreen({super.key, required this.patient});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final List<WorkOrder> _workOrders = [];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.patient.notes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveNotes() {
    widget.patient.notes = _notesController.text;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes saved')),
    );
  }

  void _startScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanSelectionScreen(patient: widget.patient),
      ),
    );
  }

  void _newWorkOrder() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TemplateSelectionScreen(
        patient: widget.patient,
        onTemplateSelected: (template) {
          final workOrder = template.toWorkOrder(
            patientId: widget.patient.id,
            clinicianName: '',
          );
          workOrder.name = template.name;
          setState(() {
            _workOrders.add(workOrder);
          });

          // Pop template screen then push work order
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkOrderScreen(
                workOrder: workOrder,
                patient: widget.patient,
                onSave: (wo) {
                  setState(() {
                    final index = _workOrders
                        .indexWhere((w) => w.id == wo.id);
                    if (index != -1) {
                      _workOrders[index] = wo;
                    }
                  });
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

  void _openWorkOrder(WorkOrder wo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderScreen(
          workOrder: wo,
          patient: widget.patient,
          onSave: (saved) {
            setState(() {
              final index =
                  _workOrders.indexWhere((w) => w.id == saved.id);
              if (index != -1) {
                _workOrders[index] = saved;
              }
            });
          },
        ),
      ),
    );
  }

  void _copyWorkOrder(WorkOrder wo) {
    final copy = wo.copyWith();
    setState(() {
      _workOrders.add(copy);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${wo.displayName}"'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openWorkOrder(copy),
        ),
      ),
    );
  }

  void _deleteWorkOrder(WorkOrder wo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Work Order',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${wo.displayName}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _workOrders.removeWhere((w) => w.id == wo.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Work order deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _renameWorkOrder(WorkOrder wo) {
    final controller = TextEditingController(text: wo.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Rename Work Order',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Work Order Name',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4FC3F7)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                wo.name = controller.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
            ),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final firstNameController =
        TextEditingController(text: widget.patient.firstName);
    final lastNameController =
        TextEditingController(text: widget.patient.lastName);
    final dobController =
        TextEditingController(text: widget.patient.dateOfBirth);
    final phoneController =
        TextEditingController(text: widget.patient.phone);
    final emailController =
        TextEditingController(text: widget.patient.email);
    final patientIdController =
        TextEditingController(text: widget.patient.patientId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Edit Patient',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('First Name', firstNameController),
              const SizedBox(height: 12),
              _buildField('Last Name', lastNameController),
              const SizedBox(height: 12),
              _buildField('Patient ID', patientIdController,
                  hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('Date of Birth', dobController,
                  hint: 'MM/DD/YYYY',
                  formatter: DobInputFormatter(),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildField('Phone', phoneController,
                  hint: '(555) 555-5555',
                  formatter: PhoneInputFormatter(),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('Email', emailController,
                  hint: 'email@example.com'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.patient.firstName =
                    firstNameController.text.trim();
                widget.patient.lastName =
                    lastNameController.text.trim();
                widget.patient.patientId =
                    patientIdController.text.trim();
                widget.patient.dateOfBirth =
                    dobController.text.trim();
                widget.patient.phone = phoneController.text.trim();
                widget.patient.email = emailController.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
            ),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputFormatter? formatter,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      inputFormatters: formatter != null ? [formatter] : [],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          widget.patient.fullName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── Patient Info Card ───────────────────────────────────────
            _SectionCard(
              title: 'Patient Info',
              icon: Icons.person,
              child: Column(
                children: [
                  _InfoRow('Name', widget.patient.fullName),
                  if (widget.patient.patientId.isNotEmpty)
                    _InfoRow('Patient ID', widget.patient.patientId),
                  _InfoRow(
                      'Date of Birth',
                      widget.patient.dateOfBirth.isEmpty
                          ? 'Not set'
                          : widget.patient.dateOfBirth),
                  _InfoRow(
                      'Phone',
                      widget.patient.phone.isEmpty
                          ? 'Not set'
                          : widget.patient.phone),
                  _InfoRow(
                      'Email',
                      widget.patient.email.isEmpty
                          ? 'Not set'
                          : widget.patient.email),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Scans ───────────────────────────────────────────────────
            _SectionCard(
              title: 'Scans',
              icon: Icons.radar,
              child: Column(
                children: [
                  if (widget.patient.scanFiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No scans yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ...widget.patient.scanFiles.map(
                      (f) => ListTile(
                        leading: const Icon(Icons.threed_rotation,
                            color: Color(0xFF4FC3F7)),
                        title: Text(
                          f.split('/').last,
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white),
                      label: const Text('Start New Scan',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3460),
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Clinical Notes ──────────────────────────────────────────
            _SectionCard(
              title: 'Clinical Notes',
              icon: Icons.note_alt,
              child: Column(
                children: [
                  TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Enter clinical notes here...',
                      hintStyle: TextStyle(color: Colors.white24),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFF4FC3F7)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saveNotes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3460),
                      ),
                      child: const Text('Save Notes',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Work Orders ─────────────────────────────────────────────
            _SectionCard(
              title: 'Work Orders',
              icon: Icons.assignment,
              child: Column(
                children: [
                  if (_workOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No work orders yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ..._workOrders.map(
                      (wo) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.assignment,
                              color: Color(0xFF4FC3F7)),
                          title: Text(
                            wo.displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${wo.statusLabel} · ${wo.quantityLabel}',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusChip(wo.status),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white38,
                                    size: 20),
                                color: const Color(0xFF16213E),
                                onSelected: (value) {
                                  if (value == 'open')
                                    _openWorkOrder(wo);
                                  if (value == 'rename')
                                    _renameWorkOrder(wo);
                                  if (value == 'copy')
                                    _copyWorkOrder(wo);
                                  if (value == 'delete')
                                    _deleteWorkOrder(wo);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Row(children: [
                                      Icon(Icons.open_in_new,
                                          color: Colors.white54,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Open',
                                          style: TextStyle(
                                              color: Colors.white)),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(children: [
                                      Icon(Icons.drive_file_rename_outline,
                                          color: Colors.white54,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Rename',
                                          style: TextStyle(
                                              color: Colors.white)),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: Row(children: [
                                      Icon(Icons.copy,
                                          color: Colors.white54,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Copy',
                                          style: TextStyle(
                                              color: Colors.white)),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete,
                                          color: Colors.red,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _openWorkOrder(wo),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _newWorkOrder,
                      icon: const Icon(Icons.add,
                          color: Colors.white),
                      label: const Text('New Work Order',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3460),
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(WorkOrderStatus status) {
    Color color;
    switch (status) {
      case WorkOrderStatus.draft:
        color = Colors.orange;
        break;
      case WorkOrderStatus.submitted:
        color = Colors.blue;
        break;
      case WorkOrderStatus.inProgress:
        color = Colors.purple;
        break;
      case WorkOrderStatus.completed:
        color = Colors.green;
        break;
      case WorkOrderStatus.shipped:
        color = const Color(0xFF4FC3F7);
        break;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.name,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

// ─── Reusable Section Card ────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}