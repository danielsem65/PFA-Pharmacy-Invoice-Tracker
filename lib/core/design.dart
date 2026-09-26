import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The measurements and semantic colours the whole app draws from.
///
/// These used to be scattered through the screens as one-off numbers, which is
/// how a page and the list it belongs to slowly drift apart. They live here
/// instead, hung off the [ThemeExtension] mechanism so light and dark carry
/// their own values and every widget can read them without a lookup table of
/// its own.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.info,
    required this.hairline,
    required this.surface,
    required this.surfaceRaised,
    required this.sunken,
  });

  factory AppTokens.of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? lightTokens;

  factory AppTokens.forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? darkTokens : lightTokens;

  /// Money and other figures line up in a column only when every digit is the
  /// same width. Segoe UI can do that; this asks for it.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const AppTokens lightTokens = AppTokens(
    success: Color(0xFF0E9F6E),
    onSuccess: Color(0xFF046C4E),
    warning: Color(0xFFEA9A0B),
    onWarning: Color(0xFF92400E),
    danger: Color(0xFFE11D48),
    onDanger: Color(0xFF9F1239),
    info: Color(0xFF0284C7),
    hairline: Color(0x14101330),
    surface: Color(0xB8FFFFFF),
    surfaceRaised: Color(0xF2FFFFFF),
    sunken: Color(0x0F0D9488),
  );

  static const AppTokens darkTokens = AppTokens(
    success: Color(0xFF34D399),
    onSuccess: Color(0xFF6EE7B7),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFFFCD34D),
    danger: Color(0xFFFB7185),
    onDanger: Color(0xFFFDA4AF),
    info: Color(0xFF38BDF8),
    hairline: Color(0x1FFFFFFF),
    surface: Color(0x0DFFFFFF),
    surfaceRaised: Color(0x14FFFFFF),
    sunken: Color(0x0AFFFFFF),
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color info;

  /// The quiet one-pixel line that separates rows and outlines panels.
  final Color hairline;

  /// Translucent panel fills, matched to the brightness.
  final Color surface;
  final Color surfaceRaised;

  /// The faint tint behind a well — a table body, a code block, a hole.
  final Color sunken;

  /// The one corner radius everything rounds to, plus the tighter one for
  /// controls inside a panel.
  double get radius => 18;
  double get radiusSm => 12;
  double get radiusLg => 24;
  double get radiusPill => 999;

  @override
  AppTokens copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? info,
    Color? hairline,
    Color? surface,
    Color? surfaceRaised,
    Color? sunken,
  }) {
    return AppTokens(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      info: info ?? this.info,
      hairline: hairline ?? this.hairline,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      sunken: sunken ?? this.sunken,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      info: Color.lerp(info, other.info, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
    );
  }
}

/// The spacing scale. One number per step, used everywhere, so a page and the
/// panel inside it share a rhythm instead of each inventing padding.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  static const EdgeInsets page = EdgeInsets.fromLTRB(xxl, 18, xxl, 0);
  static const EdgeInsets panel = EdgeInsets.fromLTRB(lg, 13, lg, 16);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// The size ramp for the glowing icon tiles that open a page or name a panel.
enum TileSize { small, medium, large }

extension TileSizeGeometry on TileSize {
  double get box => switch (this) {
        TileSize.small => 30,
        TileSize.medium => 40,
        TileSize.large => 48,
      };

  double get icon => switch (this) {
        TileSize.small => 16,
        TileSize.medium => 20,
        TileSize.large => 24,
      };

  double get radius => switch (this) {
        TileSize.small => 10,
        TileSize.medium => 13,
        TileSize.large => 16,
      };
}

/// The frosted fill every panel, tile and well shares.
///
/// One place to change the translucency, and one place that knows whether the
/// app is currently drawing on a light or a dark sky.
abstract final class Frost {
  static BoxDecoration panel(
    BuildContext context, {
    double radius = 18,
    Color? tint,
    Color? fill,
    List<BoxShadow>? shadow,
    Border? border,
  }) {
    final tokens = AppTokens.of(context);
    final lead = tint ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: fill ?? tokens.surface,
      borderRadius: BorderRadius.circular(radius),
      border: border ??
          Border.all(color: tint != null ? tint.withValues(alpha: 0.24) : tokens.hairline),
      boxShadow: shadow ??
          <BoxShadow>[
            BoxShadow(
              color: lead.withValues(alpha: dark ? 0.16 : 0.08),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
    );
  }

  /// A lighter well for the inside of a panel: table bodies, drop zones, the
  /// body of a settings card.
  static BoxDecoration well(BuildContext context, {double radius = 14}) {
    final tokens = AppTokens.of(context);
    return BoxDecoration(
      color: tokens.sunken,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: tokens.hairline),
    );
  }

  /// The gradient that names a thing: page headers, tiles, primary buttons.
  static LinearGradient duo(int accentIndex, {double opacity = 1}) =>
      Aurora.gradient(accentIndex, opacity: opacity);
}
