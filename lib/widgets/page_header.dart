import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'aurora_background.dart';

/// The heading every page opens with: a glassy panel with a glowing icon, the
/// page name, a line of context, and the actions for that page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accentIndex = 0,
    this.actions = const <Widget>[],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final int accentIndex;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Aurora.accent(accentIndex);

    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: isDark ? 0.20 : 0.13),
              Colors.white.withValues(alpha: isDark ? 0.06 : 0.55),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
          ),
          boxShadow: Aurora.glow(
            accent,
            opacity: isDark ? 0.22 : 0.14,
            blur: 26,
            y: 10,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mark = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: 14),
                ],
                if (icon != null) ...<Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[accent, Aurora.accent(accentIndex + 3)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                ],
              ],
            );

            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: texts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style:
                        texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );

            final buttons = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            );

            // Wide enough for the buttons beside the title: they hug the right
            // edge. Narrower than that and they take a line of their own, so a
            // squeezed window never runs them off the side.
            if (actions.isNotEmpty && constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[mark, Expanded(child: heading)],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              );
            }

            return Row(
              children: <Widget>[
                mark,
                Expanded(child: heading),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  buttons,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The empty state every list shares: a soft ring, a hint of what to do, and
/// the button that does it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accentIndex = 0,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final int accentIndex;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = Aurora.accent(accentIndex);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: FadeSlideIn(
          offset: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 120,
                height: 120,
                child: ParticleDrift(
                  color: accent.withValues(alpha: 0.55),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.04),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon, size: 34, color: accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: texts.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: texts.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
