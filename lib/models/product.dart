/// A reusable catalogue entry for products the pharmacy buys on credit.
///
/// Product names are the link between the catalogue and invoice line items:
/// invoice lines store a plain copy of the name, so deleting a product never
/// damages an existing invoice.
class Product {
  Product({
    required this.id,
    required this.name,
    this.piecesPerBox = 1,
    this.pricePerBoxPesewas = 0,
    this.notes = '',
  });

  factory Product.create(
    String name, {
    int piecesPerBox = 1,
    int pricePerBoxPesewas = 0,
    String notes = '',
  }) {
    return Product(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      piecesPerBox: piecesPerBox,
      pricePerBoxPesewas: pricePerBoxPesewas,
      notes: notes,
    );
  }

  final String id;
  final String name;

  /// Default pack size, used to pre-fill new invoice lines.
  final int piecesPerBox;

  /// Default price per box in pesewas, used to pre-fill new invoice lines.
  final int pricePerBoxPesewas;
  final String notes;

  String get normalizedName => name.trim().toLowerCase();

  Product copyWith({
    String? name,
    int? piecesPerBox,
    int? pricePerBoxPesewas,
    String? notes,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      piecesPerBox: piecesPerBox ?? this.piecesPerBox,
      pricePerBoxPesewas: pricePerBoxPesewas ?? this.pricePerBoxPesewas,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'piecesPerBox': piecesPerBox,
      'pricePerBoxPesewas': pricePerBoxPesewas,
      'notes': notes,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      piecesPerBox: (json['piecesPerBox'] as int?) ?? 1,
      pricePerBoxPesewas: (json['pricePerBoxPesewas'] as int?) ?? 0,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}
