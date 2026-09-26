import 'package:flutter/material.dart';

import 'design.dart';

/// The brand colours the app decorates itself with.
///
/// Roles that carry meaning (primary, error, surfaces) come from a single
/// generated palette so contrast is always right. These are the purely
/// decorative accents: gradients, glowing icons, the drifting backdrop.
class Aurora {
  const Aurora._();

  static const teal = Color(0xFF14B8A6);
  static const emerald = Color(0xFF34D399);
  static const sky = Color(0xFF38BDF8);
  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFFA855F7);
  static const rose = Color(0xFFFB7185);
  static const amber = Color(0xFFF59E0B);
  static const pink = Color(0xFFF472B6);

  /// The night sky behind the sidebar and the page.
  static const nightA = Color(0xFF141A3A);
  static const nightB = Color(0xFF241B4B);
  static const nightC = Color(0xFF0B1226);

  /// Cycle of accents so a row of cards never repeats itself.
  static const accents = <Color>[
    teal,
    indigo,
    amber,
    rose,
    sky,
    emerald,
    violet,
    pink,
  ];

  static Color accent(int index) => accents[index % accents.length];

  static List<Color> pair(int index) {
    final a = accent(index);
    final b = accent(index + 3);
    return <Color>[a, b];
  }

  static LinearGradient gradient(int index, {double opacity = 1}) {
    final colors = pair(index).map((c) => c.withValues(alpha: opacity)).toList();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  /// The soft, wide shadows that give the cards depth without the heavy
  /// drop shadow Material draws by default.
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.16,
    double blur = 28,
    double y = 12,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }
}

const Color _seed = Color(0xFF0D9488);
const Color _ink = Color(0xFF0B1020);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  );
  return _compose(scheme, Brightness.light);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  );
  return _compose(scheme, Brightness.dark);
}

ThemeData _compose(ColorScheme scheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // The page itself is see-through so the drifting backdrop can show through
  // the gaps between cards, like frosted glass over the sky.
  final pageColor = isDark
      ? scheme.surface.withValues(alpha: 0.55)
      : scheme.surface.withValues(alpha: 0.72);
  final cardColor = isDark
      ? scheme.surfaceContainerLow.withValues(alpha: 0.86)
      : Colors.white.withValues(alpha: 0.82);
  final fieldColor = isDark
      ? Colors.white.withValues(alpha: 0.06)
      : scheme.primary.withValues(alpha: 0.05);

  final baseTextTheme = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
  ).textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  final headline = baseTextTheme.headlineSmall?.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  final title = baseTextTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    // The measurements and semantic colours every widget reads instead of
    // inventing its own.
    extensions: <ThemeExtension<dynamic>>[AppTokens.forBrightness(brightness)],
    scaffoldBackgroundColor: pageColor,
    fontFamily: 'Segoe UI',
    textTheme: baseTextTheme.copyWith(
      headlineSmall: headline,
      titleMedium: title,
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      labelSmall: baseTextTheme.labelSmall?.copyWith(letterSpacing: 0.2),
    ),
    splashFactory: InkSparkle.splashFactory,
    // A calm fade-and-rise between pages instead of a horizontal slide: it
    // keeps the eye on the content rather than the transition.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    // Pointer feedback for the whole app, so a click always answers somewhere
    // even where a widget paints its own background.
    hoverColor: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
    focusColor: scheme.primary.withValues(alpha: 0.12),
    highlightColor: scheme.primary.withValues(alpha: 0.06),
    splashColor: scheme.primary.withValues(alpha: 0.10),

    textSelectionTheme: TextSelectionThemeData(
  
      selectionColor: scheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: scheme.primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        );
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: SoftCardBorder(
        radius: 20,
        fill: cardColor,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.primary.withValues(alpha: 0.10),
        ),
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : _ink.withValues(alpha: 0.30),
        shadowBlur: 22,
        shadowSpread: -6,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        // A primary action deepens under the pointer rather than fading out, so
        // it still reads as a button.
        overlayColor: scheme.onPrimary.withValues(alpha: 0.12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        backgroundColor: scheme.primary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.28), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        overlayColor: scheme.primary.withValues(alpha: 0.08),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        overlayColor: scheme.primary.withValues(alpha: 0.08),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: scheme.primary.withValues(alpha: 0.08),
        highlightColor: scheme.primary.withValues(alpha: 0.04),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.7), width: 1.6),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: 0.75);
        }
        return scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStatePropertyAll(
        scheme.outlineVariant.withValues(alpha: 0.7),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.outline;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 5,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : scheme.primary.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : scheme.primary.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      labelStyle: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      barrierColor: _ink.withValues(alpha: isDark ? 0.6 : 0.32),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? scheme.inverseSurface : _ink,
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.95),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: baseTextTheme.bodyLarge,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : scheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconColor: scheme.onSurfaceVariant,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 46,
      dividerThickness: 0.6,
      headingRowColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.04),
      ),
      headingTextStyle: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: scheme.onSurfaceVariant,
      ),
      dataTextStyle: baseTextTheme.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      surfaceTintColor: Colors.transparent,
      color: isDark ? scheme.surfaceContainerHigh : Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thickness: WidgetStatePropertyAll(8),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: isDark ? 0.35 : 0.28),
      ),
      trackColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? scheme.inverseSurface : _ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: baseTextTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.92),
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      circularTrackColor: scheme.primary.withValues(alpha: 0.12),
    ),
  );
}

/// A rounded rectangle that paints a wide, soft shadow around itself, so cards
/// float a little above the page instead of sitting on a hard grey outline.
class SoftCardBorder extends OutlinedBorder {
  const SoftCardBorder({
    this.radius = 20,
    this.fill = const Color(0xFFFFFFFF),
    BorderSide side = BorderSide.none,
    this.shadowColor = const Color(0xFF0B1020),
    this.shadowBlur = 22,
    this.shadowSpread = -6,
    this.shadowOffset = 10,
  }) : super(side: side);

  final double radius;
  final Color fill;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowSpread;
  final double shadowOffset;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        bottom: shadowBlur > 0 ? shadowOffset + shadowBlur / 3 : 0,
      );

  @override
  SoftCardBorder copyWith({BorderSide? side}) => SoftCardBorder(
        radius: radius,
        fill: fill,
        side: side ?? this.side,
        shadowColor: shadowColor,
        shadowBlur: shadowBlur,
        shadowSpread: shadowSpread,
        shadowOffset: shadowOffset,
      );

  @override
  ShapeBorder scale(double t) => SoftCardBorder(
        radius: radius * t,
        fill: fill,
        side: side.scale(t),
        shadowColor: shadowColor,
        shadowBlur: shadowBlur * t,
        shadowSpread: shadowSpread * t,
        shadowOffset: shadowOffset * t,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(side.width / 2),
          Radius.circular(radius),
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(side.width / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    if (shadowBlur > 0) {
      canvas.drawShadow(
        path.shift(Offset(0, shadowOffset)),
        shadowColor,
        shadowBlur,
        false,
      );
    }
    canvas.drawRRect(rrect, Paint()..color = fill);
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRRect(rrect, side.toPaint());
    }
  }
}
