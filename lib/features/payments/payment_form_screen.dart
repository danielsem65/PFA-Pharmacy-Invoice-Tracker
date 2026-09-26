import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/payment.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/desktop_form.dart';
import '../../widgets/page_header.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';
import 'payments_controller.dart';

/// Records a payment, which may settle any number of a supplier's invoices at
/// once. Each invoice shows what it still owes, and the amounts are added up as
/// she types so the split can never disagree with the total.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _supplierId;
  String _method = kPaymentMethods.first;
  DateTime _date = DateTime.now();
  final Map<String, int> _allocations = {};
  bool _splitEvenly = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Read here rather than in a field initialiser, because the framework only
    // hands the widget over after this object is built. A supplier that has
    // since been deleted leaves the field empty rather than pointing at nobody.
    _supplierId = _known(widget.supplierId);
    _amountCtrl.addListener(_onAmountChanged);
  }

  String? _known(String? id) {
    if (id == null) return null;
    for (final s in ref.read(suppliersProvider)) {
      if (s.id == id) return id;
    }
    return null;
  }

  @override
  void dispose() {
    _amountCtrl
      ..removeListener(_onAmountChanged)
      ..dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// The invoices this payment can settle: the chosen supplier's, and only what
  /// they still owe.
  List<SupplierInvoice> get _openInvoices {
    final invoices = ref.read(invoicesProvider);
    final now = DateTime.now();
    return invoices
        .where(
          (i) =>
              i.supplierId == _supplierId &&
              i.balancePesewas > 0 &&
              i.statusAt(now) != InvoiceStatus.paid,
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  int get _total =>
      _allocations.values.fold(0, (sum, v) => sum + v);

  int get _unallocated {
    final typed = _parseMoney(_amountCtrl.text) ?? 0;
    return typed - _total;
  }

  int? _parseMoney(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null) return null;
    return (v * 100).round();
  }

  void _onAmountChanged() {
    // With the split on, the amount belongs to the invoices rather than the
    // other way round, so moving the total moves the split with it.
    if (_splitEvenly) _distributeEvenly();
    setState(() {});
  }

  void _distributeEvenly() {
    final invoices = _openInvoices;
    final total = _parseMoney(_amountCtrl.text) ?? 0;
    _allocations.clear();
    if (invoices.isEmpty || total <= 0) return;
    final share = total ~/ invoices.length;
    var handedOut = 0;
    for (final inv in invoices) {
      final amount = share.clamp(0, inv.balancePesewas).toInt();
      if (amount <= 0) continue;
      _allocations[inv.id] = amount;
      handedOut += amount;
    }
    // Whatever the even split could not use goes to the first invoice that can
    // still take it, so the invoice totals always match the amount typed.
    var leftover = total - handedOut;
    for (final inv in invoices) {
      if (leftover <= 0) break;
      final room = inv.balancePesewas - (_allocations[inv.id] ?? 0);
      if (room <= 0) continue;
      final extra = room < leftover ? room : leftover;
      _allocations[inv.id] = (_allocations[inv.id] ?? 0) + extra;
      leftover -= extra;
    }
  }

  void _toggleInvoice(SupplierInvoice inv, bool on) {
    setState(() {
      _error = null;
      if (on) {
        _allocations[inv.id] = inv.balancePesewas;
        if (_splitEvenly) _distributeEvenly();
      } else {
        _allocations.remove(inv.id);
      }
    });
  }

  void _setAmountFor(SupplierInvoice inv, String raw) {
    final parsed = _parseMoney(raw);
    setState(() {
      if (parsed == null || parsed <= 0) {
        _allocations.remove(inv.id);
      } else {
        _allocations[inv.id] = parsed.clamp(0, inv.balancePesewas).toInt();
      }
      // Typing an exact figure means she is splitting by hand.
      _splitEvenly = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      setState(() => _error = 'Choose the supplier this payment was made to.');
      return;
    }
    if (_allocations.isEmpty) {
      setState(() => _error = 'Tick at least one invoice to settle.');
      return;
    }
    final typed = _parseMoney(_amountCtrl.text);
    if (typed == null) {
      setState(() => _error = 'That amount is not a number.');
      return;
    }
    if (typed <= 0) {
      setState(() => _error = 'Enter the amount that was paid.');
      return;
    }
    if (_unallocated != 0) {
      setState(
        () => _error = _unallocated > 0
            ? 'Still ${formatPesewas(_unallocated)} to hand out.'
            : 'The invoices add up to more than the amount paid.',
      );
      return;
    }
    final names = ref
        .read(suppliersProvider)
        .where((s) => s.id == _supplierId)
        .map((s) => s.name)
        .join(', ');
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(paymentsProvider.notifier).add(
          Payment(
            date: _date,
            method: _method,
            reference: _referenceCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? 'Paid to $names'
                : _notesCtrl.text.trim(),
            allocations: [
              for (final entry in _allocations.entries)
                PaymentAllocation(
                  invoiceId: entry.key,
                  amountPesewas: entry.value,
                ),
            ],
          ),
        );
    if (!mounted) return;
    context.go('/payments');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suppliers = ref.watch(suppliersProvider);
    final invoices = _openInvoices;

    return Scaffold(
      appBar: AppBar(title: const Text('Record payment')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: 'Record payment',
                        subtitle:
                            'One payment can settle as many invoices as you tick',
                        icon: Icons.payments_outlined,
                        accentIndex: 4,
                      ),
                      const SizedBox(height: 18),
                      FormSection(
                        title: 'The payment',
                        icon: Icons.account_balance_wallet_outlined,
                        children: [
                          DropdownButtonFormField<String>(
                            key: const Key('payment-supplier'),
                            initialValue: _supplierId,
                            decoration: const InputDecoration(
                              labelText: 'Paid to',
                              isDense: true,
                            ),
                            items: [
                              for (final s in suppliers)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              _supplierId = v;
                              _allocations.clear();
                            }),
                          ),
                          FieldRow(
                            fields: [
                              FieldSpec(
                                flex: 2,
                                child: TextField(
                                  key: const Key('payment-amount'),
                                  controller: _amountCtrl,
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount paid (GH₵)',
                                    prefixText: 'GH₵ ',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              FieldSpec(
                                flex: 3,
                                child: InkWell(
                                  key: const Key('payment-date'),
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date paid',
                                      isDense: true,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(formatDate(_date)),
                                        const Spacer(),
                                        const Icon(Icons.event, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          FieldRow(
                            fields: [
                              FieldSpec(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _method,
                                  decoration: const InputDecoration(
                                    labelText: 'Method',
                                    isDense: true,
                                  ),
                                  items: [
                                    for (final m in kPaymentMethods)
                                      DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _method = v ?? _method),
                                ),
                              ),
                              FieldSpec(
                                flex: 3,
                                child: TextField(
                                  controller: _referenceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Reference (teller, cheque no.)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FormSection(
                        title: 'What it settles',
                        icon: Icons.checklist_rtl,
                        trailing: invoices.isEmpty
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Split evenly',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  Switch(
                                    key: const Key('split-evenly'),
                                    value: _splitEvenly,
                                    onChanged: (v) => setState(() {
                                      _splitEvenly = v;
                                      if (v) {
                                        _distributeEvenly();
                                      } else {
                                        _allocations.clear();
                                      }
                                    }),
                                  ),
                                ],
                              ),
                        children: [
                          if (invoices.isEmpty)
                            Text(
                              _supplierId == null
                                  ? 'Choose a supplier to see what they are owed.'
                                  : 'This supplier has nothing outstanding.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            )
                          else ...[
                            for (final inv in invoices)
                              _InvoiceAllocationRow(
                                invoice: inv,
                                amount: _allocations[inv.id],
                                onToggle: (on) => _toggleInvoice(inv, on),
                                onAmount: (raw) => _setAmountFor(inv, raw),
                              ),
                            const SizedBox(height: 4),
                            _AllocationSummary(
                              total: _total,
                              unallocated: _unallocated,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      FormSection(
                        title: 'Note',
                        icon: Icons.sticky_note_2_outlined,
                        children: [
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'What this payment was for',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          key: const Key('payment-error'),
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          FormActionsBar(
            leading: _allocations.isEmpty
                ? null
                : Text(
                    'Total ${formatPesewas(_total)} across '
                    '${_allocations.length} '
                    '${_allocations.length == 1 ? 'invoice' : 'invoices'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
            onCancel: () => context.go('/payments'),
            onSave: _saving ? () {} : _save,
            saveLabel: 'Save payment',
          ),
        ],
      ),
    );
  }
}

class _InvoiceAllocationRow extends StatefulWidget {
  const _InvoiceAllocationRow({
    required this.invoice,
    required this.amount,
    required this.onToggle,
    required this.onAmount,
  });

  final SupplierInvoice invoice;
  final int? amount;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onAmount;

  @override
  State<_InvoiceAllocationRow> createState() => _InvoiceAllocationRowState();
}

class _InvoiceAllocationRowState extends State<_InvoiceAllocationRow> {
  late final TextEditingController _ctrl = TextEditingController(
    text: _text,
  );
  final _focus = FocusNode();

  String get _text =>
      widget.amount == null ? '' : (widget.amount! / 100).toStringAsFixed(2);

  @override
  void didUpdateWidget(covariant _InvoiceAllocationRow old) {
    super.didUpdateWidget(old);
    if (old.amount == widget.amount) return;
    // An even split changes the figures from outside, so the box follows along
    // — unless this is the box she is typing in, which must be left alone.
    if (_focus.hasFocus) return;
    final next = _text;
    if (_ctrl.text != next) _ctrl.text = next;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final on = widget.amount != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      decoration: BoxDecoration(
        color: on ? scheme.primary.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: on
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            key: Key('pay-invoice-${widget.invoice.id}'),
            value: on,
            onChanged: (v) => widget.onToggle(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.invoice.invoiceNumber,
                  style:
                      texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Owes ${formatPesewas(widget.invoice.balancePesewas)}'
                  ' · due ${formatDate(widget.invoice.dueDate)}',
                  style: texts.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: TextField(
              key: Key('pay-amount-${widget.invoice.id}'),
              controller: _ctrl,
              focusNode: _focus,
              enabled: on,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: 'GH₵ ',
                isDense: true,
              ),
              onChanged: widget.onAmount,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({required this.total, required this.unallocated});

  final int total;
  final int unallocated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settled = unallocated == 0 && total > 0;
    return Row(
      children: [
        Icon(
          settled ? Icons.check_circle : Icons.info_outline,
          size: 18,
          color: settled ? Aurora.emerald : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            settled
                ? 'Every pesewa of the payment has a home.'
                : unallocated > 0
                    ? '${formatPesewas(unallocated)} left to hand out.'
                    : 'The invoices add up to more than was paid.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: settled ? Aurora.emerald : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          formatPesewas(total),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
