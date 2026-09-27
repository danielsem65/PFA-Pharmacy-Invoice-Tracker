import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Digits that line up on the decimal point, so a column of amounts reads as a
/// column rather than as a ragged list of numbers.
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// The card every overview panel sits in. Deliberately the same surface the
/// rest of the app already uses: a soft tint of the page, a hairline rim, and
/// a generous radius — nothing here invents a colour the app does not have.
BoxDecoration overviewPanelDecoration(
  BuildContext context, {
  double radius = 18,
}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surface.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}

/// The panel for something that wants a decision. The same card as everywhere
/// else, warmed towards red so the eye finds it before it reads it.
BoxDecoration alertPanelDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: Color.alphaBlend(
      Aurora.rose.withValues(alpha: isDark ? 0.12 : 0.07),
      scheme.surface.withValues(alpha: 0.55),
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Aurora.rose.withValues(alpha: 0.45)),
  );
}

/// The lighter well for the inside of a panel — a figure tile, a meter track.
/// Flat on purpose: the panel it sits in already reads as the raised surface.
BoxDecoration overviewWellDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.onSurface.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
  );
}

/// How loud a figure is allowed to be. Money reads differently depending on
/// whether it is the answer to a question or one line in a column of others.
enum MoneyTone { quiet, normal, strong, hero }

/// A money figure, drawn the same way everywhere.
///
/// Beyond the styling, a zero is quietened — a ledger full of ₵0.00 should not
/// shout.
class Money extends StatelessWidget {
  const Money(
    this.pesewas, {
    super.key,
    this.tone = MoneyTone.normal,
    this.color,
    this.emphasiseWhenZero = false,
    this.maxLines = 1,
  });

  final int pesewas;
  final MoneyTone tone;
  final Color? color;
  final bool emphasiseWhenZero;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    final TextStyle? style = switch (tone) {
      MoneyTone.quiet => texts.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: kTabularFigures,
          fontWeight: FontWeight.w600,
        ),
      MoneyTone.normal => texts.bodyMedium?.copyWith(
          fontFeatures: kTabularFigures,
          fontWeight: FontWeight.w700,
        ),
      MoneyTone.strong => texts.titleSmall?.copyWith(
          fontFeatures: kTabularFigures,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      MoneyTone.hero => texts.headlineSmall?.copyWith(
          fontFeatures: kTabularFigures,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          height: 1.05,
        ),
    };

    final muted = pesewas == 0 && !emphasiseWhenZero;
    return Text(
      formatPesewas(pesewas),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(
        color: color ??
            (muted ? scheme.onSurfaceVariant.withValues(alpha: 0.55) : null),
      ),
    );
  }
}

/// A rounded label: a count, a method, a stock level. The app's small tag.
class MiniPill extends StatelessWidget {
  const MiniPill(
    this.text, {
    super.key,
    this.color,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lead = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled ? lead : lead.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? lead : lead.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: dense ? 11 : 13,
              color: filled ? Colors.white : lead,
            ),
            SizedBox(width: dense ? 4 : 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.white : lead,
                fontSize: dense ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A letter avatar for a supplier, coloured by position in the list so the same
/// name always looks the same.
class AvatarTile extends StatelessWidget {
  const AvatarTile({
    super.key,
    required this.name,
    required this.accentIndex,
    this.size = 38,
  });

  final String name;
  final int accentIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final colors = Aurora.pair(accentIndex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// A hairline that can carry a name in the middle of it, for breaking a long
/// card into two readable halves.
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: texts.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A row that answers the pointer: tints on hover, dips on press, and can carry
/// a coloured stripe down its leading edge to say what state the row is in.
class HoverRow extends StatefulWidget {
  const HoverRow({
    super.key,
    required this.child,
    this.onTap,
    this.stripe,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? stripe;
  final EdgeInsets padding;

  @override
  State<HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<HoverRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered
                ? scheme.primary.withValues(alpha: 0.055)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.28),
              ),
              left: widget.stripe == null
                  ? BorderSide.none
                  : BorderSide(
                      color: widget.stripe!.withValues(alpha: 0.9),
                      width: 3,
                    ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: scheme.primary.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Opacity(
                opacity: _pressed ? 0.72 : 1,
                child: widget.padding == EdgeInsets.zero
                    ? widget.child
                    : Padding(
                        padding: widget.padding,
                        child: widget.child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin meter, for the share of a total an invoice eats or the stock left on
/// a shelf.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.animate = true,
  });

  /// 0 to 1.
  final double value;
  final Color? color;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lead = color ?? scheme.primary;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: scheme.onSurface.withValues(alpha: 0.07),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * clamped;
              if (!animate) {
                return SizedBox(
                  width: width,
                  height: height,
                  child: ColoredBox(color: lead),
                );
              }
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: width),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, w, _) => SizedBox(
                  width: w,
                  height: height,
                  child: ColoredBox(color: lead),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The tinted strip across the top of a panel that names it.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Colours the strip for a panel that is asking for attention. Null keeps
  /// the calm house tint.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lead = tint ?? scheme.primary;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            lead.withValues(alpha: 0.13),
            lead.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: tint == null
                ? scheme.outlineVariant.withValues(alpha: 0.5)
                : tint!.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// A panel title: a small tinted icon and a name.
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

/// A month-by-month column chart with a drawn line over it, used on the
/// overview to show what was bought against what was paid.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.labels,
    required this.primary,
    required this.primaryColor,
    this.secondary,
    this.secondaryColor,
    this.height = 168,
  });

  final List<String> labels;

  /// The tall bars.
  final List<double> primary;
  final Color primaryColor;

  /// The drawn line, drawn over the bars.
  final List<double>? secondary;
  final Color? secondaryColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = secondaryColor ?? scheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _TrendPainter(
                t: t,
                primary: primary,
                secondary: secondary,
                barColor: primaryColor,
                lineColor: line,
                grid: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.barColor,
    required this.lineColor,
    required this.grid,
  });

  final double t;
  final List<double> primary;
  final List<double>? secondary;
  final Color barColor;
  final Color lineColor;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || primary.isEmpty) return;
    final peak = <double>[...primary, ...?secondary].fold<double>(
          0,
          (a, b) => math.max(a, b),
        );
    if (peak <= 0) return;

    // Two quiet gridlines, enough to read the scale without a full axis.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / primary.length;
    final barWidth = math.min(slot * 0.42, 22.0);
    for (var i = 0; i < primary.length; i++) {
      final h = size.height * (primary[i] / peak) * t;
      final cx = slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barWidth / 2, size.height - h, barWidth, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              barColor.withValues(alpha: 0.45),
              barColor,
            ],
          ).createShader(rect.outerRect),
      );
    }

    final values = secondary;
    if (values == null || values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = slot * i + slot / 2;
      final eased = size.height * (values[i] / peak) * t;
      final y = size.height - eased;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final x = slot * i + slot / 2;
      final y = size.height - size.height * (values[i] / peak) * t;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = lineColor);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.t != t || old.primary != primary || old.secondary != secondary;
}

/// A titled card for the overview, where there is no table to frame but the
/// page still needs a name and a body.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
    this.trailing,
    this.accentIndex = 0,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final int accentIndex;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = Aurora.pair(accentIndex);
    return Container(
      decoration: overviewPanelDecoration(context),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon!, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: texts.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: texts.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
