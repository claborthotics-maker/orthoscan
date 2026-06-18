import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';
import '../utils/input_formatters.dart';
import 'patient_screen.dart';
import 'settings_screen.dart';
import 'work_order_screen.dart';
import '../services/database_service.dart';
import '../services/clinician_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Patient> _patients = [];
  final List<_WOWithPatient> _allWorkOrders = [];
  final _db = DatabaseService();
  int _selectedIndex = 0;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _woLoading = false;
  final _searchController = TextEditingController();
  final _clinicianService = ClinicianService();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final patients = await _db.getAllPatients();
    setState(() {
      _patients.clear();
      _patients.addAll(patients);
    });
  }

  Future<void> _loadAllWorkOrders() async {
    setState(() => _woLoading = true);
    final wos = await _db.getAllWorkOrders();
    final patients = await _db.getAllPatients();
    final patientMap = {for (final p in patients) p.id: p};
    setState(() {
      _allWorkOrders.clear();
      for (final wo in wos) {
        final p = patientMap[wo.patientId];
        if (p != null) _allWorkOrders.add(_WOWithPatient(wo, p));
      }
      _woLoading = false;
    });
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) _loadAllWorkOrders();
  }

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
        onSave: (patient) async {
          await _db.insertPatient(patient);
          setState(() => _patients.add(patient));
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

  void _confirmDeletePatient(Patient patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Patient',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${patient.fullName}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will permanently delete the patient and ALL their work orders. This cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
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
              Navigator.pop(context);
              await _db.deletePatient(patient.id);
              setState(() =>
                  _patients.removeWhere((p) => p.id == patient.id));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${patient.fullName} deleted')),
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

  void _showSessionSwitcher() {
    final clinicians = _clinicianService.all;
    if (clinicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No clinicians set up. Go to Settings first.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Clinician selectedClinician =
              _clinicianService.activeClinician ?? clinicians.first;
          final clinics = _clinicianService
              .getClinicsForClinician(selectedClinician.id);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Active Session',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Clinician',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                ...clinicians.map((c) => GestureDetector(
                      onTap: () =>
                          setSheetState(() => selectedClinician = c),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedClinician.id == c.id
                              ? const Color(0xFF0F3460)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedClinician.id == c.id
                                ? const Color(0xFF4FC3F7)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.person,
                              color: Color(0xFF4FC3F7), size: 18),
                          const SizedBox(width: 10),
                          Text(c.name,
                              style: TextStyle(
                                  color: selectedClinician.id == c.id
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: selectedClinician.id == c.id
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ]),
                      ),
                    )),
                const SizedBox(height: 16),
                const Text('Clinic',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                if (clinics.isEmpty)
                  const Text('No clinics added for this clinician',
                      style: TextStyle(color: Colors.white38))
                else
                  ...clinics.map((c) {
                    final isSelected =
                        _clinicianService.activeClinic?.id == c.id &&
                            selectedClinician.id ==
                                _clinicianService.activeClinician?.id;
                    return GestureDetector(
                      onTap: () {
                        _clinicianService.setActive(selectedClinician, c);
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0F3460)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4FC3F7)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFF4FC3F7), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                if (c.fullAddress.isNotEmpty)
                                  Text(c.fullAddress,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final clinics = _clinicianService
                          .getClinicsForClinician(selectedClinician.id);
                      _clinicianService.setActive(
                          selectedClinician,
                          clinics.isNotEmpty ? clinics.first : null);
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3460),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Text('Set Active Session',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: Colors.white54),
            selectedIcon: Icon(Icons.people, color: Colors.white),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.assignment, color: Colors.white),
            label: 'Work Orders',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addPatient,
              backgroundColor: const Color(0xFF0F3460),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('New Patient',
                  style: TextStyle(color: Colors.white)),
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
                  title: const Text('CL@B',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
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
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
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
                onPressed: () => setState(() => _isSearching = true),
              ),
              GestureDetector(
                onTap: _showSessionSwitcher,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services,
                          color: Color(0xFF4FC3F7), size: 14),
                      const SizedBox(width: 4),
                      Text(_clinicianService.activeLabel,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF4FC3F7), size: 14),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                  await _clinicianService.load();
                  setState(() {});
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
                '${_patients.length} patient${_patients.length == 1 ? "" : "s"}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        if (_isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                '${_filteredPatients.length} result${_filteredPatients.length == 1 ? "" : "s"}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                    _isSearching ? Icons.search_off : Icons.people_outline,
                    size: 80,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching ? 'No patients found' : 'No patients yet',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 18),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PatientScreen(patient: patient)),
                    ).then((_) => setState(() {})),
                    onDelete: () => _confirmDeletePatient(patient),
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
            title: const Text('Work Orders',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: _WOSearchDelegate(_allWorkOrders, _db),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        if (_woLoading)
          const SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4FC3F7))),
          )
        else if (_allWorkOrders.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.assignment_outlined,
                      size: 80, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No work orders yet',
                      style: TextStyle(color: Colors.white54, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Create a work order from a patient profile',
                      style: TextStyle(color: Colors.white38)),
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
                  final item = _allWorkOrders[index];
                  return _WorkOrderCard(
                    wo: item.wo,
                    patient: item.patient,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => WorkOrderScreen(
                                workOrder: item.wo,
                                patient: item.patient,
                                onSave: (wo) async {
                                  await _db.updateWorkOrder(wo);
                                },
                              )),
                    ).then((_) => _loadAllWorkOrders()),
                  );
                },
                childCount: _allWorkOrders.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── WO With Patient ──────────────────────────────────────────────────────────
