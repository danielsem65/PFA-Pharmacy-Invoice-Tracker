import 'package:flutter/material.dart';

import '../models/supplier_invoice.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final InvoiceStatus status;

  Color get _background {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF0E7C4A);
      case InvoiceStatus.overdue:
        return const Color(0xFFC62828);
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFB26A00);
      case InvoiceStatus.open:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _background.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}