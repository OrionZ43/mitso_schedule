import 'package:flutter/material.dart';

/// Сид-палитры приложения.
///
/// Значения — из макета (`PAL` в `.dc.html`). Сама схема не берётся из макета
/// пословно: по гайдлайну роли выводятся из сида через
/// [ColorScheme.fromSeed] с вариантом [DynamicSchemeVariant.expressive].
/// https://m3.material.io/styles/color/system/overview
enum AppPalette {
  violet('Фиолетовая', Color(0xFF6B3FD4)),
  blue('Синяя', Color(0xFF1F5FD0)),
  green('Зелёная', Color(0xFF1E6B4E)),
  coral('Коралловая', Color(0xFFA93B4F));

  const AppPalette(this.label, this.seed);

  final String label;
  final Color seed;

  static AppPalette byName(String? name) => AppPalette.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AppPalette.violet,
  );
}

abstract final class AppColorSchemes {
  /// Baseline-сид M3, используется когда динамические цвета выключены.
  static const Color baselineSeed = Color(0xFF6750A4);

  static ColorScheme fromSeed(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
  }

  /// Итоговая схема экрана.
  ///
  /// * [dynamicEnabled] == false -> baseline-схема M3 (`#6750A4`);
  /// * [dynamicEnabled] == true  -> схема с устройства ([deviceScheme],
  ///   Android 12+), иначе сид устройства [deviceAccent], иначе [palette].
  static ColorScheme resolve({
    required AppPalette palette,
    required Brightness brightness,
    required bool dynamicEnabled,
    ColorScheme? deviceScheme,
    Color? deviceAccent,
  }) {
    if (!dynamicEnabled) {
      return fromSeed(baselineSeed, brightness);
    }
    if (deviceScheme != null) {
      return deviceScheme;
    }
    if (deviceAccent != null) {
      return fromSeed(deviceAccent, brightness);
    }
    return fromSeed(palette.seed, brightness);
  }
}
