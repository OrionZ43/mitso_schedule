import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Типографика по токенам типошкалы M3.
///
/// https://m3.material.io/styles/typography/type-scale-tokens
///
/// Emphasized-начертания (https://m3.material.io/styles/typography/applying-type)
/// реализованы весом w700 поверх обычного Roboto: `google_fonts` не даёт
/// управлять осями Roboto Flex через `variations`, а вес — та часть
/// emphasized-контраста, которая влияет на макет.
abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final Color color = brightness == Brightness.light
        ? const Color(0xFF1C1B20)
        : const Color(0xFFE8E1EC);

    TextStyle style(
      double size,
      double height,
      double tracking,
      FontWeight weight,
    ) {
      final TextStyle base = GoogleFonts.roboto(
        fontSize: size,
        height: height / size,
        letterSpacing: tracking,
        fontWeight: weight,
        color: color,
      );
      // Если google_fonts не смог отдать шрифт (нет сети при первом запуске и
      // нет ассета), он возвращает стиль без семейства. Тогда берём системный
      // Roboto: на Android он есть всегда, и текст не уезжает на шрифт
      // по умолчанию.
      return base.copyWith(
        fontFamily: base.fontFamily ?? 'Roboto',
        fontFamilyFallback: const ['Roboto'],
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
extension TextStyleEmphasis on TextStyle {
  /// Акцентное начертание (w700) — заголовки экранов, названия пар, кнопки.
  TextStyle get emphasized => copyWith(fontWeight: FontWeight.w700);
}

/// Короткий доступ к токенам типошкалы из виджетов.
extension TextThemeShortcut on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
