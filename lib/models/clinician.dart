class Clinician {
  final String id;
  String name;
  String clinicName;
  String address;
  String city;
  String state;
  String zip;
  String phone;
  String email;
  String licenseNumber;
  bool isDefault;

  Clinician({
    required this.id,
    required this.name,
    required this.clinicName,
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.phone = '',
    this.email = '',
    this.licenseNumber = '',
    this.isDefault = false,
  });

  String get fullLabel => '$name — $clinicName';

  String get shippingAddress {
    final parts = [address, city, state, zip]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clinicName': clinicName,
      'address': address,
      'city': city,
      'state': state,
      'zip': zip,
      'phone': phone,
      'email': email,
      'licenseNumber': licenseNumber,
      'isDefault': isDefault,
    };
  }

  factory Clinician.fromMap(Map<String, dynamic> map) {
    return Clinician(
      id: map['id'],
      name: map['name'],
      clinicName: map['clinicName'],
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zip: map['zip'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }
}