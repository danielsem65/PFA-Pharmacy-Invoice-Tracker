import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../models/supplier.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ui_kit.dart';
import '../invoices/invoices_controller.dart';
import 'suppliers_controller.dart';

/// The room the chevron takes at the end of a row.
const double _chevronGutter = 40;

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

    final owed = <String, int>{};
    final billed = <String, int>{};
    for (final inv in invoices) {
      billed[inv.supplierId] = (billed[inv.supplierId] ?? 0) + 1;
      if (inv.balancePesewas > 0) {
        owed[inv.supplierId] = (owed[inv.supplierId] ?? 0) + inv.balancePesewas;
      }
    }

    final q = _query.trim().toLowerCase();
    final visible = suppliers
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

    var totalOwed = 0;
    var owingCount = 0;
    for (final s in suppliers) {
      final amount = owed[s.id] ?? 0;
      if (amount <= 0) continue;
      totalOwed += amount;
      owingCount++;
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: 'Suppliers',
              subtitle: '${suppliers.length} '
                  '${suppliers.length == 1 ? 'distributor' : 'distributors'} you buy stock from',
              icon: Icons.local_shipping,
              accentIndex: 2,
              meta: <Widget>[
                MiniPill(
                  '$owingCount still owing',
                  icon: Icons.account_balance_wallet_outlined,
                  dense: true,
                ),
              ],
              actions: <Widget>[
                FilledButton.icon(
                  onPressed: () => context.go('/suppliers/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Supplier'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
            child: FilterBar(
              delay: const Duration(milliseconds: 70),
              children: <Widget>[
                SearchField(
                  hint: 'Search suppliers…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.md, Insets.xxl, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'Owed to suppliers',
                    value: formatPesewas(totalOwed),
                    icon: Icons.account_balance_wallet_outlined,
                    gradient: StatCard.primary,
                    delay: const Duration(milliseconds: 120),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'With a balance',
                    value: '$owingCount',
                    icon: Icons.pending_actions_outlined,
                    gradient: StatCard.warn,
                    delay: const Duration(milliseconds: 190),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Suppliers',
                    value: '${suppliers.length}',
                    icon: Icons.local_shipping_outlined,
                    gradient: StatCard.neutral,
                    delay: const Duration(milliseconds: 260),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: visible.isEmpty
                ? const _EmptySuppliers()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xxl,
                      0,
                      Insets.xxl,
                      Insets.xxl,
                    ),
                    child: TableScaffold(
                      header: const _SupplierHeadings(),
                      footer: _SupplierFooter(
                        shown: visible.length,
                        total: suppliers.length,
                      ),
                      body: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final s = visible[index];
                          return _SupplierRow(
                            supplier: s,
                            owed: owed[s.id] ?? 0,
                            invoices: billed[s.id] ?? 0,
                            accentIndex: index,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierHeadings extends StatelessWidget {
  const _SupplierHeadings();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        ColumnHeading('Supplier', flex: 34),
        ColumnHeading('Contact', flex: 26),
        ColumnHeading('Invoices', flex: 12),
        ColumnHeading('Outstanding', flex: 16, trailing: true),
        SizedBox(width: _chevronGutter),
      ],
    );
  }
}

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({
    required this.supplier,
    required this.owed,
    required this.invoices,
    required this.accentIndex,
  });

  final Supplier supplier;
  final int owed;
  final int invoices;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final contact = [supplier.phone, supplier.location]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');
    final settled = owed <= 0;

    return HoverRow(
      onTap: () => context.go('/suppliers/${supplier.id}/edit'),
      stripe: settled ? AppTokens.of(context).success : AppTokens.of(context).warning,
      child: Row(
        children: <Widget>[
          TableCellBox(
            flex: 34,
            child: Row(
              children: <Widget>[
                AvatarTile(name: supplier.name, accentIndex: accentIndex),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        supplier.name,
                        style: texts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (supplier.notes.trim().isNotEmpty)
                        Text(
                          supplier.notes,
                          style: texts.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TableCellBox(
            flex: 26,
            child: Text(
              contact.isEmpty ? '—' : contact,
              style: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TableCellBox(
            flex: 12,
            child: Text(
              '$invoices',
              style: texts.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TableCellBox(
            flex: 16,
            align: CrossAxisAlignment.end,
            child: settled
                ? MiniPill(
                    'Settled',
                    color: AppTokens.of(context).success,
                    dense: true,
                  )
                : Money(
                    owed,
                    tone: MoneyTone.strong,
                    color: scheme.error,
                  ),
          ),
          SizedBox(
            width: _chevronGutter,
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierFooter extends StatelessWidget {
  const _SupplierFooter({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      shown == total ? '$shown of $total shown' : '$shown of $total shown, filtered',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _EmptySuppliers extends StatelessWidget {
  const _EmptySuppliers();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'No suppliers yet',
      message: 'Add the distributors you buy medicines from.',
      accentIndex: 2,
    );
  }
}
