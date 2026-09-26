import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/theme.dart';
import 'aurora_background.dart';

/// A number worth noticing: a coloured icon, a quiet label, the figure itself,
/// and optionally the line of context that makes the figure mean something.
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
    this.hint,
    this.accent,
    this.onTap,
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

  /// A quieter line under the figure: a share, a period, a comparison.
  final String? hint;

  /// Overrides the icon colour when the figure means something specific, such
  /// as a balance that is overdue.
  final Color? accent;

  /// Makes the whole tile a button.
  final VoidCallback? onTap;

  static final List<Color> primary = <Color>[Aurora.teal, Aurora.indigo];
  static final List<Color> danger = <Color>[Aurora.rose, Aurora.amber];
  static final List<Color> neutral = <Color>[Aurora.sky, Aurora.violet];
  static final List<Color> money = <Color>[Aurora.emerald, Aurora.teal];
  static final List<Color> warn = <Color>[Aurora.amber, Aurora.rose];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = AppTokens.of(context);
    final lead = accent ?? (gradient.isEmpty ? scheme.primary : gradient.first);

    final tile = Container(
      width: width,
      constraints: BoxConstraints(minWidth: 96, minHeight: compact ? 82 : 92),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: Frost.panel(
        context,
        radius: tokens.radius,
        tint: lead,
        fill: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.72),
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
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: lead.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                color: accent ?? scheme.onSurface,
                fontFeatures: AppTokens.tabularFigures,
              ),
            ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    final body = onTap == null
        ? tile
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            // The tile paints its own background, so the Material underneath is
            // only there to catch the ink.
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(tokens.radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(tokens.radius),
                child: tile,
              ),
            ),
          );

    return FadeSlideIn(delay: delay, child: body);
  }
}
