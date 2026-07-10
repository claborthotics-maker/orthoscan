import 'package:flutter/material.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';
import '../services/clinician_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _clinicianService = ClinicianService();
  final _themeService = ThemeService();
  int _deliveryDays = 25;
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _clinicianService.load();
    _deliveryDays = _themeService.defaultDeliveryDays;
    _isDark = _themeService.isDark;
    if (mounted) setState(() {});
  }

  void _showClinicianDialog({Clinician? clinician}) {
    final nameController = TextEditingController(text: clinician?.name ?? '');
    final licenseController = TextEditingController(text: clinician?.licenseNumber ?? '');
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
            _buildField('License Number', licenseController, hint: 'Optional'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              if (isEditing) {
                clinician.name = name;
                clinician.licenseNumber = licenseController.text.trim();
                await _clinicianService.updateClinician(clinician);
              } else {
                final newClinician = Clinician(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  licenseNumber: licenseController.text.trim(),
                );
                await _clinicianService.addClinician(newClinician);
              }
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClinicDialog({required String clinicianId, Clinic? clinic}) {
    final nameController = TextEditingController(text: clinic?.name ?? '');
    final addressController = TextEditingController(text: clinic?.address ?? '');
    final cityController = TextEditingController(text: clinic?.city ?? '');
    final stateController = TextEditingController(text: clinic?.state ?? '');
    final zipController = TextEditingController(text: clinic?.zip ?? '');
    final phoneController = TextEditingController(text: clinic?.phone ?? '');
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
              _buildField('Address', addressController, hint: 'Optional'),
              const SizedBox(height: 12),
              _buildField('City', cityController, hint: 'Optional'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildField('State', stateController, hint: 'Optional')),
                const SizedBox(width: 8),
                Expanded(child: _buildField('ZIP', zipController, hint: 'Optional')),
              ]),
              const SizedBox(height: 12),
              _buildField('Phone', phoneController, hint: 'Optional'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              if (isEditing) {
                clinic.name = name;
                clinic.address = addressController.text.trim();
                clinic.city = cityController.text.trim();
                clinic.state = stateController.text.trim();
                clinic.zip = zipController.text.trim();
                clinic.phone = phoneController.text.trim();
                await _clinicianService.updateClinic(clinic);
              } else {
                final newClinic = Clinic(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  clinicianId: clinicianId,
                  name: name,
                  address: addressController.text.trim(),
                  city: cityController.text.trim(),
                  state: stateController.text.trim(),
                  zip: zipController.text.trim(),
                  phone: phoneController.text.trim(),
                );
                await _clinicianService.addClinic(newClinic);
              }
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteClinician(Clinician clinician) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Clinician', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${clinician.name}? This will also delete all their clinics.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinicianService.deleteClinician(clinician.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmDeleteClinic(Clinic clinic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Clinic', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${clinic.name}?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinicianService.deleteClinic(clinic.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicians = _clinicianService.all;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Settings Section
            const Text('App Settings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dark Mode', style: TextStyle(color: Colors.white, fontSize: 15)),
                    Switch(
                      value: _isDark,
                      activeColor: const Color(0xFF4FC3F7),
                      onChanged: (v) async {
                        await _themeService.setDarkMode(v);
                        setState(() => _isDark = v);
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Default Delivery Days', style: TextStyle(color: Colors.white, fontSize: 15)),
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Color(0xFF4FC3F7)),
                        onPressed: () async {
                          if (_deliveryDays > 1) {
                            await _themeService.setDefaultDeliveryDays(_deliveryDays - 1);
                            setState(() => _deliveryDays--);
                          }
                        },
                      ),
                      Text('$_deliveryDays days', style: const TextStyle(color: Colors.white, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF4FC3F7)),
                        onPressed: () async {
                          await _themeService.setDefaultDeliveryDays(_deliveryDays + 1);
                          setState(() => _deliveryDays++);
                        },
                      ),
                    ]),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Clinicians Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Clinicians',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showClinicianDialog(),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('Add Clinician', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
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
                final clinics = _clinicianService.getClinicsForClinician(clinician.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clinician.name,
                                      style: const TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (clinician.licenseNumber.isNotEmpty)
                                    Text('License: ${clinician.licenseNumber}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                              onPressed: () => _showClinicianDialog(clinician: clinician),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => _confirmDeleteClinician(clinician),
                            ),
                          ],
                        ),
                      ),
                      if (clinics.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 1),
                        ...clinics.map((clinic) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF4FC3F7), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(clinic.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    if (clinic.fullAddress.isNotEmpty)
                                      Text(clinic.fullAddress,
                                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white54, size: 16),
                                onPressed: () => _showClinicDialog(clinicianId: clinician.id, clinic: clinic),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                onPressed: () => _confirmDeleteClinic(clinic),
                              ),
                            ],
                          ),
                        )),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: TextButton.icon(
                          onPressed: () => _showClinicDialog(clinicianId: clinician.id),
                          icon: const Icon(Icons.add, color: Color(0xFF4FC3F7), size: 16),
                          label: const Text('Add Clinic', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 13)),
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
}

