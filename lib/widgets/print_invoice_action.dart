import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../data/invoice_pdf_service.dart';
import '../features/settings/business_profile_controller.dart';
import '../features/settings/print_settings_controller.dart';
import '../features/suppliers/suppliers_controller.dart';
import '../models/business_profile.dart';
import '../models/print_settings.dart';
import '../models/supplier.dart';
import '../models/supplier_invoice.dart';
import 'toast.dart';

/// What the picker dialog came back with.
class InvoicePrintChoice {
  const InvoicePrintChoice({required this.layout, required this.remember});

  final InvoicePrintLayout layout;

  /// Whether this layout should become the default for next time.
  final bool remember;
}

/// Picks the layout to print in. [initial] is the remembered default, so the
/// dialog opens on the layout that will be used most often.
Future<InvoicePrintChoice?> showInvoiceLayoutPicker(
  BuildContext context, {
  InvoicePrintLayout? initial,
}) {
  var selected = initial ?? InvoicePrintLayout.classicForm;
  var remember = initial != null;

  return showDialog<InvoicePrintChoice>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final texts = Theme.of(context).textTheme;
        return AlertDialog(
          title: const Text('Print invoice'),
          content: SizedBox(
            width: 420,
            // Three layouts plus the checkbox will not fit a short window, and
            // an AlertDialog body is not scrollable on its own.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose how this page is laid out. All three are A4 and print '
                    'in black and white.',
                    style: texts.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  for (final layout in InvoicePrintLayout.values)
                    _LayoutTile(
                      layout: layout,
                      selected: selected == layout,
                      onTap: () => setState(() => selected = layout),
                    ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: remember,
                    onChanged: (v) => setState(() => remember = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Remember this layout'),
                    subtitle: const Text(
                      'Skip this step next time. You can change it in Settings.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                InvoicePrintChoice(layout: selected, remember: remember),
              ),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            ),
          ],
        );
      },
    ),
  );
}

/// Picks a layout, builds the PDF and hands it to the Windows print dialog.
Future<void> printInvoice(
  BuildContext context,
  WidgetRef ref,
  SupplierInvoice invoice,
) async {
  final settings = ref.read(printSettingsProvider);
  final choice = await showInvoiceLayoutPicker(
    context,
    initial: settings.defaultLayout,
  );
  if (choice == null || !context.mounted) return;

  // Only write when the answer is actually different, so printing never
  // rewrites settings it did not change.
  final wanted = choice.remember ? choice.layout : null;
  if (wanted != settings.defaultLayout) {
    await ref.read(printSettingsProvider.notifier).setDefaultLayout(wanted);
  }
  if (!context.mounted) return;

  final supplier = ref
      .read(suppliersProvider)
      .where((s) => s.id == invoice.supplierId)
      .firstOrNull;

  await layoutInvoicePrint(
    context,
    invoice,
    layout: choice.layout,
    supplier: supplier,
    profile: ref.read(businessProfileProvider),
  );
}

/// The build-and-print half of [printInvoice], split out so the invoice list
/// and the detail screen can share it.
Future<void> layoutInvoicePrint(
  BuildContext context,
  SupplierInvoice invoice, {
  required InvoicePrintLayout layout,
  Supplier? supplier,
  BusinessProfile? profile,
}) async {
  try {
    // Drawing an A4 page locally takes milliseconds, so there is no spinner to
    // show. The Windows print window then opens on top with the page ready.
    final printed = await Printing.layoutPdf(
      (format) => buildInvoicePdf(
        invoice,
        supplier: supplier,
        profile: profile,
        layout: layout,
      ),
      name: '${invoice.invoiceNumber} — ${layout.label}.pdf',
    );
    if (context.mounted && printed) {
      toast(context, 'Sent to printer.');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Could not print: $e');
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final InvoicePrintLayout layout;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (layout) {
      case InvoicePrintLayout.classicForm:
        return Icons.description_outlined;
      case InvoicePrintLayout.splitLedger:
        return Icons.view_column_outlined;
      case InvoicePrintLayout.paymentVoucher:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_icon, size: 20, color: selected ? scheme.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      layout.label,
                      style: texts.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      layout.blurb,
                      style: texts.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
