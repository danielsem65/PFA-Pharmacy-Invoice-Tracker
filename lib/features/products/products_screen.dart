import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../features/invoices/invoices_controller.dart';
import '../../models/product.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ui_kit.dart';
import 'products_controller.dart';

/// The room the chevron takes at the end of a row.
const double _chevronGutter = 40;

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final invoices = ref.watch(invoicesProvider);

    // How many invoices each catalogue name turns up on, counted once per
    // invoice so a product bought twice on one invoice still counts as one.
    final usedOn = <String, int>{};
    for (final inv in invoices) {
      final seen = <String>{};
      for (final line in inv.lines) {
        seen.add(line.name.trim().toLowerCase());
      }
      for (final name in seen) {
        usedOn[name] = (usedOn[name] ?? 0) + 1;
      }
    }

    final q = _query.trim().toLowerCase();
    final visible = products
        .where(
          (p) => q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.notes.toLowerCase().contains(q),
        )
        .toList();

    var inUse = 0;
    var priced = 0;
    var priceTotal = 0;
    for (final p in products) {
      if ((usedOn[p.normalizedName] ?? 0) > 0) inUse++;
      if (p.pricePerBoxPesewas > 0) {
        priced++;
        priceTotal += p.pricePerBoxPesewas;
      }
    }
    final averagePrice = priced == 0 ? 0 : (priceTotal / priced).round();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: 'Products',
              subtitle: '${products.length} '
                  '${products.length == 1 ? 'product' : 'products'} you buy — pick one while adding invoice items',
              icon: Icons.medication_liquid,
              accentIndex: 2,
              meta: <Widget>[
                MiniPill(
                  '$inUse in use',
                  icon: Icons.receipt_long_outlined,
                  dense: true,
                ),
              ],
              actions: <Widget>[
                MoreMenuButton(visibleProducts: visible),
                FilledButton.icon(
                  onPressed: () => context.go('/products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Product'),
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
                  hint: 'Search products…',
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
                    label: 'Products',
                    value: '${products.length}',
                    icon: Icons.medication_liquid_outlined,
                    gradient: StatCard.neutral,
                    delay: const Duration(milliseconds: 120),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'In use',
                    value: '$inUse',
                    icon: Icons.link_rounded,
                    gradient: StatCard.primary,
                    delay: const Duration(milliseconds: 190),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Average price',
                    value: formatPesewas(averagePrice),
                    icon: Icons.sell_outlined,
                    gradient: StatCard.money,
                    delay: const Duration(milliseconds: 260),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: visible.isEmpty
                ? const _EmptyProducts()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xxl,
                      0,
                      Insets.xxl,
                      Insets.xxl,
                    ),
                    child: TableScaffold(
                      header: const _ProductHeadings(),
                      footer: _ProductFooter(
                        shown: visible.length,
                        total: products.length,
                      ),
                      body: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final p = visible[index];
                          final count = usedOn[p.normalizedName] ?? 0;
                          return _ProductRow(
                            product: p,
                            accentIndex: index,
                            usedOn: count == 0
                                ? '—'
                                : '$count ${count == 1 ? 'invoice' : 'invoices'}',
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

class _ProductHeadings extends StatelessWidget {
  const _ProductHeadings();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        ColumnHeading('Product', flex: 36),
        ColumnHeading('Pieces/box', flex: 16, trailing: true),
        ColumnHeading('Price/box', flex: 20, trailing: true),
        ColumnHeading('Used on', flex: 16, trailing: true),
        SizedBox(width: _chevronGutter),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.usedOn,
    required this.accentIndex,
  });

  final Product product;
  final String usedOn;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return HoverRow(
      onTap: () => context.go('/products/${product.id}/edit'),
      stripe: Aurora.accent(accentIndex + 2),
      child: Row(
        children: <Widget>[
          TableCellBox(
            flex: 36,
            child: Row(
              children: <Widget>[
                AvatarTile(
                  name: product.name,
                  accentIndex: accentIndex + 2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        product.name,
                        style: texts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.notes.trim().isNotEmpty)
                        Text(
                          product.notes,
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
            flex: 16,
            align: CrossAxisAlignment.end,
            child: Text(
              '${product.piecesPerBox}',
              style: texts.bodyMedium,
            ),
          ),
          TableCellBox(
            flex: 20,
            align: CrossAxisAlignment.end,
            child: product.pricePerBoxPesewas > 0
                ? Money(product.pricePerBoxPesewas, tone: MoneyTone.normal)
                : Text('—', style: texts.bodyMedium),
          ),
          TableCellBox(
            flex: 16,
            align: CrossAxisAlignment.end,
            child: Text(
              usedOn,
              style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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

class _ProductFooter extends StatelessWidget {
  const _ProductFooter({required this.shown, required this.total});

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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.medication_outlined,
      title: 'No products yet',
      message:
          'Save the products you buy so their pack size and price are filled in '
          'for you when you add an invoice item.',
      accentIndex: 2,
      action: FilledButton.icon(
        onPressed: () => context.go('/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
    );
  }
}
