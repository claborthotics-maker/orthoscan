import 'package:flutter/material.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';
import '../services/clinician_service.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _clinicianService = ClinicianService();
  int _step = 0;

  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _phoneController = TextEditingController();

  Clinician? _newClinician;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _clinicNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveClinicianAndContinue() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the clinician\'s name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final clinician = Clinician(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );
    await _clinicianService.addClinician(clinician);
    setState(() {
      _newClinician = clinician;
      _saving = false;
      _step = 1;
    });
  }

  Future<void> _saveClinicAndFinish() async {
    if (_clinicNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the clinic name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final clinic = Clinic(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clinicianId: _newClinician!.id,
      name: _clinicNameController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zip: _zipController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    await _clinicianService.addClinic(clinic);
    _clinicianService.setActive(_newClinician!, clinic);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TutorialScreen()),
      );
    }
  }

  void _skipClinic() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Welcome header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16213E), Color(0xFF0F3460)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.medical_services,
                      color: Color(0xFF4FC3F7), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome to CL@B',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _step == 0
                              ? "Let's set up your clinician profile"
                              : "Now let's add your clinic",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Step indicator
              Row(children: [
                _stepDot(0),
                Expanded(
                    child: Container(
                        height: 2,
                        color: _step >= 1
                            ? const Color(0xFF4FC3F7)
                            : Colors.white12)),
                _stepDot(1),
              ]),

              const SizedBox(height: 32),

              if (_step == 0) ..._buildClinicianStep(),
              if (_step == 1) ..._buildClinicStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepDot(int step) {
    final isActive = _step >= step;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? const Color(0xFF4FC3F7) : Colors.white12,
      ),
      child: Center(
        child: Text('${step + 1}',
            style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  List<Widget> _buildClinicianStep() {
    return [
      const Text('Clinician Information',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _buildField('Full Name', _nameController, hint: 'e.g. Dr. Jane Smith'),
      const SizedBox(height: 12),
      _buildField('License Number', _licenseController, hint: 'Optional'),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _saveClinicianAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3460),
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Continue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
        ),
      ),
    ];
  }

  List<Widget> _buildClinicStep() {
    return [
      const Text('Clinic Information',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _buildField('Clinic Name', _clinicNameController,
          hint: 'e.g. CL@B Orthotics'),
      const SizedBox(height: 12),
      _buildField('Address', _addressController, hint: 'Optional'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildField('City', _cityController, hint: 'Optional')),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: _buildField('State', _stateController, hint: 'Optional')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildField('ZIP', _zipController, hint: 'Optional')),
        const SizedBox(width: 12),
        Expanded(child: _buildField('Phone', _phoneController, hint: 'Optional')),
      ]),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _saveClinicAndFinish,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3460),
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Finish Setup',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _skipClinic,
          child: const Text('Skip for now',
              style: TextStyle(color: Colors.white38)),
        ),
      ),
    ];
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
}


