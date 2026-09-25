import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../features/invoices/invoices_controller.dart';
import '../../models/product.dart';
import '../../widgets/more_menu_button.dart';
import 'products_controller.dart';

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
    final scheme = Theme.of(context).colorScheme;

    final q = _query.trim().toLowerCase();
    final visible = products
        .where(
          (p) => q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.notes.toLowerCase().contains(q),
        )
        .toList();

    int usedIn(String normalizedName) {
      var count = 0;
      for (final inv in invoices) {
        for (final line in inv.lines) {
          if (line.name.trim().toLowerCase() == normalizedName) {
            count++;
            break;
          }
        }
      }
      return count;
    }

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
                        'Products',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${products.length} ${products.length == 1 ? 'product' : 'products'} you buy — pick one while adding invoice items',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                MoreMenuButton(visibleProducts: visible),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => context.go('/products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Product'),
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
                      hintText: 'Search products…',
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
                ? const _EmptyProducts()
                : _ProductTable(
                    products: visible,
                    usedIn: usedIn,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.usedIn,
  });

  final List<Product> products;
  final int Function(String normalizedName) usedIn;

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
                  flex: 40,
                  child: Text('Product', style: headerStyle),
                ),
                Expanded(
                  flex: 18,
                  child: Text(
                    'Pieces per box',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'Price per box',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: Text(
                    'Used on',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                final count = usedIn(p.normalizedName);
                return _ProductRow(
                  product: p,
                  usedOn: count == 0
                      ? '—'
                      : '$count ${count == 1 ? 'invoice' : 'invoices'}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.usedOn,
  });

  final Product product;
  final String usedOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/products/${product.id}/edit'),
          hoverColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 40,
                  child: Row(
                    children: [
                      _ProductAvatar(name: product.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: texts.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product.notes.trim().isNotEmpty)
                              Text(
                                product.notes,
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
                  flex: 18,
                  child: Text(
                    '${product.piecesPerBox}',
                    textAlign: TextAlign.right,
                    style: texts.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    product.pricePerBoxPesewas > 0
                        ? formatPesewas(product.pricePerBoxPesewas)
                        : '—',
                    textAlign: TextAlign.right,
                    style: texts.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: Text(
                    usedOn,
                    textAlign: TextAlign.right,
                    style: texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.name});

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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

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
              Icons.medication_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('No products yet', style: texts.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Save the products you buy so their pack size and price are '
              'filled in for you when you add an invoice item.',
              style: texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ],
        ),
      ),
    );
  }
}
