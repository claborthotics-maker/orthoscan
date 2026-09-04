import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';
import '../services/clinician_service.dart';
import 'tutorial_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _clinicianService = ClinicianService();
  int _step = 0;

  // Clinician info
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();

  // Multiple clinics
  final List<_ClinicForm> _clinicForms = [_ClinicForm()];

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    for (final f in _clinicForms) { f.dispose(); }
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your full name.');
        return;
      }
      setState(() => _step = 1);
    } else {
      _submit();
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Required', style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Validate all clinic forms
    for (int i = 0; i < _clinicForms.length; i++) {
      final f = _clinicForms[i];
      final errors = <String>[];
      if (f.nameController.text.trim().isEmpty) errors.add('• Clinic name');
      if (f.addressController.text.trim().isEmpty) errors.add('• Address');
      if (f.cityController.text.trim().isEmpty) errors.add('• City');
      if (f.stateController.text.trim().isEmpty) errors.add('• State');
      if (f.zipController.text.trim().length < 5) errors.add('• ZIP code (5 digits)');
      if (f.phoneController.text.replaceAll(RegExp(r'\D'), '').length < 10) errors.add('• Phone (10 digits)');
      if (errors.isNotEmpty) {
        _showError('Clinic ${i + 1} is missing:\n${errors.join('\n')}');
        return;
      }
    }

    final clinician = Clinician(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );
    await _clinicianService.addClinician(clinician);

    for (final f in _clinicForms) {
      final clinic = Clinic(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_${_clinicForms.indexOf(f)}',
        clinicianId: clinician.id,
        name: f.nameController.text.trim(),
        address: f.addressController.text.trim(),
        city: f.cityController.text.trim(),
        state: f.stateController.text.trim(),
        zip: f.zipController.text.trim(),
        phone: f.phoneController.text.trim(),
      );
      await _clinicianService.addClinic(clinic);
    }

    _clinicianService.setActive(clinician, _clinicianService.getClinicsForClinician(clinician.id).first);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TutorialScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text('Welcome to CL@B',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _step == 0 ? 'Tell us about yourself' : 'Set up your clinic(s)',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 32),

              if (_step == 0) ...[
                _buildField('Full Name *', _nameController),
                const SizedBox(height: 16),
                _buildField('License Number', _licenseController, hint: 'Optional'),
              ] else ...[
                ...List.generate(_clinicForms.length, (i) {
                  final f = _clinicForms[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_clinicForms.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Clinic ${i + 1}',
                                style: const TextStyle(color: Color(0xFF4FC3F7),
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            if (i > 0)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => setState(() => _clinicForms.removeAt(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildField('Clinic Name *', f.nameController),
                      const SizedBox(height: 12),
                      _buildField('Address *', f.addressController),
                      const SizedBox(height: 12),
                      _buildField('City *', f.cityController),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildField('State *', f.stateController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('ZIP *', f.zipController,
                            maxLength: 5, inputType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 12),
                      _buildPhoneField('Phone *', f.phoneController),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
                TextButton.icon(
                  onPressed: () => setState(() => _clinicForms.add(_ClinicForm())),
                  icon: const Icon(Icons.add, color: Color(0xFF4FC3F7)),
                  label: const Text('Add Another Clinic',
                      style: TextStyle(color: Color(0xFF4FC3F7))),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_step == 0 ? 'Next' : 'Get Started',
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {String? hint, int? maxLength, TextInputType? inputType}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
      ),
    );
  }

  Widget _buildPhoneField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLength: 12,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white),
      inputFormatters: [PhoneInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'xxx-xxx-xxxx',
        counterText: '',
        hintStyle: const TextStyle(color: Colors.white24),
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
      ),
    );
  }
}

class _ClinicForm {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final zipController = TextEditingController();
  final phoneController = TextEditingController();

  void dispose() {
    nameController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipController.dispose();
    phoneController.dispose();
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
