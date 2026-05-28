import 'package:flutter/material.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';
import '../services/clinician_service.dart';

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
    _load();
  }

  Future<void> _load() async {
    await _clinicianService.load();
    if (mounted) setState(() {});
  }

  void _showClinicianDialog({Clinician? clinician}) {
    final nameController =
        TextEditingController(text: clinician?.name ?? '');
    final licenseController =
        TextEditingController(text: clinician?.licenseNumber ?? '');
    final isEditing = clinician != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(isEditing ? 'Edit Clinician' : 'Add Clinician',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField('Full Name', nameController),
            const SizedBox(height: 12),
            _buildField('License Number', licenseController,
                hint: 'Optional'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              if (isEditing) {
                clinician.name = nameController.text.trim();
                clinician.licenseNumber =
                    licenseController.text.trim();
                await _clinicianService.updateClinician(clinician);
              } else {
                final newClinician = Clinician(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  licenseNumber: licenseController.text.trim(),
                );
                await _clinicianService.addClinician(newClinician);
              }
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3460)),
            child: Text(isEditing ? 'Save' : 'Add',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClinicDialog(Clinician clinician, {Clinic? clinic}) {
    final nameController =
        TextEditingController(text: clinic?.name ?? '');
    final addressController =
        TextEditingController(text: clinic?.address ?? '');
    final cityController =
        TextEditingController(text: clinic?.city ?? '');
    final stateController =
        TextEditingController(text: clinic?.state ?? '');
    final zipController =
        TextEditingController(text: clinic?.zip ?? '');
    final phoneController =
        TextEditingController(text: clinic?.phone ?? '');
    final isEditing = clinic != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(isEditing ? 'Edit Clinic' : 'Add Clinic',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Clinic Name', nameController),
              const SizedBox(height: 12),
              _buildField('Address', addressController,
                  hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('City', cityController, hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('State', stateController,
                  hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('ZIP', zipController, hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('Phone', phoneController,
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
              if (nameController.text.isEmpty) return;
              if (isEditing) {
                clinic.name = nameController.text.trim();
                clinic.address = addressController.text.trim();
                clinic.city = cityController.text.trim();
                clinic.state = stateController.text.trim();
                clinic.zip = zipController.text.trim();
                clinic.phone = phoneController.text.trim();
                await _clinicianService.updateClinic(clinic);
              } else {
                final newClinic = Clinic(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  clinicianId: clinician.id,
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                  city: cityController.text.trim(),
                  state: stateController.text.trim(),
                  zip: zipController.text.trim(),
                  phone: phoneController.text.trim(),
                );
                await _clinicianService.addClinic(newClinic);
              }
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3460)),
            child: Text(isEditing ? 'Save' : 'Add',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteClinicianConfirm(Clinician clinician) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Clinician',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${clinician.name}" and all their clinics?',
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
              await _clinicianService.deleteClinician(clinician.id);
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
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

  void _deleteClinicConfirm(Clinic clinic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Clinic',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${clinic.name}"?',
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
              await _clinicianService.deleteClinic(clinic.id);
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Clinicians',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showClinicianDialog(),
                  icon: const Icon(Icons.add,
                      color: Colors.white, size: 18),
                  label: const Text('Add Clinician',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3460)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (clinicians.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'No clinicians yet.\nTap "Add Clinician" to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              ...clinicians.map((clinician) {
                final clinics = _clinicianService
                    .getClinicsForClinician(clinician.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: clinician.isDefault
                          ? const Color(0xFF4FC3F7)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clinician header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F3460),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.medical_services,
                                  color: Color(0xFF4FC3F7),
                                  size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(clinician.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 16)),
                                    if (clinician.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                                  0xFF4FC3F7)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                        ),
                                        child: const Text(
                                            'Default',
                                            style: TextStyle(
                                                color: Color(
                                                    0xFF4FC3F7),
                                                fontSize: 11)),
                                      ),
                                    ],
                                  ]),
                                  if (clinician.licenseNumber
                                      .isNotEmpty)
                                    Text(
                                        'Lic: ${clinician.licenseNumber}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white38),
                              color: const Color(0xFF16213E),
                              onSelected: (value) {
                                if (value == 'edit')
                                  _showClinicianDialog(
                                      clinician: clinician);
                                if (value == 'default')
                                  _clinicianService
                                      .setDefaultClinician(
                                          clinician.id)
                                      .then((_) =>
                                          setState(() {}));
                                if (value == 'delete')
                                  _deleteClinicianConfirm(
                                      clinician);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit',
                                        style: TextStyle(
                                            color: Colors.white))),
                                if (!clinician.isDefault)
                                  const PopupMenuItem(
                                      value: 'default',
                                      child: Text('Set as Default',
                                          style: TextStyle(
                                              color: Colors.white))),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(
                                            color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      // Clinics list
                      ...clinics.map((clinic) => ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Colors.white38, size: 20),
                            title: Text(clinic.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14)),
                            subtitle: clinic.fullAddress.isNotEmpty
                                ? Text(clinic.fullAddress,
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (clinic.isDefault)
                                  const Icon(Icons.star,
                                      color: Color(0xFF4FC3F7),
                                      size: 16),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white38,
                                      size: 18),
                                  color: const Color(0xFF16213E),
                                  onSelected: (value) {
                                    if (value == 'edit')
                                      _showClinicDialog(clinician,
                                          clinic: clinic);
                                    if (value == 'default')
                                      _clinicianService
                                          .setDefaultClinic(
                                              clinician.id, clinic.id)
                                          .then((_) =>
                                              setState(() {}));
                                    if (value == 'delete')
                                      _deleteClinicConfirm(clinic);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    if (!clinic.isDefault)
                                      const PopupMenuItem(
                                          value: 'default',
                                          child: Text(
                                              'Set as Default',
                                              style: TextStyle(
                                                  color:
                                                      Colors.white))),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete',
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                          )),

                      // Add clinic button
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextButton.icon(
                          onPressed: () =>
                              _showClinicDialog(clinician),
                          icon: const Icon(Icons.add,
                              color: Color(0xFF4FC3F7), size: 18),
                          label: const Text('Add Clinic',
                              style: TextStyle(
                                  color: Color(0xFF4FC3F7))),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}