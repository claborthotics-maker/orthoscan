import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import 'scan_screen.dart';
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

  void _newWorkOrder() {
    final workOrder = WorkOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: widget.patient.id,
      createdAt: DateTime.now(),
      clinicianName: '',
      clinicName: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderScreen(
          workOrder: workOrder,
          patient: widget.patient,
          onSave: (wo) {
            setState(() {
              _workOrders.add(wo);
            });
          },
        ),
      ),
    );
  }

  void _startScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(patient: widget.patient),
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
            onPressed: () {},
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

            // ─── Scan Button ─────────────────────────────────────────────
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
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
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

            // ─── Notes ───────────────────────────────────────────────────
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
                        borderSide: BorderSide(color: Color(0xFF4FC3F7)),
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
                      (wo) => ListTile(
                        leading: const Icon(Icons.assignment,
                            color: Color(0xFF4FC3F7)),
                        title: Text(
                          wo.productType.isEmpty
                              ? 'Work Order'
                              : wo.productType,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          wo.statusLabel,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkOrderScreen(
                                workOrder: wo,
                                patient: widget.patient,
                                onSave: (_) {},
                              ),
                            ),
                          );
                        },
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
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}