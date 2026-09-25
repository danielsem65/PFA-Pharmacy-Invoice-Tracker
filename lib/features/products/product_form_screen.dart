import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../widgets/desktop_form.dart';
import 'products_controller.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _pieces;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  Product? _existing;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _pieces = TextEditingController(text: '1');
    _price = TextEditingController();
    _notes = TextEditingController();
    if (_isEditing) {
      _existing = ref
          .read(productsProvider)
          .where((p) => p.id == widget.productId)
          .firstOrNull;
      if (_existing != null) {
        _name.text = _existing!.name;
        _pieces.text = '${_existing!.piecesPerBox}';
        _price.text = _existing!.pricePerBoxPesewas == 0
            ? ''
            : (_existing!.pricePerBoxPesewas / 100).toStringAsFixed(2);
        _notes.text = _existing!.notes;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pieces.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  int? _parseMoney(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null) return null;
    return (v * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(productsProvider.notifier);
    final name = _name.text.trim();
    final pieces = int.tryParse(_pieces.text.trim()) ?? 1;
    final price = _parseMoney(_price.text) ?? 0;
    if (_existing != null) {
      await controller.update(_existing!.copyWith(
        name: name,
        piecesPerBox: pieces < 1 ? 1 : pieces,
        pricePerBoxPesewas: price < 0 ? 0 : price,
        notes: _notes.text.trim(),
      ));
    } else {
      await controller.add(Product.create(
        name,
        piecesPerBox: pieces < 1 ? 1 : pieces,
        pricePerBoxPesewas: price < 0 ? 0 : price,
        notes: _notes.text.trim(),
      ));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'New Product'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  FormSection(
                    title: 'Product',
                    icon: Icons.medication_outlined,
                    children: [
                      FieldRow(
                        fields: [
                          (
                            flex: 5,
                            child: TextFormField(
                              controller: _name,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Product name',
                                hintText: 'e.g. Panadol 500mg',
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Enter the product name'
                                      : null,
                            ),
                          ),
                          (
                            flex: 3,
                            child: TextFormField(
                              controller: _pieces,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Pieces per box',
                                helperText: 'Default pack size',
                              ),
                              validator: (v) =>
                                  (int.tryParse((v ?? '').trim()) ?? 0) > 0
                                      ? null
                                      : 'At least 1',
                            ),
                          ),
                          (
                            flex: 3,
                            child: TextFormField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Price per box (GH₵)',
                                prefixText: '₵ ',
                                helperText: 'Optional default',
                              ),
                              validator: (v) {
                                final parsed = _parseMoney(v ?? '');
                                if (parsed == null) return 'Enter a valid price';
                                if (parsed < 0) return 'Cannot be negative';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _notes,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Hint(
                    text: _isEditing
                        ? 'Renaming this product does not change invoices that '
                            'already use it — invoice lines keep the name they '
                            'were saved with.'
                        : 'Product names appear as suggestions when you add '
                            'items on an invoice, and fill in the pack size '
                            'and price for you.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: FormActionsBar(
        onCancel: () => context.pop(),
        onSave: _save,
        saveLabel: _isEditing ? 'Save changes' : 'Save product',
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
