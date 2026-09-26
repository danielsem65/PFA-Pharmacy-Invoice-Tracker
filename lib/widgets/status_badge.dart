import 'package:flutter/material.dart';

import '../models/supplier_invoice.dart';

/// The coloured pill that says where an invoice stands: settled, overdue,
/// part-paid or still open.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final InvoiceStatus status;

  /// The colour that stands for this status, so a row can pick it up for its
  /// own accent without repeating the mapping.
  static Color colorOf(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF0E9F6E);
      case InvoiceStatus.overdue:
        return const Color(0xFFE11D48);
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFEA9A0B);
      case InvoiceStatus.open:
        return const Color(0xFF0284C7);
    }
  }

  /// A darker twin of the same hue, for text that sits on a light background.
  static Color inkOf(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF046C4E);
      case InvoiceStatus.overdue:
        return const Color(0xFF9F1239);
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFF92400E);
      case InvoiceStatus.open:
        return const Color(0xFF075985);
    }
  }

  /// The glyph that goes with the word, so the state reads at a glance.
  static IconData iconOf(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Icons.check_circle_rounded;
      case InvoiceStatus.overdue:
        return Icons.error_rounded;
      case InvoiceStatus.partiallyPaid:
        return Icons.timelapse_rounded;
      case InvoiceStatus.open:
        return Icons.schedule_rounded;
    }
  }

  Color get _background => colorOf(status);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _background;

    if (isDark) {
      return _Pill(
        colors: <Color>[color.withValues(alpha: 0.28), color.withValues(alpha: 0.18)],
        border: color.withValues(alpha: 0.5),
        dot: color,
        foreground: Colors.white,
        label: status.label,
        glow: color,
        icon: iconOf(status),
      );
    }
    return _Pill(
      colors: <Color>[color.withValues(alpha: 0.16), color.withValues(alpha: 0.08)],
      border: color.withValues(alpha: 0.32),
      dot: color,
      foreground: inkOf(status),
      label: status.label,
      glow: color,
      icon: iconOf(status),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.colors,
    required this.border,
    required this.dot,
    required this.foreground,
    required this.label,
    required this.glow,
    required this.icon,
  });

  final List<Color> colors;
  final Color border;
  final Color dot;
  final Color foreground;
  final String label;
  final Color glow;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: glow.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
