import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../utils/input_formatters.dart';
import 'patient_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Patient> _patients = [];
  int _selectedIndex = 0;
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Patient> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    final query = _searchQuery.toLowerCase();
    return _patients.where((p) {
      return p.fullName.toLowerCase().contains(query) ||
          p.patientId.toLowerCase().contains(query) ||
          p.phone.toLowerCase().contains(query);
    }).toList();
  }

  void _addPatient() {
    showDialog(
      context: context,
      builder: (context) => _NewPatientDialog(
        onSave: (patient) {
          setState(() {
            _patients.add(patient);
          });
        },
      ),
    );
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _selectedIndex == 0
          ? _buildPatientList()
          : _buildWorkOrdersView(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF16213E),
        indicatorColor: const Color(0xFF0F3460),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: Colors.white54),
            selectedIcon: Icon(Icons.people, color: Colors.white),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined,
                color: Colors.white54),
            selectedIcon:
                Icon(Icons.assignment, color: Colors.white),
            label: 'Work Orders',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addPatient,
              backgroundColor: const Color(0xFF0F3460),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'New Patient',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildPatientList() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF16213E),
          expandedHeight: _isSearching ? 0 : 120,
          pinned: true,
          flexibleSpace: _isSearching
              ? null
              : FlexibleSpaceBar(
                  title: const Text(
                    'OrthoScan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF16213E),
                          Color(0xFF0F3460)
                        ],
                      ),
                    ),
                  ),
                ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or patient ID...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
              : null,
          actions: [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _stopSearch,
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() => _isSearching = true);
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings,
                    color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),

        if (!_isSearching && _patients.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                '${_patients.length} patient${_patients.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ),
          ),

        if (_isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                '${_filteredPatients.length} result${_filteredPatients.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ),
          ),

        if (_filteredPatients.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSearching
                        ? Icons.search_off
                        : Icons.people_outline,
                    size: 80,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'No patients found'
                        : 'No patients yet',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSearching
                        ? 'Try a different search term'
                        : 'Tap + New Patient to get started',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final patient = _filteredPatients[index];
                  return _PatientCard(
                    patient: patient,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientScreen(patient: patient),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  );
                },
                childCount: _filteredPatients.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkOrdersView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF16213E),
          expandedHeight: 120,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Work Orders',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16213E), Color(0xFF0F3460)],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.white24,
                ),
                SizedBox(height: 16),
                Text(
                  'No work orders yet',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Work orders appear here after scanning',
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Patient Card ─────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;

  const _PatientCard({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F3460),
                  radius: 28,
                  child: Text(
                    '${patient.firstName[0]}${patient.lastName[0]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (patient.patientId.isNotEmpty)
                        Text(
                          'ID: ${patient.patientId}',
                          style: const TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        patient.dateOfBirth.isEmpty
                            ? 'No DOB'
                            : 'DOB: ${patient.dateOfBirth}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      if (patient.scanFiles.isNotEmpty)
                        Text(
                          '${patient.scanFiles.length} scan(s)',
                          style: const TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── New Patient Dialog ───────────────────────────────────────────────────────
class _NewPatientDialog extends StatefulWidget {
  final Function(Patient) onSave;

  const _NewPatientDialog({required this.onSave});

  @override
  State<_NewPatientDialog> createState() => _NewPatientDialogState();
}

class _NewPatientDialogState extends State<_NewPatientDialog> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _patientIdController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: const Text(
        'New Patient',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField('First Name', _firstNameController),
            const SizedBox(height: 12),
            _buildField('Last Name', _lastNameController),
            const SizedBox(height: 12),
            _buildField('Patient ID', _patientIdController,
                hint: 'Optional'),
            const SizedBox(height: 12),
            _buildField('Date of Birth', _dobController,
                hint: 'MM/DD/YYYY',
                formatter: DobInputFormatter(),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildField('Phone', _phoneController,
                hint: '(555) 555-5555',
                formatter: PhoneInputFormatter(),
                keyboardType: TextInputType.phone),
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
            if (_firstNameController.text.isEmpty ||
                _lastNameController.text.isEmpty) return;

            final patient = Patient(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              patientId: _patientIdController.text.trim(),
              dateOfBirth: _dobController.text.trim(),
              phone: _phoneController.text.trim(),
              createdAt: DateTime.now(),
            );

            widget.onSave(patient);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3460),
          ),
          child: const Text('Save',
              style: TextStyle(color: Colors.white)),
        ),
      ],
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
}