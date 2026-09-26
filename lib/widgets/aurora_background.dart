import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The sky the app sits on: slow colour blooms with a drift of small particles
/// across them.
///
/// The drift is a one-off entrance rather than a loop that never ends. A
/// permanently running animation would repaint the whole window forever for
/// something nobody watches, and it would leave the test suite waiting for a
/// frame that never comes. This settles after a couple of seconds and then
/// simply sits there.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.seed = 0, this.density = 1, this.grain = true});

  /// Varies the layout a little between screens, so two pages never show the
  /// exact same sky.
  final int seed;

  /// Scales the particle count, for places that want a quieter backdrop.
  final double density;

  /// The anti-banding film. Off for places where the sky is already being
  /// covered by something busy.
  final bool grain;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Asked here rather than in initState: reading an inherited widget is only
    // allowed once the element is attached to the tree.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _drift.value = 1;
    } else {
      _drift.forward();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              return CustomPaint(
                painter: _AuroraPainter(
                  t: Curves.easeOutCubic.transform(_drift.value),
                  seed: widget.seed,
                  density: widget.density,
                  strength: isDark ? 0.5 : 0.62,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Grain sits on its own layer so it is painted once rather than on
          // every frame of the intro, and so the blur never has to work around
          // it.
          if (widget.grain)
            const CustomPaint(painter: _GrainPainter(), size: Size.infinite),
        ],
      ),
    );
  }
}

