/// ═══════════════════════════════════════════════════════
/// VOID THEME — strict black & white design language.
///
/// There are intentionally only two "real" colors in this app.
/// Everything else is produced with opacity, blur and shadows,
/// which keeps the UI premium, calm and almost "void-like".
/// ═══════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VoidColors {
  VoidColors._();

  /// Pure white — the void's canvas.
  static const Color background = Color(0xFFFFFFFF);

  /// Deep black — every primary element.
  static const Color foreground = Color(0xFF000000);

  // ── Derived neutrals (pure greys, no hue) ───────────────────────────
  static const Color muted = Color(0xFF8A8A8A); // secondary text
  static const Color faintLine = Color(0x14000000); // hairline dividers
  static const Color scrim = Color(0x66FFFFFF); // frosted overlays

  /// Soft black shadow used on white surfaces ("glow" inverted).
  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// White halo used around black objects (atmospheric rim light feel).
  static const List<BoxShadow> haloGlow = <BoxShadow>[
    BoxShadow(color: Color(0x33000000), blurRadius: 48, spreadRadius: 2),
  ];
}

class VoidTheme {
  VoidTheme._();

  /// The single source of truth for typography. Inter gives the minimal,
  /// futuristic feel; we fall back gracefully if the font can't be fetched.
  static TextTheme textTheme(BuildContext context) {
    final TextTheme base = Theme.of(context).textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 96,
        fontWeight: FontWeight.w200,
        letterSpacing: -2,
        color: VoidColors.foreground,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
        color: VoidColors.foreground,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: VoidColors.foreground,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: VoidColors.muted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        color: VoidColors.muted,
      ),
    );
  }

  /// App-wide ThemeData. Light-only by design: the aesthetic IS the product.
  static ThemeData build() {
    final ThemeData light = ThemeData.from(
      colorScheme: const ColorScheme.light(
        surface: VoidColors.background,
        onSurface: VoidColors.foreground,
        primary: VoidColors.foreground,
        onPrimary: VoidColors.background,
        error: VoidColors.foreground,
      ),
    );
    return light.copyWith(
      scaffoldBackgroundColor: VoidColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: VoidColors.faintLine,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: VoidColors.foreground,
        selectionColor: Color(0x33000000),
        selectionHandleColor: VoidColors.foreground,
      ),
    );
  }
}

/// Spacing scale — a tiny rhythm system so layouts stay consistent.
class VoidSpacing {
  VoidSpacing._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 40;
}
