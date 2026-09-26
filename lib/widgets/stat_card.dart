import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'aurora_background.dart';

/// A number worth noticing: a coloured icon, a quiet label, the figure itself.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.compact = false,
    this.width,
    this.delay = Duration.zero,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final bool compact;

  /// Fixed width when a caller wants an even row of tiles; null lets the card
  /// grow to whatever the label needs, so nothing is cut short.
  final double? width;
  final Duration delay;

  static final List<Color> primary = <Color>[Aurora.teal, Aurora.indigo];
  static final List<Color> danger = <Color>[Aurora.rose, Aurora.amber];
  static final List<Color> neutral = <Color>[Aurora.sky, Aurora.violet];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lead = gradient.isEmpty ? scheme.primary : gradient.first;

    return FadeSlideIn(
      delay: delay,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minWidth: 96, minHeight: 92),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: lead.withValues(alpha: 0.20)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: lead.withValues(alpha: isDark ? 0.20 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: texts.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 10 : 11,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texts.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  fontSize: compact ? 17 : 21,
                  height: 1.05,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
