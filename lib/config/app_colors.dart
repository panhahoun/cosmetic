import 'package:flutter/material.dart';

/// M-Commerce / Cosmetic app palette.
///
/// Mostly ivory/white; rose is reserved for buttons, selected states, prices
/// and important actions.
class AppColors {
  const AppColors._();


  /// Rose / dusty pink. Buttons, selected states, prices, favorite icons.
  static const Color primary = Color(0xFFC98F9B);

  /// Soft blush. Secondary buttons, unselected chips, category pills.
  static const Color secondary = Color(0xFFF4E4E7);

  /// Warm ivory. Scaffold background.
  static const Color background = Color(0xFFFCF9F7);

  /// White. Cards, app bars, sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// Deep brown. Main text.
  static const Color textPrimary = Color(0xFF2D2526);

  /// Warm gray. Secondary text.
  static const Color textMuted = Color(0xFF7D7374);

  /// Champagne gold. Small accents, ratings.
  static const Color accent = Color(0xFFC6A15B);

  /// Soft beige. Dividers, card and input outlines.
  static const Color border = Color(0xFFE8DDDA);

  /// Sage green. Confirmations.
  static const Color success = Color(0xFF6F8A72);

  /// Soft red. Errors and discount badges.
  static const Color error = Color(0xFFC65D63);


  /// Bottom navigation selected.
  static const Color navSelected = primary;

  /// Bottom navigation unselected.
  static const Color navUnselected = Color(0xFFA69B9C);

  /// Text/icons placed on top of [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Text/icons placed on top of [secondary].
  static const Color onSecondary = textPrimary;

  /// Pressed / pressed-hover tone for [primary].
  static const Color primaryPressed = Color(0xFFB07683);

  /// Home / auth page gradient, light.
  static const Color scaffoldGradientTop = Color(0xFFFDFBFA);

  /// Home / auth page gradient, light (bottom).
  static const Color scaffoldGradientBottom = Color(0xFFF7EFEC);

  /// Product card / splash gradient, light.
  static const Color cardGradientTop = Color(0xFFFFFDFC);

  /// Product card / splash gradient, light (bottom).
  static const Color cardGradientBottom = Color(0xFFF9F1F0);


  /// Darker rose that keeps AA contrast against dark surfaces.
  static const Color primaryDark = Color(0xFFD8A6B0);

  static const Color darkBackground = Color(0xFF17141A);

  static const Color darkSurface = Color(0xFF211D24);

  static const Color darkSurfaceAlt = Color(0xFF2A252E);

  static const Color darkTextPrimary = Color(0xFFF5F1F0);

  static const Color darkTextMuted = Color(0xFFA9A0A6);

  static const Color darkBorder = Color(0xFF3A343E);

  static const Color darkGradientTop = Color(0xFF1B1720);

  static const Color darkGradientBottom = Color(0xFF241F29);


  /// Transparent rose for glows, shadows and selection indicators.
  static Color primaryAlpha(double opacity) =>
      primary.withValues(alpha: opacity);

  /// Page gradient used by full-screen scroll views.
  static List<Color> scaffoldGradient(Brightness brightness) =>
      brightness == Brightness.dark
          ? const [darkGradientTop, darkGradientBottom]
          : const [scaffoldGradientTop, scaffoldGradientBottom];

  /// Gradient used by product cards and the splash logo.
  static List<Color> cardGradient(Brightness brightness) =>
      brightness == Brightness.dark
          ? const [darkSurfaceAlt, darkSurface]
          : const [cardGradientTop, cardGradientBottom];
}
