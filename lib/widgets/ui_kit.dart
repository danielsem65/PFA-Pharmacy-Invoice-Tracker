import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'aurora_background.dart';
import 'glass_panel.dart';

/// How loud a figure is allowed to be. Money reads differently depending on
/// whether it is the answer to a question or one line in a column of others.
enum MoneyTone { quiet, normal, strong, hero }

/// A money figure, drawn the same way everywhere.
///
/// Beyond the styling, the digits are tabular so a column of amounts lines up
/// on the decimal point, and a zero is quietened — a ledger full of ₵0.00
/// should not shout.
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
          fontFeatures: AppTokens.tabularFigures,
          fontWeight: FontWeight.w600,
        ),
      MoneyTone.normal => texts.bodyMedium?.copyWith(
          fontFeatures: AppTokens.tabularFigures,
          fontWeight: FontWeight.w700,
        ),
      MoneyTone.strong => texts.titleSmall?.copyWith(
          fontFeatures: AppTokens.tabularFigures,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      MoneyTone.hero => texts.headlineSmall?.copyWith(
          fontFeatures: AppTokens.tabularFigures,
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

/// The glowing gradient tile that marks a page or names a panel.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.accentIndex = 0,
    this.size = TileSize.medium,
    this.color,
  });

  final IconData icon;
  final int accentIndex;
  final TileSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lead = color ?? Aurora.accent(accentIndex);
    final pair = color == null
        ? <Color>[lead, Aurora.accent(accentIndex + 3)]
        : <Color>[lead, Color.lerp(lead, Colors.white, 0.35)!];
    return Container(
      width: size.box,
      height: size.box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
        borderRadius: BorderRadius.circular(size.radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: lead.withValues(alpha: 0.38),
            blurRadius: size == TileSize.large ? 16 : 10,
            offset: Offset(0, size == TileSize.large ? 6 : 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size.icon),
    );
  }
}

/// A letter avatar for a supplier or a product, coloured by position in the
/// list so the same name always looks the same.
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
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.first.withValues(alpha: 0.32),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.11),
          ),
        ],
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

/// One cell of a table row or of its heading row.
///
/// Every column in the app is built from these, so a heading always sits above
/// the figure it names with the same inset and the same alignment.
class TableCellBox extends StatelessWidget {
  const TableCellBox({
    super.key,
    required this.child,
    this.flex = 1,
    this.align = CrossAxisAlignment.start,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  });

  final Widget child;
  final int flex;
  final CrossAxisAlignment align;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding,
        child: Align(
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
    );
  }
}

/// A column heading: quiet, spaced, and never wrapped into two lines.
class ColumnHeading extends StatelessWidget {
  const ColumnHeading(
    this.label, {
    super.key,
    this.flex = 1,
    this.trailing = false,
  });

  final String label;
  final int flex;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return TableCellBox(
      flex: flex,
      align: trailing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: panelHeadingStyle(context),
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

/// The search box every list opens with.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.widthFactor = 4,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  /// How much of the filter bar the field claims next to the dropdowns.
  final int widthFactor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppTokens.of(context);
    return Expanded(
      flex: widthFactor,
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: tokens.surfaceRaised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            borderSide: BorderSide(color: tokens.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            borderSide: BorderSide(color: tokens.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// A dropdown filter, styled as a field so it sits in the bar with the search
/// box instead of looking like a stray menu.
class FilterSelect<T> extends StatelessWidget {
  const FilterSelect({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.wrapperKey,
    this.buttonKey,
    this.flex = 1,
  });

  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  /// Put on the outer frame, for finders that aim at the whole control.
  final Key? wrapperKey;

  /// Put on the button itself.
  final Key? buttonKey;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppTokens.of(context);
    return Flexible(
      flex: flex,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          key: wrapperKey,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: tokens.surfaceRaised,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: tokens.hairline),
          ),
          child: DropdownButton<T>(
            key: buttonKey,
            value: value,
            hint: Text(hint),
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            icon: Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// The rounded bar that holds a page's search field and its filters.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children, this.delay});

  final List<Widget> children;
  final Duration? delay;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final child = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(color: tokens.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 10),
            children[i],
          ],
        ],
      ),
    );
    return delay == null
        ? child
        : FadeSlideIn(delay: delay!, child: child);
  }
}

