class Supplier {
  Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.location = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String phone;
  final String location;
  final String notes;

  factory Supplier.create(
    String name, {
    String phone = '',
    String location = '',
    String notes = '',
  }) {
    return Supplier(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      phone: phone,
      location: location,
      notes: notes,
    );
  }

  Supplier copyWith({
    String? name,
    String? phone,
    String? location,
    String? notes,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'location': location,
      'notes': notes,
    };
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: (json['phone'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
    );
  }
}