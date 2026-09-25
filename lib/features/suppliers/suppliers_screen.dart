import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/supplier.dart';
import '../invoices/invoices_controller.dart';
import 'suppliers_controller.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final invoices = ref.watch(invoicesProvider);
    final scheme = Theme.of(context).colorScheme;

    int owedBy(Supplier s) {
      var total = 0;
      for (final inv in invoices) {
        if (inv.supplierId == s.id) total += inv.balancePesewas;
      }
      return total;
    }

    final q = _query.trim().toLowerCase();
    final visible = suppliers
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suppliers',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${suppliers.length} ${suppliers.length == 1 ? 'distributor' : 'distributors'} you buy stock from',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/suppliers/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Supplier'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search suppliers…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: visible.isEmpty
                ? const _EmptySuppliers()
                : _SupplierTable(
                    suppliers: visible,
                    owedBy: owedBy,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierTable extends StatelessWidget {
  const _SupplierTable({required this.suppliers, required this.owedBy});

  final List<Supplier> suppliers;
  final int Function(Supplier) owedBy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: const EdgeInsets.fromLTRB(24, 0, 16, 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 30,
                  child: Text('Supplier',
                      style: headerStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 22,
                  child: Text('Contact',
                      style: headerStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 18,
                  child: Text(
                    'Outstanding',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final s = suppliers[index];
                return _SupplierRow(supplier: s, owed: owedBy(s));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({required this.supplier, required this.owed});

  final Supplier supplier;
  final int owed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final contact = [supplier.phone, supplier.location]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/suppliers/${supplier.id}/edit'),
          hoverColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 30,
                  child: Row(
                    children: [
                      _Avatar(name: supplier.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: texts.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (supplier.notes.trim().isNotEmpty)
                              Text(
                                supplier.notes,
                                style: texts.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 22,
                  child: Text(
                    contact.isEmpty ? '—' : contact,
                    style: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 18,
                  child: owed > 0
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatPesewas(owed),
                              style: texts.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Settled',
                            style: texts.labelMedium?.copyWith(
                              color: const Color(0xFF0E7C4A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7490), Color(0xFF0F9D77)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptySuppliers extends StatelessWidget {
  const _EmptySuppliers();

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('No suppliers yet', style: texts.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add the distributors you buy medicines from.',
              style: texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}