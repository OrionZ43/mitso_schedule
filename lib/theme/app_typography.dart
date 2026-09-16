import 'package:flutter/material.dart';

/// Типографика по токенам типошкалы M3.
///
/// https://m3.material.io/styles/typography/type-scale-tokens
///
/// Шрифт — системный Roboto: на Android он есть всегда, поэтому ничего не
/// скачивается и не кладётся в ассеты.
///
/// Цвет текста в стилях не задаётся — его подставляет тема из `onSurface`.
abstract final class AppTypography {
  static TextTheme textTheme() {
    TextStyle style(
      double size,
      double height,
      double tracking,
      FontWeight weight,
    ) {
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        height: height / size,
        letterSpacing: tracking,
        fontWeight: weight,
      );
    }

    return TextTheme(
      displayLarge: style(57, 64, -0.25, FontWeight.w400),
      displayMedium: style(45, 52, 0, FontWeight.w400),
      displaySmall: style(36, 44, 0, FontWeight.w400),
      headlineLarge: style(32, 40, 0, FontWeight.w400),
      headlineMedium: style(28, 36, 0, FontWeight.w400),
      headlineSmall: style(24, 32, 0, FontWeight.w400),
      titleLarge: style(22, 28, 0, FontWeight.w400),
      titleMedium: style(16, 24, 0.15, FontWeight.w500),
      titleSmall: style(14, 20, 0.1, FontWeight.w500),
      bodyLarge: style(16, 24, 0.5, FontWeight.w400),
      bodyMedium: style(14, 20, 0.25, FontWeight.w400),
      bodySmall: style(12, 16, 0.4, FontWeight.w400),
      labelLarge: style(14, 20, 0.1, FontWeight.w500),
      labelMedium: style(12, 16, 0.5, FontWeight.w500),
      labelSmall: style(11, 16, 0.5, FontWeight.w500),
    );
  }
}

/// Emphasized-начертание токена типошкалы.
///
/// https://m3.material.io/styles/typography/type-scale-tokens — 15 emphasized
/// стилей (май 2025) с теми же размером и строкой. Значения —
/// Compose `tokens/TypeScaleTokens.kt` (`*Emphasized*`), MDC `Typography.md`:
///   * display, headline, titleLarge, body — вес Medium (500);
///   * titleMedium, titleSmall, label — вес Bold (700).
/// Это ровно «на ступень тяжелее» базового веса (400 → 500, 500 → 700).
/// Tracking у emphasized: display/headline/titleLarge — 0, bodyLarge — 0.15,
/// остальные как у базовых.
extension TextStyleEmphasis on TextStyle {
  TextStyle get emphasized {
    final bool regular = (fontWeight ?? FontWeight.w400).value <= 400;
    final double size = fontSize ?? 14;
    final double? tracking = switch ((regular, size)) {
      // bodyLarge: 16sp с обычным весом.
      (true, 16) => 0.15,
      // display*, headline*, titleLarge (22sp и крупнее).
      (true, >= 22) => 0,
      _ => letterSpacing,
    };
    return copyWith(
      fontWeight: regular ? FontWeight.w500 : FontWeight.w700,
      letterSpacing: tracking,
    );
  }
}

/// Короткий доступ к токенам типошкалы из виджетов.
extension TextThemeShortcut on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
