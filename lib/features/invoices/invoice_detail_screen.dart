import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/receipt_storage.dart';
import '../../models/supplier_invoice.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/print_invoice_action.dart';
import '../../widgets/status_badge.dart';
import 'invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final suppliers = ref.watch(suppliersProvider);
    final now = DateTime.now();

    SupplierInvoice? invoice;
    for (final i in invoices) {
      if (i.id == invoiceId) {
        invoice = i;
        break;
      }
    }

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Invoice not found.')),
      );
    }

    final inv = invoice;

    final supplierName = suppliers
            .where((s) => s.id == inv.supplierId)
            .firstOrNull
            ?.name ??
        'Unknown supplier';
    final status = inv.statusAt(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => printInvoice(context, ref, inv),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/invoices/${inv.id}/edit'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, inv.id),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Pulse: the figure that matters is on the dark panel, four
                // answers sit under it, and the paperwork comes last.
                _Hero(
                  invoice: inv,
                  supplierName: supplierName,
                  status: status,
                ),
                const SizedBox(height: 16),
                _Figures(invoice: inv, now: now),
                if (inv.lines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ItemsCard(invoice: inv),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final words = <Widget>[
                      _AmountWordsCard(invoice: inv),
                      if (inv.notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _NotesCard(note: inv.notes),
                      ],
                    ];

                    if (inv.receipts.isEmpty ||
                        constraints.maxWidth < 640) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: words,
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: words,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 360,
                          child: _ReceiptsCard(
                            invoice: inv,
                            ref: ref,
                            onOpen: _openReceipt,
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
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(invoicesProvider.notifier).remove(id);
      if (context.mounted) context.pop();
    }
  }

  void _openReceipt(BuildContext context, WidgetRef ref, String name) {
    showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<File>(
        future: ref
            .read(receiptStorageProvider)
            .receiptPath(name)
            .then((p) => File(p)),
        builder: (context, snapshot) {
          final file = snapshot.data;
          return AlertDialog(
            title: Text(_displayName(name)),
            content: SizedBox(
              width: 720,
              height: 520,
              child: file == null
                  ? const Center(child: CircularProgressIndicator())
                  : file.existsSync()
                      ? Image.file(file)
                      : const Center(child: Text('Receipt not found.')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The dark panel at the top: who it is for, where it stands, and the one
/// number that decides what happens next.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.invoice,
    required this.supplierName,
    required this.status,
  });

  final SupplierInvoice invoice;
  final String supplierName;
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final texts = Theme.of(context).textTheme;
    final accent = StatusBadge.colorOf(status);

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          supplierName,
          style: texts.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          <String>[
            inv.invoiceNumber,
            if (inv.reference.isNotEmpty) 'Ref ${inv.reference}',
            if (inv.description.isNotEmpty) inv.description,
          ].join('   ·   '),
          style: texts.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    // What is owed if anything is; otherwise what the whole thing came to, so
    // a settled invoice never shows a big round zero.
    final figure = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          inv.owesMoney ? 'BALANCE' : 'TOTAL',
          style: texts.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatPesewas(
            inv.owesMoney ? inv.balancePesewas : inv.totalPesewas,
          ),
          style: texts.headlineMedium?.copyWith(
            color: inv.owesMoney ? const Color(0xFFFDE68A) : Aurora.emerald,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    return FadeSlideIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Aurora.nightC, Color(0xFF123A4A), Aurora.nightB],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.26),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ParticleDrift(
          count: 16,
          color: accent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Under about half the width the supplier's name needs the room
              // more than the figure does, so the figure drops below it.
              final tight = constraints.maxWidth < 520;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tight) ...[
                    headline,
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeroStatusPill(status: status),
                        const Spacer(),
                        figure,
                      ],
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: headline),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _HeroStatusPill(status: status),
                        ),
                        const SizedBox(width: 20),
                        figure,
                      ],
                    ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      _HeroMeta(
                        label: 'Invoice date',
                        value: formatDate(inv.invoiceDate),
                      ),
                      _HeroMeta(
                        label: 'Received',
                        value: formatDate(inv.receivedDate),
                      ),
                      _HeroMeta(
                        label: 'Due',
                        value: formatDate(inv.dueDate),
                      ),
                      _HeroMeta(
                        label: 'Payment',
                        value: inv.paymentMethod,
                      ),
                      if (inv.paidDate != null)
                        _HeroMeta(
                          label: 'Paid on',
                          value: formatDate(inv.paidDate!),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The status on the dark panel. [StatusBadge] picks ink for a light page, so
/// it would be hard to read here; this is the same hue on its own ground.
class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = StatusBadge.colorOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

/// One quiet fact in the dark panel's foot: a muted label, a bright answer.
class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: texts.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          TextSpan(
            text: value,
            style: texts.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four answers, before anything else on the page: what it came to, what
/// has been paid, what is left and how long there is to pay it.
class _Figures extends StatelessWidget {
  const _Figures({required this.invoice, required this.now});

  final SupplierInvoice invoice;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final days = inv.dueDate.difference(dateOnly(now)).inDays;
    final boxes = inv.lines.fold(0, (sum, l) => sum + l.boxes);
    final pieces = inv.lines.fold(0, (sum, l) => sum + l.pieceCount);
    final settled = inv.totalPesewas <= 0
        ? 0
        : (inv.amountPaidPesewas * 100 / inv.totalPesewas).round();

    final tiles = <Widget>[
      _FigureTile(
        label: 'Total',
        value: formatPesewas(inv.totalPesewas),
        foot: inv.taxRatePercent > 0
            ? '${formatPesewas(inv.amountPesewas)} + '
                '${_rate(inv.taxRatePercent)}% tax'
            : 'no tax on this invoice',
      ),
      _FigureTile(
        label: 'Paid',
        value: formatPesewas(inv.amountPaidPesewas),
        valueColor: inv.amountPaidPesewas > 0
            ? _readableStatus(context, InvoiceStatus.paid)
            : null,
        foot: '$settled% settled · ${inv.paymentMethod}',
      ),
      _FigureTile(
        label: 'Balance',
        value: formatPesewas(inv.balancePesewas),
        valueColor: inv.owesMoney
            ? _readableStatus(context, InvoiceStatus.partiallyPaid)
            : _readableStatus(context, InvoiceStatus.paid),
        foot: !inv.owesMoney
            ? 'settled in full'
            : days < 0
                ? '${_plural(-days, 'day', 'days')} late'
                : days == 0
                    ? 'due today'
                    : 'due in ${_plural(days, 'day', 'days')}',
      ),
      _FigureTile(
        label: 'Items',
        value: '${inv.lines.length}',
        foot: '${_plural(boxes, 'box', 'boxes')} · '
            '${_plural(pieces, 'piece', 'pieces')}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across once there is room for them to breathe, two otherwise.
        final across = constraints.maxWidth >= 780;
        final width = across
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// One figure with a caption. The caption carries the detail the figure
/// cannot hold itself, so nothing is lost by leading with the big number.
class _FigureTile extends StatelessWidget {
  const _FigureTile({
    required this.label,
    required this.value,
    required this.foot,
    this.valueColor,
  });

  final String label;
  final String value;
  final String foot;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: texts.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: texts.headlineSmall?.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            foot,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(height: 22),
          Text(note, style: texts.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

/// English does not always reach the plural by adding an s, so the many form
/// is spelled out rather than guessed at.
String _plural(int n, String one, String many) => n == 1 ? '$n $one' : '$n $many';

/// A whole number of a percent reads as 15, not 15.0; a rate that is not whole
/// is kept as written so the invoice matches the sheet it came from.
String _rate(double percent) =>
    percent % 1 == 0 ? '${percent.toInt()}' : '$percent';

/// The status hue, in the version that stays readable on this page's surface.
Color _readableStatus(BuildContext context, InvoiceStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? StatusBadge.colorOf(status)
      : StatusBadge.inkOf(status);
}

class _AmountWordsCard extends StatelessWidget {
  const _AmountWordsCard({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final inv = invoice;

    Widget words(String label, IconData icon, int pesewas) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: texts.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              moneyInWords(pesewas),
              style: texts.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT IN WORDS',
            style: texts.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const Divider(height: 24),
          words('TOTAL', Icons.receipt_long_outlined, inv.totalPesewas),
          if (inv.owesMoney) ...[
            const Divider(height: 16),
            words('BALANCE', Icons.account_balance_wallet_outlined, inv.balancePesewas),
          ],
        ],
      ),
    );
  }
}

class _ReceiptsCard extends StatelessWidget {
  const _ReceiptsCard({
    required this.invoice,
    required this.ref,
    required this.onOpen,
  });

  final SupplierInvoice invoice;
  final WidgetRef ref;
  final void Function(BuildContext context, WidgetRef ref, String name) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipts (${invoice.receipts.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in invoice.receipts)
                ActionChip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text(_displayName(name)),
                  onPressed: () => onOpen(context, ref, name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Receipts are stored with a generated prefix, so what a person sees is what
/// came after it, with the leftovers spaced out.
String _displayName(String stored) {
  final idx = stored.indexOf('_');
  if (idx == -1) return stored;
  return stored.substring(idx + 1).replaceAll('_', ' ');
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.invoice});

  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    Widget header(String label, {bool right = false}) => Text(
          label,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: texts.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        );

    Widget cell(
      String text, {
      bool right = false,
      TextStyle? style,
    }) => Text(
          text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style ?? texts.bodyMedium,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${invoice.lines.length})',
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(flex: 4, child: header('Product')),
              Expanded(flex: 2, child: header('Qty', right: true)),
              Expanded(flex: 2, child: header('Price/box', right: true)),
              Expanded(flex: 2, child: header('Amount', right: true)),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in invoice.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: cell(
                      line.name,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        cell('${line.boxes} × ${line.piecesPerBox}',
                            right: true),
                        cell(
                          '${line.pieceCount} items',
                          right: true,
                          style: texts.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: cell(
                      '${formatPesewas(line.pricePerBoxPesewas)}/box',
                      right: true,
                      style: texts.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: cell(
                      formatPesewas(line.totalPesewas),
                      right: true,
                      style: texts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subtotal',
                  style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatPesewas(invoice.lineItemsTotalPesewas),
                style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
