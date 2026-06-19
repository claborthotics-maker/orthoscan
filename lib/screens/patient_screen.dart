import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../services/database_service.dart';
import '../utils/input_formatters.dart';
import '../services/database_service.dart';
import 'scan_selection_screen.dart';
import 'work_order_screen.dart';

class PatientScreen extends StatefulWidget {
  final Patient patient;

  const PatientScreen({super.key, required this.patient});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final List<WorkOrder> _workOrders = [];
  final _notesController = TextEditingController();
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.patient.notes;
    _loadWorkOrders();
  }

  Future<void> _loadWorkOrders() async {
    final orders = await _db.getWorkOrdersForPatient(widget.patient.id);
    if (mounted) {
      setState(() {
        _workOrders.clear();
        _workOrders.addAll(orders);
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    widget.patient.notes = _notesController.text;
    await _db.updatePatient(widget.patient);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Select Template',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _TemplateSheetContent(
                onTemplateSelected: (template) async {
                  Navigator.pop(sheetContext);
                  final workOrder = template.toWorkOrder(
                    patientId: widget.patient.id,
                    clinicianName: '',
                  );
                  // name comes from template.toWorkOrder() — don't blank it
                  await _db.insertWorkOrder(workOrder);
                  await Future.delayed(
                      const Duration(milliseconds: 300));
                  if (!mounted) return;
                  setState(() => _workOrders.insert(0, workOrder));
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkOrderScreen(
                        workOrder: workOrder,
                        patient: widget.patient,
                        onSave: (wo) async {
                          await _db.updateWorkOrder(wo);
                          if (mounted) {
                            setState(() {
                              final index = _workOrders
                                  .indexWhere((w) => w.id == wo.id);
                              if (index != -1)
                                _workOrders[index] = wo;
                            });
                          }
                        },
                      ),
                    ),
                  );
                  if (mounted) _loadWorkOrders();
                },
              ),
            ),
          ],
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
          onSave: (saved) async {
            await _db.updateWorkOrder(saved);
            if (mounted) {
              setState(() {
                final index =
                    _workOrders.indexWhere((w) => w.id == saved.id);
                if (index != -1) _workOrders[index] = saved;
              });
            }
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
    _db.insertWorkOrder(copy);
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
            onPressed: () async {
              await _db.deleteWorkOrder(wo.id);
              setState(() {
                _workOrders.removeWhere((w) => w.id == wo.id);
              });
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Work order deleted')),
                );
              }
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
            onPressed: () async {
              setState(() {
                wo.name = controller.text.trim();
              });
              await _db.updateWorkOrder(wo);
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
            onPressed: () async {
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
              await _db.updatePatient(widget.patient);
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

            // â”€â”€â”€ Patient Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionCard(
              title: 'Patient Info',
              icon: Icons.person,
              child: Column(
                children: [
                  _InfoRow('Name', widget.patient.fullName),
                  if (widget.patient.patientId.isNotEmpty)
                    _InfoRow('Patient ID', widget.patient.patientId),
                  _InfoRow('Date of Birth',
                      widget.patient.dateOfBirth.isEmpty
                          ? 'Not set'
                          : widget.patient.dateOfBirth),
                  _InfoRow('Phone',
                      widget.patient.phone.isEmpty
                          ? 'Not set'
                          : widget.patient.phone),
                  _InfoRow('Email',
                      widget.patient.email.isEmpty
                          ? 'Not set'
                          : widget.patient.email),
                ],
              ),
            ),

            const SizedBox(height: 16),

         // ─── Scans (Coming Soon) ─────────────────────────────
              Opacity(
                opacity: 0.5,
                child: IgnorePointer(
                  child: _SectionCard(
                    title: 'Scans',
                    icon: Icons.radar,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Coming Soon',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No scans yet',
                              style: TextStyle(color: Colors.white54)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: null,
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
                ),
              ),
              
            const SizedBox(height: 16),

            // â”€â”€â”€ Clinical Notes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                        borderSide: BorderSide(color: Colors.white24),
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

            // â”€â”€â”€ Work Orders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionCard(
              title: 'Work Orders',
              icon: Icons.assignment,
              child: Column(
                children: [
                  if (_workOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No work orders yet',
                          style: TextStyle(color: Colors.white54)),
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
                          title: Text(wo.displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              '${_typeName(wo.templateType)} · ${wo.quantityLabel}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusChip(wo.status),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white38, size: 20),
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
                                      Icon(
                                          Icons
                                              .drive_file_rename_outline,
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
                                          color: Colors.red, size: 18),
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
                      icon: const Icon(Icons.add, color: Colors.white),
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

  String _typeName(TemplateType? type) {
    switch (type) {
      case TemplateType.rebound: return 'Rebound';
      case TemplateType.polyShell: return 'Poly Shell';
      case TemplateType.partialFoot: return 'Partial Foot';
      case null: return 'No Type Set';
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(status.name,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// â”€â”€â”€ Section Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
}

// â”€â”€â”€ Info Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Template Sheet Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TemplateSheetContent extends StatefulWidget {
  final Function(WorkOrderTemplate) onTemplateSelected;

  const _TemplateSheetContent({required this.onTemplateSelected});

  @override
  State<_TemplateSheetContent> createState() =>
      _TemplateSheetContentState();
}

class _TemplateSheetContentState extends State<_TemplateSheetContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<WorkOrderTemplate> _templates = DefaultTemplates.getAll();
  final _db = DatabaseService();
  bool _loadingCustom = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomTemplates();
  }

Future<void> _loadCustomTemplates() async {
    final custom = await _db.getCustomTemplates();    for (final t in custom) {    }
    if (mounted) {
      setState(() {
        _templates.addAll(custom);
        _loadingCustom = false;
      });
    }
  }

  Future<void> _deleteCustomTemplate(WorkOrderTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Template', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${template.name}"? This cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteTemplate(template.id);
      setState(() => _templates.removeWhere((t) => t.id == template.id));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WorkOrderTemplate> _filterByType(TemplateType type) =>
      _templates.where((t) => t.templateType == type).toList();

  Color _typeColor(TemplateType type) {
    switch (type) {
      case TemplateType.rebound:
        return Colors.blue;
      case TemplateType.polyShell:
        return Colors.purple;
      case TemplateType.partialFoot:
        return Colors.orange;
    }
  }

  IconData _typeIcon(TemplateType type) {
    switch (type) {
      case TemplateType.rebound:
        return Icons.layers;
      case TemplateType.polyShell:
        return Icons.view_in_ar;
      case TemplateType.partialFoot:
        return Icons.accessibility_new;
    }
  }

  Widget _buildList(List<WorkOrderTemplate> templates) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final t = templates[index];
        final color = _typeColor(t.templateType);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => widget.onTemplateSelected(t),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: color.withOpacity(0.4)),
                    ),
                    child: Icon(_typeIcon(t.templateType),
                        color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       Row(children: [
                            Text(t.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            if (t.isCustom) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4FC3F7).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Custom',
                                    style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10)),
                              ),
                            ],
                          ]),
                        const SizedBox(height: 4),
                        Text(t.description,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                if (t.isCustom)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _deleteCustomTemplate(t),
                      )
                    else
                      const Icon(Icons.chevron_right,
                          color: Colors.white38),
                  ]),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF4FC3F7),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        tabs: const [
          Tab(text: 'Rebound'),
          Tab(text: 'Poly Shell'),
          Tab(text: 'Partial Foot'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildList(_filterByType(TemplateType.rebound)),
            _buildList(_filterByType(TemplateType.polyShell)),
            _buildList(_filterByType(TemplateType.partialFoot)),
          ],
        ),
      ),
    ]);
  }
}

