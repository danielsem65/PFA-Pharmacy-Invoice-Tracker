import 'package:flutter/material.dart';

import 'theme.dart';

/// The colours that make a pane read as glass rather than as a flat wash.
///
/// A glass surface is four separate things stacked on top of each other, and
/// each one is a separate decision: the [tint] that carries colour, the [sheen]
/// that fakes the light falling across the top of the pane, the [edgeLight] and
/// [edgeDim] that make the rim catch light on one side and fall away on the
/// other, and the [shadow] that lifts the pane off whatever is behind it. Miss
/// the rim and the result looks like a rectangle of fog; miss the sheen and it
/// looks like a rectangle of paint.
@immutable
class GlassTokens {
  const GlassTokens({
    required this.tintThin,
    required this.tintRegular,
    required this.tintThick,
    required this.tintUltra,
    required this.sheen,
    required this.edgeLight,
    required this.edgeDim,
    required this.rim,
    required this.shadow,
    required this.highlight,
  });

  /// Painted over the blurred backdrop. Kept low on purpose: the blur already
  /// does the work of hiding what is behind, so the tint only has to set the
  /// mood and guarantee the contrast of whatever sits on top of it.
  final Color tintThin;
  final Color tintRegular;
  final Color tintThick;
  final Color tintUltra;

  /// The light falling across the top-left of the pane, fading out downward.
  final LinearGradient sheen;

  /// The bright half of the rim gradient, where the light source is.
  final Color edgeLight;

  /// The dim half of the rim gradient, opposite the light.
  final Color edgeDim;

  /// A flat hairline under the rim, so the edge still reads when the gradient
  /// is too subtle to see on its own.
  final Color rim;

  /// A soft, wide, low-opacity drop shadow. Real glass casts a wide faint
  /// shadow with a bright caustic line at the top; that is what the two
  /// entries here describe.
  final List<BoxShadow> shadow;

  /// The bright caustic line just inside the top edge of the pane.
  final Color highlight;

  /// The flat fill for something that sits *inside* an already-blurred pane.
  /// Blurring a second time there would cost real frames and change nothing a
  /// viewer could see, so nested surfaces stay flat.
  Color tintFor(GlassLevel level) => switch (level) {
        GlassLevel.thin => tintThin,
        GlassLevel.regular => tintRegular,
        GlassLevel.thick => tintThick,
        GlassLevel.ultra => tintUltra,
      };

  GlassTokens copyWith({
    Color? tintThin,
    Color? tintRegular,
    Color? tintThick,
    Color? tintUltra,
    LinearGradient? sheen,
    Color? edgeLight,
    Color? edgeDim,
    Color? rim,
    List<BoxShadow>? shadow,
    Color? highlight,
  }) {
    return GlassTokens(
      tintThin: tintThin ?? this.tintThin,
      tintRegular: tintRegular ?? this.tintRegular,
      tintThick: tintThick ?? this.tintThick,
      tintUltra: tintUltra ?? this.tintUltra,
      sheen: sheen ?? this.sheen,
      edgeLight: edgeLight ?? this.edgeLight,
      edgeDim: edgeDim ?? this.edgeDim,
      rim: rim ?? this.rim,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
    );
  }

  GlassTokens lerp(covariant GlassTokens? other, double t) {
    if (other == null) return this;
    return GlassTokens(
      tintThin: Color.lerp(tintThin, other.tintThin, t)!,
      tintRegular: Color.lerp(tintRegular, other.tintRegular, t)!,
      tintThick: Color.lerp(tintThick, other.tintThick, t)!,
      tintUltra: Color.lerp(tintUltra, other.tintUltra, t)!,
      sheen: LinearGradient.lerp(sheen, other.sheen, t)!,
      edgeLight: Color.lerp(edgeLight, other.edgeLight, t)!,
      edgeDim: Color.lerp(edgeDim, other.edgeDim, t)!,
      rim: Color.lerp(rim, other.rim, t)!,
      shadow: t < 0.5 ? shadow : other.shadow,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}

/// How much frost a pane carries, and therefore how much it costs to draw.
///
/// One blur per visual plane is the rule these levels exist to enforce: the
/// page backdrop, the chrome, and each card get one. Anything nested inside a
/// blurred pane stays flat.
enum GlassLevel {
  /// A chip or a strip sitting directly on the page.
  thin,

  /// The default for cards and panels.
  regular,

  /// Chrome that overlaps something: the sidebar, toolbars, sticky headers.
  thick,

  /// Menus and dialogs, which have to stay readable over anything.
  ultra,
}

extension GlassLevelTuning on GlassLevel {
  /// The blur radius in logical pixels. A real pane needs a lot of blur to stop
  /// reading as a transparent rectangle; 20+ is the point where the backdrop
  /// stops being recognisable and becomes a wash of colour.
  double get sigma => switch (this) {
        GlassLevel.thin => 12,
        GlassLevel.regular => 24,
        GlassLevel.thick => 36,
        GlassLevel.ultra => 52,
      };

  /// The lift off the page, so a card casts a deeper shadow than a chip.
  int get lift => switch (this) {
        GlassLevel.thin => 8,
        GlassLevel.regular => 16,
        GlassLevel.thick => 24,
        GlassLevel.ultra => 40,
      };
}

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
    required this.glass,
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
    glass: GlassTokens(
      // Over a pale sky the pane has to be nearly opaque to hold dark text at
      // a readable contrast, so the tint does the work the blur cannot.
      tintThin: Color(0x8CFFFFFF),
      tintRegular: Color(0xB4FFFFFF),
      tintThick: Color(0xD2FFFFFF),
      tintUltra: Color(0xF7FFFFFF),
      sheen: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xB3FFFFFF), Color(0x00FFFFFF)],
      ),
      edgeLight: Color(0xE6FFFFFF),
      edgeDim: Color(0x1F0B1020),
      rim: Color(0x1A0B1020),
      highlight: Color(0xB3FFFFFF),
      shadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x14101833),
          blurRadius: 26,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x0A0B1020),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    ),
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
    glass: GlassTokens(
      // Over the night sky a thin tint is enough: the backdrop is already dark,
      // so the pane mostly needs a whisper of white to lift it off the sky.
      tintThin: Color(0x0F17255A),
      tintRegular: Color(0x1A17255A),
      tintThick: Color(0x2617255A),
      tintUltra: Color(0x3D0E1428),
      sheen: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0x1FFFFFFF), Color(0x00FFFFFF)],
      ),
      edgeLight: Color(0x59FFFFFF),
      edgeDim: Color(0x0DFFFFFF),
      rim: Color(0x1AFFFFFF),
      highlight: Color(0x3DFFFFFF),
      shadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 34,
          offset: Offset(0, 18),
        ),
        BoxShadow(
          color: Color(0x3D000000),
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ],
    ),
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

  /// Everything needed to draw a real glass pane in this brightness.
  final GlassTokens glass;

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
    GlassTokens? glass,
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
      glass: glass ?? this.glass,
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
      glass: glass.lerp(other.glass, t),
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
    final glass = tokens.glass;
    return BoxDecoration(
      color: fill ?? glass.tintRegular,
      gradient: glass.sheen,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: glass.rim),
      boxShadow: shadow ?? glass.shadow,
    );
  }

  /// A lighter well for the inside of a panel: table bodies, drop zones, the
  /// body of a settings card. Flat on purpose — the panel it sits in is already
  /// blurred, so a second blur here would cost frames and show nothing.
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
