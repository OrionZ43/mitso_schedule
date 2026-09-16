import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Динамическая схема Android 14+ — роли прямо из системы.
///
/// MDC-Android на API 34+ берёт роли не из тональных палитр, а из системных
/// ресурсов `android:color/system_*` (`color/res/values-v34/tokens.xml`), где
/// уже учтены обои и уровень контраста («You will get contrast control for
/// free if you already use dynamic colors», `docs/theming/Color.md`).
/// Нативная часть — `MainActivity.systemColorRoles`.
abstract final class SystemColorRoles {
  static const MethodChannel _channel = MethodChannel('mitso/system_colors');

  /// Светлая и тёмная схемы или `null`, если система их не отдаёт
  /// (Android 13 и ниже, не Android, ошибка канала).
  static Future<({ColorScheme light, ColorScheme dark})?> load() async {
    try {
      final Map<Object?, Object?>? raw = await _channel
          .invokeMapMethod<Object?, Object?>('roles');
      if (raw == null) return null;
      return (
        light: _scheme(
          raw['light']! as Map<Object?, Object?>,
          Brightness.light,
        ),
        dark: _scheme(raw['dark']! as Map<Object?, Object?>, Brightness.dark),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static ColorScheme _scheme(Map<Object?, Object?> r, Brightness brightness) {
    Color c(String role) => Color(r[role]! as int);
    return ColorScheme(
      brightness: brightness,
      primary: c('primary'),
      onPrimary: c('onPrimary'),
      primaryContainer: c('primaryContainer'),
      onPrimaryContainer: c('onPrimaryContainer'),
      primaryFixed: c('primaryFixed'),
      primaryFixedDim: c('primaryFixedDim'),
      onPrimaryFixed: c('onPrimaryFixed'),
      onPrimaryFixedVariant: c('onPrimaryFixedVariant'),
      secondary: c('secondary'),
      onSecondary: c('onSecondary'),
      secondaryContainer: c('secondaryContainer'),
      onSecondaryContainer: c('onSecondaryContainer'),
      secondaryFixed: c('secondaryFixed'),
      secondaryFixedDim: c('secondaryFixedDim'),
      onSecondaryFixed: c('onSecondaryFixed'),
      onSecondaryFixedVariant: c('onSecondaryFixedVariant'),
      tertiary: c('tertiary'),
      onTertiary: c('onTertiary'),
      tertiaryContainer: c('tertiaryContainer'),
      onTertiaryContainer: c('onTertiaryContainer'),
      tertiaryFixed: c('tertiaryFixed'),
      tertiaryFixedDim: c('tertiaryFixedDim'),
      onTertiaryFixed: c('onTertiaryFixed'),
      onTertiaryFixedVariant: c('onTertiaryFixedVariant'),
      error: c('error'),
      onError: c('onError'),
      errorContainer: c('errorContainer'),
      onErrorContainer: c('onErrorContainer'),
      surface: c('surface'),
      onSurface: c('onSurface'),
      surfaceDim: c('surfaceDim'),
      surfaceBright: c('surfaceBright'),
      surfaceContainerLowest: c('surfaceContainerLowest'),
      surfaceContainerLow: c('surfaceContainerLow'),
      surfaceContainer: c('surfaceContainer'),
      surfaceContainerHigh: c('surfaceContainerHigh'),
      surfaceContainerHighest: c('surfaceContainerHighest'),
      onSurfaceVariant: c('onSurfaceVariant'),
      outline: c('outline'),
      outlineVariant: c('outlineVariant'),
      // Роль scrim в системе не публикуется; во всех схемах M3 это чёрный.
      scrim: const Color(0xFF000000),
      shadow: const Color(0xFF000000),
      inverseSurface: c('inverseSurface'),
      onInverseSurface: c('onInverseSurface'),
      inversePrimary: c('inversePrimary'),
      surfaceTint: c('primary'),
    );
  }
}
