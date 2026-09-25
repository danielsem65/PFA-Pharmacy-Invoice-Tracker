import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/supplier.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';

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
    final texts = Theme.of(context).textTheme;

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
      appBar: AppBar(
        title: const Text('Suppliers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search suppliers…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const _EmptySuppliers()
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final s = visible[index];
                      final owe = owedBy(s);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(s.name.isEmpty ? '?' : s.name[0]),
                        ),
                        title: Text(s.name),
                        subtitle: Text(
                          [s.phone, s.location]
                              .where((e) => e.trim().isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          owe > 0 ? 'You owe ${formatPesewas(owe)}' : '',
                          style: texts.bodyMedium?.copyWith(
                            color: owe > 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => context.go('/suppliers/${s.id}/edit'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/suppliers/new'),
        icon: const Icon(Icons.add),
        label: const Text('Supplier'),
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