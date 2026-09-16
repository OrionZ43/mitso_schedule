import 'package:flutter/material.dart';

/// Сид-палитры приложения.
///
/// Значения — из макета (`PAL` в `.dc.html`). Сама схема не берётся из макета
/// пословно: по гайдлайну роли выводятся из сида через
/// [ColorScheme.fromSeed] с вариантом [DynamicSchemeVariant.expressive].
/// https://m3.material.io/styles/color/system/overview
enum AppPalette {
  // Имя элемента — идентификатор палитры из макета (цвет сида),
  // [label] — название итогового цвета, который увидит пользователь:
  // вариант `expressive` поворачивает оттенок (см. [AppColorSchemes.variant]).
  violet('Бирюзовая', Color(0xFF6B3FD4)),
  blue('Зелёная', Color(0xFF1F5FD0)),
  green('Терракотовая', Color(0xFF1E6B4E)),
  coral('Синяя', Color(0xFFA93B4F));

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

  /// Вариант вывода схемы из сида.
  ///
  /// `expressive` заметно поворачивает оттенок: из сида violet `#6B3FD4`
  /// получается бирюзовый primary `#006B5A`, из coral `#A93B4F` — синий
  /// `#286294`. Так и задумано в M3 Expressive, поэтому палитры названы по
  /// цвету-источнику, а не по итоговому primary.
  static const DynamicSchemeVariant variant = DynamicSchemeVariant.expressive;

  static ColorScheme fromSeed(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );
  }

  static final Map<(AppPalette, Brightness), Color> _primaryCache = {};

  /// Итоговый primary палитры — им красится образец в выборе палитры,
  /// чтобы кружок совпадал с тем, что получится на экране.
  static Color primaryOf(AppPalette palette, Brightness brightness) {
    return _primaryCache.putIfAbsent((
      palette,
      brightness,
    ), () => fromSeed(palette.seed, brightness).primary);
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
