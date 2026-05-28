class Clinic {
  String id;
  String clinicianId;
  String name;
  String address;
  String city;
  String state;
  String zip;
  String phone;
  bool isDefault;

  Clinic({
    required this.id,
    required this.clinicianId,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.phone = '',
    this.isDefault = false,
  });

  String get fullAddress {
    final parts = [address, city, state, zip]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  String get displayLabel => fullAddress.isNotEmpty
      ? '$name — $fullAddress'
      : name;
}