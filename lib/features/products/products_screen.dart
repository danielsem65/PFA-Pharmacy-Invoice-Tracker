import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../features/invoices/invoices_controller.dart';
import '../../models/product.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/more_menu_button.dart';
import '../../widgets/page_header.dart';
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
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: PageHeader(
              title: 'Products',
              subtitle:
                  '${products.length} ${products.length == 1 ? 'product' : 'products'} you buy — pick one while adding invoice items',
              icon: Icons.medication_liquid,
              accentIndex: 2,
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
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 70),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Aurora.violet.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.primary.withValues(alpha: 0.04),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            ),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final count = usedIn(p.normalizedName);
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
          ],
        ),
      ),
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
                      _ProductAvatar(
                        name: product.name,
                        accentIndex: accentIndex,
                      ),
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
                        ?.copyWith(fontWeight: FontWeight.w700),
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
  const _ProductAvatar({required this.name, required this.accentIndex});

  final String name;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final colors = Aurora.pair(accentIndex + 2);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
