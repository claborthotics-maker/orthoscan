import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clinician.dart';
import '../services/clinician_service.dart';
import '../utils/input_formatters.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _clinicianService = ClinicianService();

@override
void initState() {
  super.initState();
  _loadClinicians();
}

Future<void> _loadClinicians() async {
  await _clinicianService.load();
  setState(() {});
}

  void _addClinician() {
    _showClinicianDialog();
  }

  void _editClinician(Clinician clinician) {
    _showClinicianDialog(clinician: clinician);
  }

  void _deleteClinician(Clinician clinician) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Clinician',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${clinician.fullLabel}?',
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
  await _clinicianService.delete(clinician.id);
  setState(() {});
  Navigator.pop(context);
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

  void _showClinicianDialog({Clinician? clinician}) {
    final isEditing = clinician != null;
    final nameController =
        TextEditingController(text: clinician?.name ?? '');
    final clinicController =
        TextEditingController(text: clinician?.clinicName ?? '');
    final addressController =
        TextEditingController(text: clinician?.address ?? '');
    final cityController =
        TextEditingController(text: clinician?.city ?? '');
    final stateController =
        TextEditingController(text: clinician?.state ?? '');
    final zipController =
        TextEditingController(text: clinician?.zip ?? '');
    final phoneController =
        TextEditingController(text: clinician?.phone ?? '');
    final emailController =
        TextEditingController(text: clinician?.email ?? '');
    final licenseController =
        TextEditingController(text: clinician?.licenseNumber ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          isEditing ? 'Edit Clinician' : 'New Clinician',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Clinician Name', nameController),
              const SizedBox(height: 12),
              _buildField('Clinic / Business Name', clinicController),
              const SizedBox(height: 12),
              _buildField('Clinic Address', addressController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildField('City', cityController)),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 60,
                      child:
                          _buildField('State', stateController)),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 80,
                      child: _buildField('ZIP', zipController)),
                ],
              ),
              const SizedBox(height: 12),
              _buildField('Phone', phoneController,
                  hint: '(555) 555-5555',
                  formatter: PhoneInputFormatter(),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('Email', emailController,
                  hint: 'email@clinic.com'),
              const SizedBox(height: 12),
              _buildField('License Number', licenseController,
                  hint: 'Optional'),
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
  if (nameController.text.isEmpty ||
      clinicController.text.isEmpty) return;

  if (isEditing) {
                clinician!.name = nameController.text.trim();
                clinician.clinicName = clinicController.text.trim();
                clinician.address = addressController.text.trim();
                clinician.city = cityController.text.trim();
                clinician.state = stateController.text.trim();
                clinician.zip = zipController.text.trim();
                clinician.phone = phoneController.text.trim();
                clinician.email = emailController.text.trim();
                clinician.licenseNumber =
                    licenseController.text.trim();
                await _clinicianService.update(clinician);
              } else {
                final newClinician = Clinician(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  name: nameController.text.trim(),
                  clinicName: clinicController.text.trim(),
                  address: addressController.text.trim(),
                  city: cityController.text.trim(),
                  state: stateController.text.trim(),
                  zip: zipController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  licenseNumber: licenseController.text.trim(),
                );
                await _clinicianService.add(newClinician);
              }

              setState(() {});
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
    final clinicians = _clinicianService.all;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Settings',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── Clinician Profiles ───────────────────────────────────────
            Container(
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
                      const Icon(Icons.badge,
                          color: Color(0xFF4FC3F7), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Clinician Profiles',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addClinician,
                        icon: const Icon(Icons.add,
                            color: Color(0xFF4FC3F7), size: 18),
                        label: const Text('Add',
                            style: TextStyle(
                                color: Color(0xFF4FC3F7))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (clinicians.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No clinician profiles yet.\nTap Add to create one.',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...clinicians.map((clinician) =>
                        _ClinicianCard(
                          clinician: clinician,
                          onEdit: () => _editClinician(clinician),
                          onDelete: () =>
                              _deleteClinician(clinician),
                          onSetDefault: () async {
  await _clinicianService.setDefault(clinician.id);
  setState(() {});
},
                        )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── App Info ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF4FC3F7), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'App Info',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('App', 'OrthoScan'),
                  _infoRow('Version', '1.0.0'),
                  _infoRow('Build', 'Beta'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClinician,
        backgroundColor: const Color(0xFF0F3460),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Clinician',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Clinician Card ───────────────────────────────────────────────────────────
class _ClinicianCard extends StatelessWidget {
  final Clinician clinician;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _ClinicianCard({
    required this.clinician,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: clinician.isDefault
              ? const Color(0xFF4FC3F7).withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0F3460),
                radius: 20,
                child: Text(
                  clinician.name.isNotEmpty
                      ? clinician.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          clinician.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (clinician.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4FC3F7)
                                  .withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF4FC3F7)
                                      .withOpacity(0.4)),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xFF4FC3F7),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      clinician.clinicName,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    if (clinician.shippingAddress.isNotEmpty)
                      Text(
                        clinician.shippingAddress,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    if (clinician.phone.isNotEmpty)
                      Text(
                        clinician.phone,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: Colors.white54),
                color: const Color(0xFF16213E),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'default') onSetDefault();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit,
                            color: Colors.white54, size: 18),
                        SizedBox(width: 8),
                        Text('Edit',
                            style:
                                TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  if (!clinician.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.star,
                              color: Colors.white54, size: 18),
                          SizedBox(width: 8),
                          Text('Set as Default',
                              style: TextStyle(
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete,
                            color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}