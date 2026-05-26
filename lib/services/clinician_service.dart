import '../models/clinician.dart';

// In-memory clinician storage
// We will replace this with a real database later
class ClinicianService {
  static final ClinicianService _instance = ClinicianService._internal();
  factory ClinicianService() => _instance;
  ClinicianService._internal();

  final List<Clinician> _clinicians = [];

  List<Clinician> get all => List.unmodifiable(_clinicians);

  Clinician? get defaultClinician {
    try {
      return _clinicians.firstWhere((c) => c.isDefault);
    } catch (_) {
      return _clinicians.isNotEmpty ? _clinicians.first : null;
    }
  }

  void add(Clinician clinician) {
    // If this is the first clinician, make it default
    if (_clinicians.isEmpty) {
      clinician.isDefault = true;
    }
    _clinicians.add(clinician);
  }

  void update(Clinician clinician) {
    final index = _clinicians.indexWhere((c) => c.id == clinician.id);
    if (index != -1) {
      _clinicians[index] = clinician;
    }
  }

  void delete(String id) {
    _clinicians.removeWhere((c) => c.id == id);
    // If we deleted the default, make the first one default
    if (_clinicians.isNotEmpty && defaultClinician == null) {
      _clinicians.first.isDefault = true;
    }
  }

  void setDefault(String id) {
    for (final c in _clinicians) {
      c.isDefault = c.id == id;
    }
  }

  bool get isEmpty => _clinicians.isEmpty;
  bool get isNotEmpty => _clinicians.isNotEmpty;
}