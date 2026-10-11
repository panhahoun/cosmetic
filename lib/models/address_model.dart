class Address {
  final int id;
  final String fullName;
  final String phone;
  final String addressLine;
  final String city;
  final String postalCode;
  final bool isDefault;

  Address({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.postalCode,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return Address(
      id: i(json['id']),
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      addressLine: json['address_line']?.toString() ?? '',
      city: (json['city'] ?? '').toString(),
      postalCode: (json['postal_code'] ?? '').toString(),
      isDefault: json['is_default'] == true,
    );
  }

  String get summary =>
      [city, postalCode].where((s) => s.isNotEmpty).join(', ');
}
