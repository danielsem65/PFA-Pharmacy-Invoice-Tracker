import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/receipt_storage.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/desktop_form.dart';
import '../../widgets/glass_dialog.dart';
import '../invoices/invoices_controller.dart';
import '../products/products_controller.dart';
import '../suppliers/suppliers_controller.dart';

class _LineDraft {
  _LineDraft([InvoiceLine? line])
      : name = TextEditingController(text: line?.name ?? ''),
        boxes = TextEditingController(text: line == null ? '1' : '${line.boxes}'),
        piecesPerBox = TextEditingController(
            text: line == null ? '1' : '${line.piecesPerBox}'),
        pricePerBox = TextEditingController(
            text: line == null
                ? ''
                : (line.pricePerBoxPesewas / 100).toStringAsFixed(2));

  final TextEditingController name;
  final TextEditingController boxes;
  final TextEditingController piecesPerBox;
  final TextEditingController pricePerBox;

  void dispose() {
    name.dispose();
    boxes.dispose();
    piecesPerBox.dispose();
    pricePerBox.dispose();
  }
}

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
  late final TextEditingController _notes;

  SupplierInvoice? _existing;
  String? _supplierId;
  DateTime _invoiceDate = dateOnly(DateTime.now());
  DateTime _receivedDate = dateOnly(DateTime.now());
  DateTime _dueDate = dateOnly(DateTime.now().add(const Duration(days: 30)));
  String _paymentMethod = 'Cash';
  final List<String> _receipts = [];
  final List<_LineDraft> _lineDrafts = [];

  bool get _isEditing => widget.invoiceId != null;
  bool get _hasLines => _lineDrafts.isNotEmpty;

  int get _computedSubtotal {
    var total = 0;
    for (final d in _lineDrafts) {
      final boxes = int.tryParse(d.boxes.text.trim()) ?? 0;
      final price = _parseMoney(d.pricePerBox.text) ?? 0;
      total += boxes * price;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _invoiceNo = TextEditingController();
    _reference = TextEditingController();
    _description = TextEditingController();
    _amount = TextEditingController();
    _taxRate = TextEditingController();
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
        _receipts.addAll(e.receipts);
        _invoiceNo.text = e.invoiceNumber;
        _reference.text = e.reference;
        _description.text = e.description;
        _notes.text = e.notes;
        _amount.text = (e.amountPesewas / 100).toStringAsFixed(2);
        _taxRate.text = e.taxRatePercent == e.taxRatePercent.roundToDouble()
            ? e.taxRatePercent.round().toString()
            : e.taxRatePercent.toString();
        if (e.lines.isNotEmpty) {
          _lineDrafts.addAll(e.lines.map((l) => _LineDraft(l)));
          _amount.text = (e.lineItemsTotalPesewas / 100).toStringAsFixed(2);
        }
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
    _notes.dispose();
    _searchController.dispose();
    for (final d in _lineDrafts) {
      d.dispose();
    }
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

  /// Opens the dialog that asks for the details of a supplier who is not in the
  /// app yet, and puts them on this invoice.
  ///
  /// The dialog closes itself and hands the new supplier back, rather than
  /// writing it and then closing. Two reasons: the dialog shuts the instant
  /// Create is pressed instead of sitting there while the write happens, and
  /// the pop happens in the same frame as the tap, so it can only ever close
  /// the dialog. Awaiting a write first left the dialog's own route able to be
  /// gone by the time it popped, and the pop then took the invoice form with
  /// it - losing everything typed on the form.
  Future<void> _createSupplier(String name) async {
    final nameTrimmed = name.trim();
    if (nameTrimmed.isEmpty) return;

    // Cancelled means null, which is not an error: nothing was created, so
    // there is nothing to select.
    final created = await showGlassDialog<Supplier>(
      context: context,
      builder: (context) => NewSupplierDialog(initialName: nameTrimmed),
    );
    if (created == null) return;
    await ref.read(suppliersProvider.notifier).add(created);
    final s = ref
        .read(suppliersProvider)
        .where((x) => x.id == created.id)
        .firstOrNull;
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

  void _addLine() {
    setState(() {
      _lineDrafts.add(_LineDraft());
      _refreshAmount();
    });
  }

  /// Adds a line from a catalogue product instead of a typed one, carrying the
  /// pack size and price across so only the quantity is left to fill in.
  void _addLineFromProduct(Product product) {
    final draft = _LineDraft()
      ..name.text = product.name
      ..piecesPerBox.text = '${product.piecesPerBox}'
      ..pricePerBox.text = product.pricePerBoxPesewas > 0
          ? (product.pricePerBoxPesewas / 100).toStringAsFixed(2)
          : '';
    setState(() {
      _lineDrafts.add(draft);
      _refreshAmount();
    });
  }

  Future<void> _lookUpProduct() async {
    final chosen = await showGlassDialog<Product>(
      context: context,
      builder: (context) => const _ProductLookupDialog(),
    );
    if (chosen == null || !mounted) return;
    _addLineFromProduct(chosen);
  }

  void _removeLine(int index) {
    setState(() {
      _lineDrafts.removeAt(index).dispose();
      _refreshAmount();
    });
  }

  void _refreshAmount() {
    if (_hasLines) {
      _amount.text = (_computedSubtotal / 100).toStringAsFixed(2);
    }
  }

  String _lineSummary(_LineDraft d) {
    final boxes = int.tryParse(d.boxes.text.trim()) ?? 0;
    final pieces = int.tryParse(d.piecesPerBox.text.trim()) ?? 0;
    final price = _parseMoney(d.pricePerBox.text) ?? 0;
    if (boxes <= 0 || pieces <= 0 || price <= 0) return '—';
    final items = boxes * pieces;
    return '$boxes ${boxes == 1 ? 'box' : 'boxes'} × $pieces/box = '
        '$items items · ${formatPesewas(boxes * price)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select a supplier first.')));
      return;
    }
    final amount = _hasLines ? _computedSubtotal : (_parseMoney(_amount.text) ?? 0);
    final tax = _parsePercent(_taxRate.text);

    var invoiceLines = const <InvoiceLine>[];
    if (_hasLines) {
      final lines = <InvoiceLine>[];
      for (final d in _lineDrafts) {
        final name = d.name.text.trim();
        final boxes = int.tryParse(d.boxes.text.trim());
        final pieces = int.tryParse(d.piecesPerBox.text.trim());
        final price = _parseMoney(d.pricePerBox.text);
        if (name.isEmpty ||
            boxes == null ||
            boxes <= 0 ||
            pieces == null ||
            pieces <= 0 ||
            price == null ||
            price <= 0) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text(
                'Complete every product line — name, boxes, '
                'pieces per box and price.',
              ),
            ));
          return;
        }
        lines.add(
          InvoiceLine(
            name: name,
            boxes: boxes,
            piecesPerBox: pieces,
            pricePerBoxPesewas: price,
          ),
        );
      }
      invoiceLines = lines;
    }

    // What has been paid is not decided here. A new invoice starts at nothing,
    // and an edit leaves the figure the payments page has already recorded
    // exactly as it found it, so saving invoice details can never quietly undo
    // a payment.
    final invoice = _existing == null
        ? SupplierInvoice.create(
            supplierId: _supplierId!,
            invoiceNumber: _invoiceNo.text.trim(),
            invoiceDate: _invoiceDate,
            receivedDate: _receivedDate,
            dueDate: _dueDate,
            amountPesewas: amount,
            taxRatePercent: tax ?? 0,
            reference: _reference.text.trim(),
            description: _description.text.trim(),
            paymentMethod: _paymentMethod,
            notes: _notes.text.trim(),
            receipts: List.of(_receipts),
            lines: invoiceLines,
          )
        : _existing!.copyWith(
            supplierId: _supplierId!,
            invoiceNumber: _invoiceNo.text.trim(),
            invoiceDate: _invoiceDate,
            receivedDate: _receivedDate,
            dueDate: _dueDate,
            amountPesewas: amount,
            taxRatePercent: tax ?? 0,
            reference: _reference.text.trim(),
            description: _description.text.trim(),
            paymentMethod: _paymentMethod,
            notes: _notes.text.trim(),
            receipts: List.of(_receipts),
            lines: invoiceLines,
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

  /// The line numbers in the order they are shown: newest first, so a line added
  /// on this page is the one you see straight away. The drafts themselves stay
  /// in the order they were entered, which is the order the saved invoice keeps.
  List<int> get _newestFirst => [
        for (var i = _lineDrafts.length - 1; i >= 0; i--) i,
      ];

  int get _liveSubtotal =>
      _hasLines ? _computedSubtotal : (_parseMoney(_amount.text) ?? 0);

  int get _liveTax {
    final rate = _parsePercent(_taxRate.text) ?? 0;
    return (_liveSubtotal * rate / 100).round();
  }

  int get _liveTotal => _liveSubtotal + _liveTax;

  /// What the payments page has already settled against this invoice. Payments
  /// are recorded there and nowhere else, so this only ever reads.
  int get _recordedPaid => _existing?.amountPaidPesewas ?? 0;

  int _lineTotal(_LineDraft d) {
    final boxes = int.tryParse(d.boxes.text.trim()) ?? 0;
    final price = _parseMoney(d.pricePerBox.text) ?? 0;
    return boxes * price;
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _banner(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, box) {
                      final main = <Widget>[
                        _supplierSection(suppliers),
                        _itemsSection(),
                      ];
                      final side = <Widget>[
                        _datesSection(),
                        _amountsSection(),
                        _totalsPanel(),
                        _notesSection(),
                      ];
                      if (box.maxWidth < 1040) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: withGaps([...main, ...side], 16),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: withGaps(main, 16),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 400,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: withGaps(side, 16),
                            ),
                          ),
                        ],
                      );
                    },
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
        saveLabel: 'Save',
        leading: _footerSummary(),
      ),
    );
  }

  Widget _banner() {
    final texts = Theme.of(context).textTheme;
    final mark = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        size: 30,
        color: Colors.white,
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isEditing ? 'Update this invoice' : 'Record a new invoice',
          style: texts.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the medicines you bought on credit. Item lines are optional — '
          'leave them empty and type a total instead.',
          style: texts.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.35,
          ),
        ),
      ],
    );
    final total = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TOTAL',
            style: texts.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatPesewas(_liveTotal),
            style: texts.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B3B52),
                Color(0xFF0E7490),
                Color(0xFF0F9D77),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E7490).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: wide
              ? Row(
                  children: [
                    mark,
                    const SizedBox(width: 16),
                    Expanded(child: words),
                    const SizedBox(width: 16),
                    total,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        mark,
                        const SizedBox(width: 14),
                        Expanded(child: words),
                      ],
                    ),
                    const SizedBox(height: 14),
                    total,
                  ],
                ),
        );
      },
    );
  }

  Widget _supplierSection(List<Supplier> suppliers) {
    return FormSection(
      title: 'Supplier & reference',
      icon: Icons.local_shipping_outlined,
      children: [
        _supplierPicker(suppliers),
        FieldRow(
          fields: [
            (
              flex: 3,
              child: TextFormField(
                controller: _invoiceNo,
                decoration: const InputDecoration(labelText: 'Invoice No'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the invoice number'
                    : null,
              ),
            ),
            (
              flex: 3,
              child: TextFormField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Ref / PO No'),
              ),
            ),
            (
              flex: 4,
              child: TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _itemsSection() {
    return FormSection(
      title: 'Products / items',
      icon: Icons.inventory_2_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            key: const Key('lookup-product'),
            tooltip: 'Look up a product',
            onPressed: _lookUpProduct,
            icon: const Icon(Icons.travel_explore, size: 20),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _addLine,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ],
      ),
      children: [
        if (_lineDrafts.isEmpty)
          const FormHint(
            text: 'Optional. Add every product you bought — e.g. 2 boxes × 24 '
                'pieces at ₵55 per box. Leave it empty and type the total in the '
                'amounts panel instead.',
          )
        else ...[
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= _tableBreakpoint;
              final rows = <Widget>[
                if (wide) _lineHeaderRow(),
                for (final i in _newestFirst) ...[
                  const SizedBox(height: 8),
                  _lineRow(_lineDrafts[i], i, wide: wide),
                ],
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withGaps(rows, 8),
              );
            },
          ),
          const SizedBox(height: 4),
          const FormHint(
            icon: Icons.swap_vert,
            text: 'Newest items are listed first while you are on this page. '
                'Once saved, the invoice lists them in the order you entered '
                'them.',
          ),
        ],
      ],
    );
  }

  static const _nameFlex = 5;
  static const _boxesFlex = 2;
  static const _piecesFlex = 2;
  static const _priceFlex = 3;
  static const _badgeWidth = 24.0;

  /// Wider than the round number badge, because the word 'ITEM' has to sit on
  /// one line above it.
  static const _itemHeadingWidth = 44.0;
  static const _totalWidth = 110.0;
  static const _deleteWidth = 36.0;
  static const _gutter = 8.0;
  static const _pad = 12.0;

  /// The item line is laid out as a table only once the panel is wide enough for
  /// the columns to be readable; below that it stacks like a card.
  static const _tableBreakpoint = 860.0;

  Widget _lineHeaderRow() {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        );
    // A column heading must never break across two lines: a wrapped 'ITEM'
    // reads as 'ITE' with an 'M' dropped underneath it. Headings stay on one
    // line and shrink to fit their column instead.
    Widget heading(String label, {int flex = 0, double width = 0, Alignment align = Alignment.centerLeft}) {
      final text = Text(
        label,
        style: style,
        maxLines: 1,
        softWrap: false,
      );
      final fitted = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: align,
        child: text,
      );
      if (flex > 0) {
        return Expanded(flex: flex, child: Align(alignment: align, child: fitted));
      }
      return SizedBox(width: width, child: Align(alignment: align, child: fitted));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          heading('ITEM', width: _itemHeadingWidth),
          const SizedBox(width: _gutter),
          heading('PRODUCT', flex: _nameFlex),
          const SizedBox(width: _gutter),
          heading('BOXES', flex: _boxesFlex),
          const SizedBox(width: _gutter),
          heading('PCS/BOX', flex: _piecesFlex),
          const SizedBox(width: _gutter),
          heading('PRICE / BOX', flex: _priceFlex),
          const SizedBox(width: _gutter),
          heading('LINE TOTAL', width: _totalWidth, align: Alignment.centerRight),
          const SizedBox(width: _gutter),
          const SizedBox(width: _deleteWidth),
        ],
      ),
    );
  }

  Widget _lineRow(_LineDraft draft, int index, {required bool wide}) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isNewest = index == _lineDrafts.length - 1;
    final total = _lineTotal(draft);
    final pieces = int.tryParse(draft.piecesPerBox.text.trim()) ?? 0;
    final boxes = int.tryParse(draft.boxes.text.trim()) ?? 0;

    final nameField = TextFormField(
      controller: draft.name,
      decoration: const InputDecoration(labelText: 'Product name', isDense: true),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Enter product name' : null,
    );
    final boxesField = TextFormField(
      controller: draft.boxes,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Boxes', isDense: true),
      validator: (v) =>
          (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'At least 1',
      onChanged: (_) => setState(_refreshAmount),
    );
    final piecesField = TextFormField(
      controller: draft.piecesPerBox,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Pieces per box', isDense: true),
      validator: (v) =>
          (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'At least 1',
      onChanged: (_) => setState(_refreshAmount),
    );
    final priceField = TextFormField(
      controller: draft.pricePerBox,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Price per box (GH₵)',
        isDense: true,
        prefixText: '₵ ',
      ),
      validator: (v) =>
          (_parseMoney((v ?? '').trim()) ?? 0) > 0 ? null : 'Enter price',
      onChanged: (_) => setState(_refreshAmount),
    );
    final remove = SizedBox(
      width: _deleteWidth,
      child: IconButton(
        tooltip: 'Remove item',
        padding: EdgeInsets.zero,
        onPressed: () => _removeLine(index),
        icon: const Icon(Icons.delete_outline, size: 20),
      ),
    );
    final badge = Container(
      width: _badgeWidth,
      height: _badgeWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNewest ? scheme.primary : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: isNewest
          ? Icon(Icons.check, size: 15, color: scheme.onPrimary)
          : Text(
              '${_newestFirst.indexOf(index) + 1}',
              style: texts.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    final content = wide
        ? Row(
            children: [
              badge,
              const SizedBox(width: _gutter),
              Expanded(flex: _nameFlex, child: nameField),
              const SizedBox(width: _gutter),
              Expanded(flex: _boxesFlex, child: boxesField),
              const SizedBox(width: _gutter),
              Expanded(flex: _piecesFlex, child: piecesField),
              const SizedBox(width: _gutter),
              Expanded(flex: _priceFlex, child: priceField),
              const SizedBox(width: _gutter),
              SizedBox(
                width: _totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPesewas(total),
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: total > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (boxes > 0 && pieces > 0)
                      Text(
                        '${boxes * pieces} items',
                        style: texts.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: _gutter),
              remove,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  badge,
                  const SizedBox(width: _gutter),
                  Expanded(child: nameField),
                  remove,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: boxesField),
                  const SizedBox(width: _gutter),
                  Expanded(child: piecesField),
                  const SizedBox(width: _gutter),
                  Expanded(child: priceField),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    isNewest ? 'Just added' : _lineSummary(draft),
                    style: texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatPesewas(total),
                    style: texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: isNewest
            ? scheme.primaryContainer.withValues(alpha: 0.30)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNewest
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: content,
    );
  }

  Widget _datesSection() {
    return FormSection(
      title: 'Dates',
      icon: Icons.event_outlined,
      children: [
        FieldRow(
          fields: [
            (
              flex: 1,
              child: _dateField(
                label: 'Invoice Date',
                value: _invoiceDate,
                onPicked: (d) => setState(() => _invoiceDate = d),
              ),
            ),
            (
              flex: 1,
              child: _dateField(
                label: 'Received Date',
                value: _receivedDate,
                onPicked: (d) => setState(() => _receivedDate = d),
              ),
            ),
          ],
        ),
        FieldRow(
          fields: [
            (
              flex: 1,
              child: _dateField(
                label: 'Due Date',
                value: _dueDate,
                onPicked: (d) => setState(() => _dueDate = d),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _amountsSection() {
    return FormSection(
      title: 'Amounts',
      icon: Icons.payments_outlined,
      children: [
        FieldRow(
          fields: [
            (
              flex: 3,
              child: TextFormField(
                controller: _amount,
                readOnly: _hasLines,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (GH₵)',
                  prefixText: '₵ ',
                  helperText: _hasLines ? 'Calculated from items' : null,
                ),
                validator: (v) {
                  final p = _parseMoney(v ?? '');
                  if (p == null) return 'Enter a valid amount';
                  if (p <= 0) return 'Amount must be more than 0';
                  return null;
                },
              ),
            ),
            (
              flex: 2,
              child: TextFormField(
                controller: _taxRate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tax %'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty || _parsePercent(t) != null) return null;
                  return '0–100';
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totalsPanel() {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final tax = _liveTax;
    final total = _liveTotal;
    final paid = _recordedPaid;
    final balance = total - paid;
    final rate = _parsePercent(_taxRate.text) ?? 0;

    Widget row(String label, String value, {bool strong = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: strong
                    ? texts.bodyMedium?.copyWith(fontWeight: FontWeight.w800)
                    : texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(
              value,
              style: (strong
                      ? texts.titleMedium
                      : texts.bodyMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? scheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.tertiaryContainer.withValues(alpha: 0.45),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Invoice total',
                style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          row(_hasLines ? 'Items subtotal' : 'Amount', formatPesewas(_liveSubtotal)),
          row('VAT (${_trimRate(rate)}%)', formatPesewas(tax)),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          row('Total', formatPesewas(total), strong: true, color: scheme.primary),
          row('Paid', formatPesewas(paid)),
          row(
            balance <= 0 ? 'Balance settled' : 'Balance due',
            formatPesewas(balance),
            strong: true,
            color: balance <= 0 ? const Color(0xFF0F9D77) : scheme.error,
          ),
          const SizedBox(height: 8),
          // The paid figure is the ledger's, not this form's, so say where it
          // comes from rather than leaving it looking editable.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  paid > 0
                      ? 'Payments are recorded on the Payments page.'
                      : 'Record a payment on the Payments page once this '
                          'invoice is saved.',
                  style: texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _trimRate(double rate) =>
      rate == rate.roundToDouble() ? '${rate.round()}' : '$rate';

  Widget _notesSection() {
    return FormSection(
      title: 'Notes & receipts',
      icon: Icons.sticky_note_2_outlined,
      children: [
        TextFormField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          maxLines: 3,
          minLines: 2,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _pickReceipts,
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach receipt / image'),
          ),
        ),
        if (_receipts.isNotEmpty)
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
    );
  }

  Widget _footerSummary() {
    final scheme = Theme.of(context).colorScheme;
    final count = _lineDrafts.length;
    final words = count == 0
        ? 'No item lines — the amount is typed in directly'
        : '$count ${count == 1 ? 'item' : 'items'} · '
            '${_hasLines ? 'total from items' : 'typed total'} '
            '${formatPesewas(_liveTotal)}';
    return Row(
      children: [
        Icon(
          count == 0 ? Icons.receipt_outlined : Icons.inventory_2_outlined,
          size: 18,
          color: scheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            words,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
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

/// Picks a product from the catalogue to drop onto an invoice line, so a name
/// that is already on file never has to be typed again.
class _ProductLookupDialog extends ConsumerStatefulWidget {
  const _ProductLookupDialog();

  @override
  ConsumerState<_ProductLookupDialog> createState() => _ProductLookupDialogState();
}

class _ProductLookupDialogState extends ConsumerState<_ProductLookupDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched rather than read: the catalogue is loaded off the page, so the
    // list arrives a moment after the dialog opens.
    final products = ref.watch(productsProvider);
    final scheme = Theme.of(context).colorScheme;
    final typed = _query.text.trim();
    final needle = typed.toLowerCase();
    final matches = needle.isEmpty
        ? products
        : products.where((p) => p.normalizedName.contains(needle)).toList();

    Widget pick(Product product, {String? label, IconData? icon}) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon ?? Icons.medication_outlined,
              size: 20, color: scheme.onPrimaryContainer),
        ),
        title: Text(label ?? product.name),
        subtitle: Text([
          '${product.piecesPerBox} per box',
          if (product.pricePerBoxPesewas > 0)
            formatPesewas(product.pricePerBoxPesewas),
        ].join(' · ')),
        onTap: () => Navigator.of(context).pop(product),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.travel_explore, color: scheme.primary),
          const SizedBox(width: 10),
          const Text('Look up a product'),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: typed.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No products in the catalogue yet. Type a name below '
                          'and it will be used as typed — or build the catalogue '
                          'on the Products page and pick from it here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final p in matches) pick(p),
                        // Nothing on file is not a dead end: the typed name can
                        // still be used, it just is not remembered.
                        if (matches.isEmpty && typed.isNotEmpty)
                          pick(
                            Product.create(typed),
                            label: 'Use "$typed"',
                            icon: Icons.add,
                          ),
                        if (products.isNotEmpty &&
                            matches.isEmpty &&
                            typed.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Nothing matches. Try part of the name.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// The "New supplier" dialog.
///
/// A [StatefulWidget] purely so the three fields can have controllers that live
/// exactly as long as the dialog does. Building them in the calling method meant
/// disposing them as soon as the dialog returned, which is before the closing
/// animation has finished - the [TextField]s were still being built during that
/// animation and threw "a TextEditingController was used after being disposed"
/// from inside the navigator, which tore the page behind the dialog down with
/// it. Building them inline instead, as a new controller on every rebuild, threw
/// away whatever had been typed. Owning them here is the only arrangement where
/// both are impossible.
class NewSupplierDialog extends StatefulWidget {
  const NewSupplierDialog({required this.initialName, super.key});

  final String initialName;

  @override
  State<NewSupplierDialog> createState() => _NewSupplierDialogState();
}

class _NewSupplierDialogState extends State<NewSupplierDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _location = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New supplier'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Supplier name'),
          ),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          TextField(
            controller: _location,
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
          onPressed: () => Navigator.of(context).pop(
            Supplier.create(
              _name.text.trim(),
              phone: _phone.text.trim(),
              location: _location.text.trim(),
            ),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}