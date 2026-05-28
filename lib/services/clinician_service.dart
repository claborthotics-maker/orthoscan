import '../models/clinician.dart';
import 'database_service.dart';

class ClinicianService {
  static final ClinicianService _instance = ClinicianService._internal();
  factory ClinicianService() => _instance;
  ClinicianService._internal();

  final _db = DatabaseService();
  List<Clinician> _clinicians = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (!_loaded) {
      _clinicians = await _db.getAllClinicians();
      _loaded = true;
    }
  }

  Future<List<Clinician>> getAll() async {
    await _ensureLoaded();
    return List.unmodifiable(_clinicians);
  }

  List<Clinician> get all {
    return List.unmodifiable(_clinicians);
  }

  Clinician? get defaultClinician {
    try {
      return _clinicians.firstWhere((c) => c.isDefault);
    } catch (_) {
      return _clinicians.isNotEmpty ? _clinicians.first : null;
    }
  }

  Future<void> load() async {
    _clinicians = await _db.getAllClinicians();
    _loaded = true;
  }

  Future<void> add(Clinician clinician) async {
    if (_clinicians.isEmpty) {
      clinician.isDefault = true;
    }
    await _db.insertClinician(clinician);
    _clinicians.add(clinician);
  }

  Future<void> update(Clinician clinician) async {
    await _db.updateClinician(clinician);
    final index = _clinicians.indexWhere((c) => c.id == clinician.id);
    if (index != -1) {
      _clinicians[index] = clinician;
    }
  }

  Future<void> delete(String id) async {
    await _db.deleteClinician(id);
    _clinicians.removeWhere((c) => c.id == id);
    if (_clinicians.isNotEmpty && defaultClinician == null) {
      _clinicians.first.isDefault = true;
      await _db.updateClinician(_clinicians.first);
    }
  }

  Future<void> setDefault(String id) async {
    await _db.setDefaultClinician(id);
    for (final c in _clinicians) {
      c.isDefault = c.id == id;
    }
  }

  bool get isEmpty => _clinicians.isEmpty;
  bool get isNotEmpty => _clinicians.isNotEmpty;
}