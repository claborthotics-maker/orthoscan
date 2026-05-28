class Clinician {
  String id;
  String name;
  String licenseNumber;
  bool isDefault;

  Clinician({
    required this.id,
    required this.name,
    this.licenseNumber = '',
    this.isDefault = false,
  });

  String get fullLabel => licenseNumber.isNotEmpty
      ? '$name (Lic: $licenseNumber)'
      : name;
}