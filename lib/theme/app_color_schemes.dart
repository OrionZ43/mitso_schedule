import 'package:flutter/material.dart';

/// Статичные схемы на выбор, когда динамические цвета выключены.
///
/// https://m3.material.io/styles/color/choosing-a-scheme — static схема
/// строится из «hand-picked source color». [baseline] — эталонная схема M3
/// (`#6750A4`), остальные — сиды из макета, выведенные Material Color
/// Utilities (styles/color/advanced: «define your own scheme variant»).
enum AppPalette {
  baseline('Базовая', Color(0xFF6750A4)),
  // Имя — сид из макета, [label] — итоговый цвет: вариант
  // [AppColorSchemes.paletteVariant] поворачивает оттенок сида.
  violet('Бирюзовая', Color(0xFF6B3FD4)),
  blue('Зелёная', Color(0xFF1F5FD0)),
  green('Терракотовая', Color(0xFF1E6B4E)),
  coral('Синяя', Color(0xFFA93B4F));

  const AppPalette(this.label, this.seed);

  final String label;
  final Color seed;

  static AppPalette byName(String? name) => AppPalette.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AppPalette.baseline,
  );
}

abstract final class AppColorSchemes {
  /// Вариант вывода палитр из макета. Гайдлайны вариант не предписывают;
  /// `expressive` выбран заказчиком и заметно поворачивает оттенок, поэтому
  /// палитры подписаны по итоговому цвету.
  static const DynamicSchemeVariant paletteVariant =
      DynamicSchemeVariant.expressive;

  /// Android 12–13: системных ролей нет, есть только палитры обоев. Android
  /// сам строит схему обоев вариантом tonal spot, поэтому и здесь он.
  static const DynamicSchemeVariant wallpaperVariant =
      DynamicSchemeVariant.tonalSpot;

  /// Схема статичной палитры.
  static ColorScheme ofPalette(AppPalette palette, Brightness brightness) {
    if (palette == AppPalette.baseline) {
      // Эталон M3 (`ColorLightTokens` / `ColorDarkTokens`): во Flutter это
      // встроенная схема `ThemeData`, а не вывод из сида — `fromSeed(#6750A4)`
      // дал бы другие роли.
      return ThemeData(brightness: brightness, useMaterial3: true).colorScheme;
    }
    return ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: brightness,
      dynamicSchemeVariant: paletteVariant,
    );
  }

  static final Map<(AppPalette, Brightness), Color> _primaryCache = {};

  /// Итоговый primary палитры — им красится образец в выборе палитры.
  static Color primaryOf(AppPalette palette, Brightness brightness) {
    return _primaryCache.putIfAbsent((
      palette,
      brightness,
    ), () => ofPalette(palette, brightness).primary);
  }

  /// Итоговая схема.
  ///
  /// * динамические цвета выключены → выбранная статичная [palette];
  /// * включены → роли системы ([systemScheme], Android 14+), иначе схема из
  ///   акцента обоев ([wallpaperSeed], Android 12–13), иначе [palette].
  static ColorScheme resolve({
    required AppPalette palette,
    required Brightness brightness,
    required bool dynamicEnabled,
    ColorScheme? systemScheme,
    Color? wallpaperSeed,
  }) {
    if (dynamicEnabled) {
      if (systemScheme != null) return systemScheme;
      if (wallpaperSeed != null) {
        return ColorScheme.fromSeed(
          seedColor: wallpaperSeed,
          brightness: brightness,
          dynamicSchemeVariant: wallpaperVariant,
        );
      }
    }
    return ofPalette(palette, brightness);
  }
}
