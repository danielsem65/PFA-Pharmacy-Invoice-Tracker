import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design.dart';

/// A pane of real glass.
///
/// Everything else in the app that wants to look frosted builds on this, and
/// the three things that separate glass from a translucent rectangle all live
/// here so no caller can forget one:
///
///  1. a genuine [BackdropFilter] blur of whatever is painted behind it, not
///     just a lower alpha on the fill;
///  2. a rim that catches light on the side facing the light source and falls
///     away on the other, painted by [_GlassRimPainter];
///  3. the caustic highlight along the top inside edge that a real pane of
///     glass throws onto whatever is behind it.
///
/// The blur is the expensive part. It costs a full-window readback per pane per
/// frame, so the rule the whole app follows is one blur per visual plane: the
/// backdrop, the chrome, and each card. Anything sitting *inside* an already
/// blurred pane uses [GlassInset], which is flat on purpose.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.regular,
    this.radius,
    this.tint,
    this.accent,
    this.sides = GlassSides.all,
    this.shadows = true,
    this.clip = true,
    this.sheen = true,
  });

  final Widget child;

  /// How hard this pane frosts its backdrop, and how far it lifts off the page.
  final GlassLevel level;

  /// Overrides the corner radius; defaults to the app's panel radius.
  final double? radius;

  /// Replaces the fill for this pane, keeping the rim and the blur.
  final Color? tint;

  /// Pushes the rim's bright side toward a colour instead of plain white, so a
  /// panel can belong to one page without tinting its whole surface.
  final Color? accent;

  /// Which edges get a rim. A toolbar that runs off the right of the window
  /// should not draw a vertical line down its middle.
  final GlassSides sides;

  /// Off for panes that are stacked flush against each other, where a shadow
  /// between them just reads as a smudge.
  final bool shadows;

  /// Off when the child paints its own corners and must not be cut off.
  final bool clip;

  /// Off for panes that hold something dense, where the top-light gradient
  /// would only compete with the content.
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final glass = AppTokens.of(context).glass;
    final r = radius ?? AppTokens.of(context).radius;
    final shape = BorderRadius.circular(r);
    final fill = tint ?? glass.tintFor(level);

    final pane = BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: level.sigma, sigmaY: level.sigma),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          gradient: sheen ? glass.sheen : null,
          borderRadius: shape,
        ),
        child: CustomPaint(
          foregroundPainter: _GlassRimPainter(
            radius: r,
            glass: glass,
            sides: sides,
            accent: accent,
            edge: level == GlassLevel.thin || level == GlassLevel.regular
                ? 1.0
                : 1.2,
          ),
          child: child,
        ),
      ),
    );

    if (!shadows) {
      return clip ? ClipRRect(borderRadius: shape, child: pane) : pane;
    }

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: glass.shadow),
      child: clip ? ClipRRect(borderRadius: shape, child: pane) : pane,
    );
  }
}

/// Which edges of a pane carry a rim.
///
/// The `has` prefix keeps these clear of the enum values themselves, which are
/// static members of this class.
enum GlassSides {
  all,
  top,
  bottom,
  left,
  right,
  horizontal,
  none;

  bool get hasTop => this == all || this == top || this == horizontal;

  bool get hasBottom => this == all || this == bottom || this == horizontal;

  bool get hasLeft => this == all || this == left;

  bool get hasRight => this == all || this == right;

  bool get hasAny => this != none;
}

