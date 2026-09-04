class Patient {
  final String id;
  String firstName;
  String lastName;
  String patientId;
  String dateOfBirth;
  String phone;
  String email;
  String notes;
  String clinicId;
  DateTime createdAt;
  List<String> scanFiles;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.patientId = '',
    this.dateOfBirth = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.clinicId = '',
    required this.createdAt,
    this.scanFiles = const [],
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'patientId': patientId,
      'dateOfBirth': dateOfBirth,
      'phone': phone,
      'email': email,
      'notes': notes,
      'clinicId': clinicId,
      'createdAt': createdAt.toIso8601String(),
      'scanFiles': scanFiles,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      patientId: map['patientId'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      notes: map['notes'] ?? '',
      clinicId: map['clinicId'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      scanFiles: List<String>.from(map['scanFiles'] ?? []),
    );
  }
}
