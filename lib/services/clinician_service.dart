import '../models/clinician.dart';
import '../models/clinic.dart';
import 'database_service.dart';

class ClinicianService {
  static final ClinicianService _instance = ClinicianService._internal();
  factory ClinicianService() => _instance;
  ClinicianService._internal();

  final _db = DatabaseService();
  List<Clinician> _clinicians = [];
  List<Clinic> _clinics = [];

  // Active session
  Clinician? _activeClinician;
  Clinic? _activeClinic;

  Clinician? get activeClinician => _activeClinician;
  Clinic? get activeClinic => _activeClinic;

  String get activeLabel {
    if (_activeClinician == null) return 'No clinician set';
    if (_activeClinic == null) return _activeClinician!.name;
    final firstName = _activeClinician!.name.split(' ').first;
    final clinicName = _activeClinic!.name.length > 12 
        ? _activeClinic!.name.substring(0, 12) + '...' 
        : _activeClinic!.name;
    return '$firstName @ $clinicName';
  }

  Future<void> load() async {
    _clinicians = await _db.getAllClinicians();
    _clinics = await _db.getAllClinics();

    // Set active clinician to default
    if (_activeClinician == null && _clinicians.isNotEmpty) {
      try {
        _activeClinician =
            _clinicians.firstWhere((c) => c.isDefault);
      } catch (_) {
        _activeClinician = _clinicians.first;
      }
    }

    // Set active clinic to default for active clinician
    if (_activeClinician != null && _activeClinic == null) {
      final clinicianClinics = getClinicsForClinician(_activeClinician!.id);
      if (clinicianClinics.isNotEmpty) {
        try {
          _activeClinic =
              clinicianClinics.firstWhere((c) => c.isDefault);
        } catch (_) {
          _activeClinic = clinicianClinics.first;
        }
      }
    }
  }

  void setActive(Clinician clinician, Clinic? clinic) {
    _activeClinician = clinician;
    _activeClinic = clinic;
  }

  List<Clinician> get all => List.unmodifiable(_clinicians);

  List<Clinic> getClinicsForClinician(String clinicianId) =>
      _clinics.where((c) => c.clinicianId == clinicianId).toList();

  List<Clinic> get allClinics => List.unmodifiable(_clinics);

  Clinician? get defaultClinician {
    try {
      return _clinicians.firstWhere((c) => c.isDefault);
    } catch (_) {
      return _clinicians.isNotEmpty ? _clinicians.first : null;
    }
  }

  bool get isEmpty => _clinicians.isEmpty;
  bool get isNotEmpty => _clinicians.isNotEmpty;

  // â”€â”€â”€ Clinician CRUD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> addClinician(Clinician clinician) async {
    if (_clinicians.isEmpty) clinician.isDefault = true;
    await _db.insertClinician(clinician);
    _clinicians.add(clinician);
    if (_activeClinician == null) _activeClinician = clinician;
  }

  Future<void> updateClinician(Clinician clinician) async {
    await _db.updateClinician(clinician);
    final index = _clinicians.indexWhere((c) => c.id == clinician.id);
    if (index != -1) _clinicians[index] = clinician;
    if (_activeClinician?.id == clinician.id) {
      _activeClinician = clinician;
    }
  }

  Future<void> deleteClinician(String id) async {
    await _db.deleteClinician(id);
    _clinicians.removeWhere((c) => c.id == id);
    _clinics.removeWhere((c) => c.clinicianId == id);
    if (_activeClinician?.id == id) {
      _activeClinician =
          _clinicians.isNotEmpty ? _clinicians.first : null;
      _activeClinic = null;
    }
  }

  Future<void> setDefaultClinician(String id) async {
    await _db.setDefaultClinician(id);
    for (final c in _clinicians) {
      c.isDefault = c.id == id;
    }
  }

  // â”€â”€â”€ Clinic CRUD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> addClinic(Clinic clinic) async {
    final existing = getClinicsForClinician(clinic.clinicianId);
    if (existing.isEmpty) clinic.isDefault = true;
    await _db.insertClinic(clinic);
    _clinics.add(clinic);
    if (_activeClinician?.id == clinic.clinicianId &&
        _activeClinic == null) {
      _activeClinic = clinic;
    }
  }

  Future<void> updateClinic(Clinic clinic) async {
    await _db.updateClinic(clinic);
    final index = _clinics.indexWhere((c) => c.id == clinic.id);
    if (index != -1) _clinics[index] = clinic;
    if (_activeClinic?.id == clinic.id) _activeClinic = clinic;
  }

  Future<void> deleteClinic(String id) async {
    await _db.deleteClinic(id);
    _clinics.removeWhere((c) => c.id == id);
    if (_activeClinic?.id == id) _activeClinic = null;
  }

  Future<void> setDefaultClinic(
      String clinicianId, String clinicId) async {
    await _db.setDefaultClinic(clinicianId, clinicId);
    for (final c in _clinics) {
      if (c.clinicianId == clinicianId) {
        c.isDefault = c.id == clinicId;
      }
    }
  }

  // Legacy getters for compatibility
  List<Clinician> get clinicians => all;
  Future<void> add(Clinician clinician) => addClinician(clinician);
  Future<void> update(Clinician clinician) => updateClinician(clinician);
  Future<void> delete(String id) => deleteClinician(id);
  Future<void> setDefault(String id) => setDefaultClinician(id);
}
