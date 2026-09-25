import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = SearchController();

  late final TextEditingController _invoiceNo;
  late final TextEditingController _reference;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _taxRate;
  late final TextEditingController _paid;
  late final TextEditingController _notes;

  SupplierInvoice? _existing;
  String? _supplierId;
  DateTime _invoiceDate = dateOnly(DateTime.now());
  DateTime _receivedDate = dateOnly(DateTime.now());
  DateTime _dueDate = dateOnly(DateTime.now().add(const Duration(days: 30)));
  DateTime _paidDate = dateOnly(DateTime.now());
  String _paymentMethod = 'Cash';
  final List<String> _receipts = [];

  bool get _isEditing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _invoiceNo = TextEditingController();
    _reference = TextEditingController();
    _description = TextEditingController();
    _amount = TextEditingController();
    _taxRate = TextEditingController();
    _paid = TextEditingController();
    _notes = TextEditingController();

    if (_isEditing) {
      final list = ref.read(invoicesProvider);
      for (final i in list) {
        if (i.id == widget.invoiceId) {
          _existing = i;
          break;
        }
      }
      final e = _existing;
      if (e != null) {
        _supplierId = e.supplierId;
        _invoiceDate = e.invoiceDate;
        _receivedDate = e.receivedDate;
        _dueDate = e.dueDate;
        _paymentMethod = e.paymentMethod;
        if (e.paidDate != null) _paidDate = e.paidDate!;
        _receipts.addAll(e.receipts);
        _invoiceNo.text = e.invoiceNumber;
        _reference.text = e.reference;
        _description.text = e.description;
        _notes.text = e.notes;
        _amount.text = (e.amountPesewas / 100).toStringAsFixed(2);
        _taxRate.text = e.taxRatePercent == e.taxRatePercent.roundToDouble()
            ? e.taxRatePercent.round().toString()
            : e.taxRatePercent.toString();
        _paid.text = (e.amountPaidPesewas / 100).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _invoiceNo.dispose();
    _reference.dispose();
    _description.dispose();
    _amount.dispose();
    _taxRate.dispose();
    _paid.dispose();
    _notes.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int? _parseMoney(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null) return null;
    return (v * 100).round();
  }

  double? _parsePercent(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  void _selectSupplier(Supplier s) {
    setState(() => _supplierId = s.id);
    _searchController.closeView(s.name);
  }

  Future<void> _createSupplier(String name) async {
    final nameTrimmed = name.trim();
    if (nameTrimmed.isEmpty) return;
    final controller = ref.read(suppliersProvider.notifier);
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    late String createdId;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: nameTrimmed),
              decoration: const InputDecoration(labelText: 'Supplier name'),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final created = Supplier.create(
                nameTrimmed,
                phone: phoneCtrl.text.trim(),
                location: locationCtrl.text.trim(),
              );
              createdId = created.id;
              await controller.add(created);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final s = ref.read(suppliersProvider).where((x) => x.id == createdId).firstOrNull;
    if (s != null && mounted) _selectSupplier(s);
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(dateOnly(picked));
  }

  Future<void> _pickReceipts() async {
    final files = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp', 'pdf'],
      ),
    ]);
    final storage = ref.read(receiptStorageProvider);
    for (final f in files) {
      try {
        final stored = await storage.saveReceiptFile(f.path);
        if (mounted) setState(() => _receipts.add(stored));
      } catch (_) {
        // Ignore files that could not be copied.
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select a supplier first.')));
      return;
    }
    final paidAmount = _parseMoney(_paid.text) ?? 0;
    final amount = _parseMoney(_amount.text) ?? 0;
    final tax = _parsePercent(_taxRate.text);

    final invoice = _existing == null
        ? SupplierInvoice.create(
            supplierId: _supplierId!,
            invoiceNumber: _invoiceNo.text.trim(),
            invoiceDate: _invoiceDate,
            receivedDate: _receivedDate,
            dueDate: _dueDate,
            amountPesewas: amount,
            taxRatePercent: tax ?? 0,
            amountPaidPesewas: paidAmount,
            reference: _reference.text.trim(),
            description: _description.text.trim(),
            paidDate: paidAmount > 0 ? _paidDate : null,
            paymentMethod: _paymentMethod,
            notes: _notes.text.trim(),
            receipts: List.of(_receipts),
          )
        : _existing!.copyWith(
            supplierId: _supplierId!,
            invoiceNumber: _invoiceNo.text.trim(),
            invoiceDate: _invoiceDate,
            receivedDate: _receivedDate,
            dueDate: _dueDate,
            amountPesewas: amount,
            taxRatePercent: tax ?? 0,
            amountPaidPesewas: paidAmount,
            paidDate: paidAmount > 0 ? _paidDate : null,
            clearPaidDate: paidAmount <= 0,
            reference: _reference.text.trim(),
            description: _description.text.trim(),
            paymentMethod: _paymentMethod,
            notes: _notes.text.trim(),
            receipts: List.of(_receipts),
          );

    await ref.read(invoicesProvider.notifier).upsert(invoice);
    if (mounted) context.pop();
  }

  Widget _supplierPicker(List<Supplier> suppliers) {
    return SearchAnchor.bar(
      searchController: _searchController,
      barHintText: 'Supplier',
      suggestionsBuilder: (context, controller) {
        final q = controller.text.trim();
        final ql = q.toLowerCase();
        final matches = suppliers
            .where((s) => s.name.toLowerCase().contains(ql))
            .toList();
        return [
          for (final s in matches)
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(s.name),
              subtitle: Text(
                [s.phone, s.location].where((e) => e.isNotEmpty).join(' · '),
              ),
              onTap: () => _selectSupplier(s),
            ),
          if (matches.isEmpty)
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: Text(q.isEmpty ? 'Type to search suppliers' : 'Create “$q”'),
              onTap: q.isEmpty
                  ? null
                  : () async {
                      _searchController.closeView('');
                      await _createSupplier(q);
                    },
            ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final hasPaid = (_parseMoney(_paid.text) ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _supplierPicker(suppliers),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceNo,
                          decoration: const InputDecoration(
                            labelText: 'Invoice No',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter the invoice number'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _reference,
                          decoration: const InputDecoration(
                            labelText: 'Ref / PO No',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    label: 'Invoice Date',
                    value: _invoiceDate,
                    onPicked: (d) => setState(() => _invoiceDate = d),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    label: 'Received Date',
                    value: _receivedDate,
                    onPicked: (d) => setState(() => _receivedDate = d),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    label: 'Due Date',
                    value: _dueDate,
                    onPicked: (d) => setState(() => _dueDate = d),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount (GH₵)',
                            prefixText: '₵ ',
                          ),
                          validator: (v) {
                            final p = _parseMoney(v ?? '');
                            if (p == null) return 'Enter a valid amount';
                            if (p <= 0) return 'Amount must be more than 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _taxRate,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tax %',
                          ),
                          validator: (v) =>
                              _parsePercent(v ?? '') == null
                                  ? '0–100'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paid,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Paid (GH₵)',
                            prefixText: '₵ ',
                          ),
                          validator: (v) {
                            final p = _parseMoney(v ?? '');
                            if (p == null) return 'Enter a valid amount';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _paymentField(hasPaid),
                      ),
                    ],
                  ),
                  if (hasPaid) ...[
                    const SizedBox(height: 12),
                    _dateField(
                      label: 'Paid Date',
                      value: _paidDate,
                      onPicked: (d) => setState(() => _paidDate = d),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _pickReceipts,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach receipt / image'),
                    ),
                  ),
                  if (_receipts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in _receipts)
                          InputChip(
                            label: Text(_displayName(name)),
                            onDeleted: () {
                              final storage = ref.read(receiptStorageProvider);
                              storage.deleteReceiptFile(name);
                              setState(() => _receipts.remove(name));
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentField(bool hasPaid) {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      decoration: const InputDecoration(labelText: 'Payment method'),
      items: [
        for (final m in kPaymentMethods)
          DropdownMenuItem(value: m, child: Text(m)),
      ],
      onChanged: hasPaid
          ? (v) {
              if (v != null) setState(() => _paymentMethod = v);
            }
          : null,
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          onPressed: () => _pickDate(initial: value, onPicked: onPicked),
        ),
      ),
      child: InkWell(
        onTap: () => _pickDate(initial: value, onPicked: onPicked),
        child: Text(formatDate(value)),
      ),
    );
  }

  String _displayName(String stored) {
    final idx = stored.indexOf('_');
    if (idx == -1) return stored;
    return stored.substring(idx + 1).replaceAll('_', ' ');
  }
}