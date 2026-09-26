import 'package:flutter/material.dart';

import '../core/design.dart';

/// The frosted card every list and detail page sits in: a translucent panel
/// with a soft primary glow, so the aurora behind it shows through faintly.
/// Shared rather than copied, so a page and the list it belongs to cannot drift
/// apart.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.clip = true,
    this.tint,
  });

  final Widget child;
  final double radius;

  /// Set false when the content draws its own corners and must not be clipped.
  final bool clip;

  /// Colours the border and the glow when a panel belongs to one page rather
  /// than to the app in general.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Frost.panel(context, radius: radius, tint: tint),
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            )
          : child,
    );
  }
}

/// The tinted strip across the top of a [GlassPanel] that names it, or carries
/// the column headings of a table.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primary.withValues(alpha: 0.10),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppTokens.of(context).hairline),
        ),
      ),
      child: child,
    );
  }
}

/// The heading style the panel strips share, so every column label in the app
/// reads the same.
TextStyle panelHeadingStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ) ??
      TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      );
}
/// A panel title: a small tinted icon and a name, in the manner of [FormSection]
/// but sitting on the frosted panel rather than in a form.
class PanelTitle extends StatelessWidget {
  const PanelTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
