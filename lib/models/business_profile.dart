/// Who the pharmacy is. Printed invoices carry this in the header, so it is
/// kept in one place and edited from Settings rather than typed into the app.
class BusinessProfile {
  BusinessProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.tin = '',
  });

  final String name;
  final String address;
  final String phone;
  final String email;
  final String tin;

  bool get isEmpty =>
      name.trim().isEmpty &&
      address.trim().isEmpty &&
      phone.trim().isEmpty &&
      email.trim().isEmpty &&
      tin.trim().isEmpty;

  /// The one line of small print under the business name. Empty parts are left
  /// out rather than printing " ·  · ".
  String get contactLine => <String>[
        address.trim(),
        phone.trim(),
        email.trim(),
        if (tin.trim().isNotEmpty) 'TIN ${tin.trim()}',
      ].where((part) => part.isNotEmpty).join(' · ');

  BusinessProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? tin,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      tin: tin ?? this.tin,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'tin': tin,
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      tin: json['tin'] as String? ?? '',
    );
  }

  @override
  String toString() => 'BusinessProfile(${name.isEmpty ? 'unnamed' : name})';
}