class _WOWithPatient {
  final WorkOrder wo;
  final Patient patient;
  _WOWithPatient(this.wo, this.patient);
}

// ─── Patient Card ─────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PatientCard({
    required this.patient,
    required this.onTap,
    required this.onDelete,
  });

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
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      if (patient.patientId.isNotEmpty)
                        Text('ID: ${patient.patientId}',
                            style: const TextStyle(
                                color: Color(0xFF4FC3F7), fontSize: 12)),
                      Text(
                        patient.dateOfBirth.isEmpty
                            ? 'No DOB'
                            : 'DOB: ${patient.dateOfBirth}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      if (patient.scanFiles.isNotEmpty)
                        Text('${patient.scanFiles.length} scan(s)',
                            style: const TextStyle(
                                color: Color(0xFF4FC3F7), fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38),
                  color: const Color(0xFF16213E),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Patient',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Work Order Card ──────────────────────────────────────────────────────────
class _WorkOrderCard extends StatelessWidget {
  final WorkOrder wo;
  final Patient patient;
  final VoidCallback onTap;

  const _WorkOrderCard({
    required this.wo,
    required this.patient,
    required this.onTap,
  });

  Color _statusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.draft: return Colors.orange;
      case WorkOrderStatus.submitted: return Colors.blue;
      case WorkOrderStatus.inProgress: return Colors.purple;
      case WorkOrderStatus.completed: return Colors.green;
      case WorkOrderStatus.shipped: return const Color(0xFF4FC3F7);
    }
  }

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
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(wo.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _statusColor(wo.status).withOpacity(0.4)),
                ),
                child: Icon(Icons.assignment,
                    color: _statusColor(wo.status), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wo.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(patient.fullName,
                        style: const TextStyle(
                            color: Color(0xFF4FC3F7), fontSize: 13)),
                    Text(wo.quantityLabel,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(wo.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusColor(wo.status).withOpacity(0.4)),
                    ),
                    child: Text(wo.statusLabel,
                        style: TextStyle(
                            color: _statusColor(wo.status), fontSize: 11)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${wo.createdAt.month}/${wo.createdAt.day}/${wo.createdAt.year}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ]),
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
      title: const Text('New Patient',
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField('First Name', _firstNameController),
            const SizedBox(height: 12),
            _buildField('Last Name', _lastNameController),
            const SizedBox(height: 12),
            _buildField('Patient ID', _patientIdController, hint: 'Optional'),
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
              backgroundColor: const Color(0xFF0F3460)),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
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
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4FC3F7))),
      ),
    );
  }
}

// ─── WO Search Delegate ───────────────────────────────────────────────────────
class _WOSearchDelegate extends SearchDelegate<String> {
  final List<_WOWithPatient> allItems;
  final DatabaseService db;

  _WOSearchDelegate(this.allItems, this.db);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF16213E),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? allItems
        : allItems.where((item) =>
            item.patient.fullName.toLowerCase().contains(q) ||
            item.wo.displayName.toLowerCase().contains(q) ||
            item.wo.statusLabel.toLowerCase().contains(q)).toList();

    if (filtered.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Text('No work orders found',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1A1A2E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _WorkOrderCard(
            wo: item.wo,
            patient: item.patient,
            onTap: () {
              close(context, '');
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WorkOrderScreen(
                          workOrder: item.wo,
                          patient: item.patient,
                          onSave: (wo) async {
                            await db.updateWorkOrder(wo);
                          },
                        )),
              );
            },
          );
        },
      ),
    );
  }
}