/// A very fine film of noise over the whole sky.
///
/// Blurring a large, smooth gradient is exactly how an 8-bit display shows its
/// stripes: the banding appears in the flat areas, and a blur widens those
/// areas. A scatter of single-pixel dots at a couple of percent opacity is
/// invisible as texture and completely removes the stripes. It is deliberately
/// a separate painter that never repaints.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  static const int _dots = 2600;

  /// Half the specks catch the light and half sit in the shadow, so the film
  /// has both directions in it rather than reading as a grey haze.
  static const List<_GrainPass> _grainPasses = <_GrainPass>[
    _GrainPass(0, Color(0x06FFFFFF)),
    _GrainPass(1, Color(0x06000000)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Two passes, so the light and the dark specks are batched into two draw
    // calls rather than one per speck.
    for (final pass in _grainPasses) {
      final dots = <Offset>[];
      for (var i = pass.seed; i < _dots; i += 2) {
        // Fixed seeds, so the grain is in the same place every repaint and does
        // not crawl when something above it changes.
        dots.add(
          Offset(_hash(41, i) * size.width, _hash(42, i) * size.height),
        );
      }
      canvas.drawPoints(
        ui.PointMode.points,
        dots,
        Paint()
          ..strokeWidth = 1
          ..strokeCap = ui.StrokeCap.square
          ..color = pass.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => false;
}

class _GrainPass {
  const _GrainPass(this.seed, this.color);

  final int seed;
  final Color color;
}

/// A stable pseudo-random number in 0..1, so the same grain is in the same
/// place every time the window is painted.
double _hash(int salt, int i) {
  final x = math.sin(salt * 12.9898 + i * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.seed,
    required this.density,
    required this.strength,
  });

  final double t;
  final int seed;
  final double density;
  final double strength;

  /// A stable pseudo-random number, so the same particles are in the same
  /// places every time the window is painted.
  double _noise(int salt, int i) {
    final x = math.sin(seed * 12.9898 + i * 78.233 + salt * 37.719) * 43758.5453;
    return x - x.floorToDouble();
  }

  void _bloom(Canvas canvas, Size size, int i, Color color, double alpha) {
    // Each bloom slides into place during the intro and then holds still.
    final startX = -0.15 + 0.3 * _noise(1, i);
    final startY = 0.2 + 0.6 * _noise(2, i);
    final endX = 0.1 + 0.85 * _noise(3, i);
    final endY = -0.05 + 0.55 * _noise(4, i);
    final eased = Curves.easeOutCubic.transform(t);

    final x = size.width * (startX + (endX - startX) * eased);
    final y = size.height * (startY + (endY - startY) * eased);
    final radius = size.shortestSide * (0.42 + 0.22 * _noise(5, i));

    final rect = Rect.fromCircle(center: Offset(x, y), radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha * strength),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 1],
      ).createShader(rect);
    canvas.drawCircle(Offset(x, y), radius, paint);
  }

  /// A long, thin, tilted band of colour.
  ///
  /// Round blooms alone give a sky that is all soft circles, which blurs into
  /// an even wash with no sense of direction. Real aurora is made of ribbons
  /// hanging across the sky, and a blur follows those ribbons instead of
  /// averaging everything into one colour.
  void _curtain(Canvas canvas, Size size, int i, Color color, double alpha) {
    final x = size.width * (0.05 + 0.9 * _noise(21, i));
    final y = size.height * (0.02 + 0.6 * _noise(22, i));
    final w = size.width * (0.45 + 0.5 * _noise(23, i));
    final h = size.height * (0.10 + 0.14 * _noise(24, i));
    final angle = -0.95 + 1.9 * _noise(25, i) + (1 - t) * 0.3;
    final drift = t * (0.05 + 0.06 * _noise(26, i));

    final rect = Rect.fromCenter(
      center: Offset(x + size.width * drift, y),
      width: w,
      height: h,
    );
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(angle);
    // RadialGradient stretched across a wide, short rect draws an ellipse,
    // which is the shape of a ribbon of light.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha * strength),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 1],
        ).createShader(Rect.fromCenter(center: Offset.zero, width: w, height: h)),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // The ribbons go down first, so the round blooms read as light gathering
    // on top of them rather than competing with them.
    _curtain(canvas, size, 0, Aurora.teal, 0.17);
    _curtain(canvas, size, 1, Aurora.indigo, 0.20);
    _curtain(canvas, size, 2, Aurora.violet, 0.15);
    _curtain(canvas, size, 3, Aurora.sky, 0.13);

    _bloom(canvas, size, 0, Aurora.indigo, 0.30);
    _bloom(canvas, size, 1, Aurora.teal, 0.26);
    _bloom(canvas, size, 2, Aurora.violet, 0.22);
    _bloom(canvas, size, 3, Aurora.amber, 0.12);
    _bloom(canvas, size, 4, Aurora.sky, 0.18);

    final count = (26 * density).round();
    for (var i = 0; i < count; i++) {
      final baseX = _noise(6, i);
      final baseY = _noise(7, i);
      final sizeFactor = 0.8 + 2.4 * _noise(8, i);
      final travel = 0.06 + 0.16 * _noise(9, i);
      final twinkleSpeed = 1.5 + 2.5 * _noise(10, i);
      final glow = _noise(11, i) > 0.82;

      // Rising slowly to the right as the intro plays.
      final dx = size.width * (baseX + travel * t);
      final dy = size.height * (baseY - travel * 0.6 * t);
      final opacity = (0.16 + 0.4 * _noise(12, i)) *
          (0.55 + 0.45 * math.sin(t * math.pi * twinkleSpeed + i));
      final color = Aurora.accent(i);
      final r = sizeFactor * (glow ? 1.9 : 1);

      if (glow) {
        final rect = Rect.fromCircle(center: Offset(dx, dy), radius: r * 7);
        canvas.drawCircle(
          Offset(dx, dy),
          r * 7,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity * 0.5),
                color.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.seed != seed || old.density != density;
}

/// Lifts and warms a card while the pointer is over it, the way a button
/// answers back.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.lift = 4,
    this.scale = 1.012,
    this.shadow,
  });

  final Widget child;
  final double lift;
  final double scale;
  final List<BoxShadow>? shadow;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered || _pressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, hovered ? -widget.lift : 0.0, 0.0, 1.0)
            ..scaleByDouble(
              hovered && !_pressed ? widget.scale : 1.0,
              hovered && !_pressed ? widget.scale : 1.0,
              1.0,
              1.0,
            ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: hovered && widget.shadow != null
                ? widget.shadow
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A soft radial bloom, used behind headers and empty states.
class SoftGlow extends StatelessWidget {
  const SoftGlow({
    super.key,
    required this.child,
    required this.color,
    this.radius = 180,
    this.opacity = 0.3,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          top: -radius * 0.4,
          right: -radius * 0.3,
          child: IgnorePointer(
            child: Container(
              width: radius,
              height: radius,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    color.withValues(alpha: opacity),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A drifting, shimmering dot field for hero areas. Bounded in time, so the
/// window eventually holds still.
class ParticleDrift extends StatefulWidget {
  const ParticleDrift({
    super.key,
    required this.child,
    this.count = 14,
    this.color = Colors.white,
  });

  final Widget child;
  final int count;
  final Color color;

  @override
  State<ParticleDrift> createState() => _ParticleDriftState();
}

class _ParticleDriftState extends State<ParticleDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(
                  t: Curves.easeOut.transform(_t.value),
                  count: widget.count,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.t, required this.count, required this.color});

  final double t;
  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (var i = 0; i < count; i++) {
      final seedA = math.sin(i * 12.9898) * 43758.5453;
      final a = seedA - seedA.floorToDouble();
      final seedB = math.sin(i * 78.233) * 43758.5453;
      final b = seedB - seedB.floorToDouble();
      final seedC = math.sin(i * 39.425) * 43758.5453;
      final c = seedC - seedC.floorToDouble();

      final dx = size.width * (a * 0.9 + 0.05 * t);
      final dy = size.height * (b * 0.9 - 0.08 * t);
      final r = 0.8 + 2.2 * c;
      final opacity = (0.25 + 0.5 * c) *
          (0.5 + 0.5 * math.sin(t * math.pi * 2 + i));
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

/// Fades and rises its child into place, optionally after a short wait, so a
/// page assembles itself one card at a time instead of snapping in as a block.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _in.value = 1;
    } else if (widget.delay == Duration.zero) {
      _in.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _in.forward();
      });
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _in,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset / 100),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _in, curve: Curves.easeOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}