/// A panel wrapped for tabular data: a frosted card, an optional heading strip
/// that holds either a name or the column titles, and an optional footer for
/// totals.
class TableScaffold extends StatelessWidget {
  const TableScaffold({
    super.key,
    required this.body,
    this.header,
    this.title,
    this.titleIcon,
    this.accentIndex = 0,
    this.footer,
    this.headerTrailing,
  });

  final Widget body;
  final Widget? header;
  final String? title;
  final IconData? titleIcon;
  final int accentIndex;
  final Widget? footer;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTokens.of(context).radiusLg,
      child: Column(
        children: <Widget>[
          if (title != null)
            PanelHeader(
              child: PanelTitle(
                title: title!,
                icon: titleIcon,
                trailing: headerTrailing,
              ),
            )
          else if (header != null)
            PanelHeader(padding: EdgeInsets.zero, child: header!),
          Expanded(child: body),
          if (footer != null)
            PanelFooter(child: footer!),
        ],
      ),
    );
  }
}

/// The strip along the bottom of a panel — totals, counts, hints.
class PanelFooter extends StatelessWidget {
  const PanelFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// A row of a table that answers the pointer: tints on hover, dips on press,
/// and can carry a coloured stripe down its leading edge to say what state the
/// thing in the row is in.
class HoverRow extends StatefulWidget {
  const HoverRow({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTap,
    this.stripe,
    this.selected = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final Color? stripe;
  final bool selected;
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
            color: widget.selected
                ? scheme.primary.withValues(alpha: 0.12)
                : _hovered
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
              onSecondaryTap: widget.onSecondaryTap,
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

/// A thin meter, for the share of a budget an invoice eats or the stock left
/// on a shelf.
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
    final tokens = AppTokens.of(context);
    final lead = color ?? Theme.of(context).colorScheme.primary;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: tokens.sunken,
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

/// A keyboard shortcut, drawn as a key. Used by the shortcuts sheet and by any
/// control that wants to advertise its accelerator.
class Kbd extends StatelessWidget {
  const Kbd(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// One bar in a small chart. Grows from the baseline when it first appears, so
/// a dashboard settles into place instead of snapping.
class SparkBar extends StatelessWidget {
  const SparkBar({
    super.key,
    required this.value,
    required this.color,
    this.secondaryValue,
  });

  final double value;
  final Color color;
  final double? secondaryValue;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        painter: _SparkBarPainter(
          value: v,
          secondary: secondaryValue,
          color: color,
          dim: Theme.of(context).brightness == Brightness.dark,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparkBarPainter extends CustomPainter {
  _SparkBarPainter({
    required this.value,
    required this.secondary,
    required this.color,
    required this.dim,
  });

  final double value;
  final double? secondary;
  final Color color;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final secondaryHeight = size.height * (secondary ?? 0).clamp(0.0, 1.0);
    if (secondary != null && secondaryHeight > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            0,
            size.height - secondaryHeight,
            size.width,
            secondaryHeight,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: 0.22),
      );
    }
    final h = size.height * value.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - h, size.width, h),
        const Radius.circular(3),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            color.withValues(alpha: dim ? 0.55 : 0.75),
            color,
          ],
        ).createShader(
          Rect.fromLTWH(0, size.height - h, size.width, h),
        ),
    );
  }

  @override
  bool shouldRepaint(_SparkBarPainter old) =>
      old.value != value || old.secondary != secondary || old.color != color;
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

/// A titled card for the settings and import pages, where there is no table to
/// frame but the same frosted language still applies.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
    this.trailing,
    this.accentIndex = 0,
    this.padding = Insets.card,
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
    return GlassPanel(
      radius: AppTokens.of(context).radiusLg,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  IconTile(
                    icon: icon!,
                    accentIndex: accentIndex,
                    size: TileSize.small,
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
            const SizedBox(height: Insets.lg),
            ..._gaps(children, Insets.md),
          ],
        ),
      ),
    );
  }
}

/// Gaps between the children of a card, without a Column per row.
List<Widget> _gaps(List<Widget> items, double gap) => <Widget>[
      for (var i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: gap),
        items[i],
      ],
    ];