/// The rim itself: a gradient stroke that is bright where the light is and dim
/// where it is not, plus a soft caustic band just inside the top edge.
///
/// A flat one-pixel border is what makes a translucent rectangle look like a
/// rectangle. Giving the stroke a direction is what makes it look like an edge
/// of a solid that happens to be clear.
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.radius,
    required this.glass,
    required this.sides,
    required this.accent,
    required this.edge,
  });

  final double radius;
  final GlassTokens glass;
  final GlassSides sides;
  final Color? accent;
  final double edge;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !sides.hasAny) return;
    final rect = Offset.zero & size;

    // The caustic light along the top, clipped inside the pane so it fades out
    // rather than ending at a hard line.
    if (sides.hasTop) {
      final inner = rect.deflate(edge + 0.5);
      if (inner.width > 0 && inner.height > 0) {
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(radius)));
        canvas.drawRect(
          Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.55),
          Paint()
            ..shader = ui.Gradient.linear(
              inner.topCenter,
              Offset(inner.left, inner.top + inner.height * 0.55),
              <Color>[glass.highlight, glass.highlight.withValues(alpha: 0)],
            ),
        );
        canvas.restore();
      }
    }

    if (radius <= 0) {
      _paintSides(canvas, rect);
      return;
    }
    final rrect = RRect.fromRectAndRadius(rect.deflate(edge / 2), Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          <Color>[
            accent ?? glass.edgeLight,
            glass.rim,
            glass.edgeDim,
          ],
          <double>[0, 0.45, 1],
        ),
    );
  }

  /// A square pane cannot be stroked with a rounded path, so each edge that
  /// wants a rim gets its own line.
  void _paintSides(Canvas canvas, Rect rect) {
    void line(Offset from, Offset to, Color color) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = edge
          ..color = color,
      );
    }

    if (sides.hasTop) {
      line(
        rect.topLeft,
        rect.topRight,
        Color.lerp(accent ?? glass.edgeLight, glass.edgeDim, 0.25)!,
      );
    }
    if (sides.hasBottom) {
      line(
        rect.bottomLeft,
        rect.bottomRight,
        glass.edgeDim,
      );
    }
    if (sides.hasLeft) {
      line(
        rect.topLeft,
        rect.bottomLeft,
        glass.edgeDim,
      );
    }
    if (sides.hasRight) {
      line(
        rect.topRight,
        rect.bottomRight,
        glass.edgeDim,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter old) =>
      old.radius != radius ||
      old.sides != sides ||
      old.edge != edge ||
      old.accent != accent ||
      old.glass != glass;
}

/// A surface nested inside an already-blurred pane.
///
/// This is a flat fill with a hairline and a faint inner shadow. It looks
/// almost identical to [GlassSurface] over a card, costs a fraction of a frame,
/// and keeps the blur count from multiplying as panels get nested.
class GlassInset extends StatelessWidget {
  const GlassInset({
    super.key,
    required this.child,
    this.radius,
    this.color,
    this.border,
    this.padding,
  });

  final Widget child;
  final double? radius;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final r = radius ?? tokens.radiusSm;
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.sunken,
        borderRadius: BorderRadius.circular(r),
        border: border ?? Border.all(color: tokens.hairline),
        boxShadow: <BoxShadow>[
          // An inner shadow, so the well reads as cut into the pane above it
          // rather than stuck onto it.
          BoxShadow(
            color: tokens.glass.edgeDim.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// A small blurred chip: a filter pill, a count badge, a tab.
///
/// Chips sit directly on a page rather than inside a card, so this is a case
/// where the blur genuinely has something to do.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.radius,
    this.tint,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final Widget child;
  final double? radius;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      level: GlassLevel.thin,
      radius: radius ?? AppTokens.of(context).radiusPill,
      tint: tint,
      shadows: false,
      sheen: false,
      sides: GlassSides.all,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A blurred bar for chrome: the sidebar, the title bar, a sticky toolbar.
///
/// [sides] decides which edges get a rim, so a bar that runs off the edge of
/// the window does not draw a line down its own middle.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.level = GlassLevel.thick,
    this.sides = GlassSides.right,
    this.padding,
    this.shadows = false,
  });

  final Widget child;
  final GlassLevel level;
  final GlassSides sides;
  final EdgeInsetsGeometry? padding;
  final bool shadows;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      level: level,
      radius: 0,
      sides: sides,
      shadows: shadows,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}
