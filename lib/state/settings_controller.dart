import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_color_schemes.dart';

/// Настройки приложения, переживающие перезапуск.
@immutable
class Settings {
  const Settings({
    this.darkOverride,
    this.dynamicColor = true,
    this.palette = AppPalette.baseline,
    this.subgroup,
  });

  /// `null` — следовать системной теме, иначе явный выбор пользователя.
  final bool? darkOverride;

  /// Динамические цвета Material You.
  final bool dynamicColor;

  /// Статичная палитра — когда [dynamicColor] выключен или обоев нет.
  final AppPalette palette;

  /// Своя подгруппа: 1 или 2. `null` — показывать занятия всех подгрупп.
  final int? subgroup;

  ThemeMode get themeMode => switch (darkOverride) {
    null => ThemeMode.system,
    true => ThemeMode.dark,
    false => ThemeMode.light,
  };

  Settings copyWith({
    bool? darkOverride,
    bool clearDarkOverride = false,
    bool? dynamicColor,
    AppPalette? palette,
    int? subgroup,
    bool clearSubgroup = false,
  }) {
    return Settings(
      darkOverride: clearDarkOverride
          ? null
          : (darkOverride ?? this.darkOverride),
      dynamicColor: dynamicColor ?? this.dynamicColor,
      palette: palette ?? this.palette,
      subgroup: clearSubgroup ? null : (subgroup ?? this.subgroup),
    );
  }
}

/// Переопределяется в `main()` после загрузки [SharedPreferences].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider не переопределён'),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  static const String _darkKey = 'settings.dark';
  static const String _dynamicKey = 'settings.dynamicColor';
  static const String _paletteKey = 'settings.palette';
  static const String _subgroupKey = 'settings.subgroup';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final prefs = _prefs;
    return Settings(
      darkOverride: prefs.getBool(_darkKey),
      dynamicColor: prefs.getBool(_dynamicKey) ?? true,
      palette: AppPalette.byName(prefs.getString(_paletteKey)),
      subgroup: prefs.getInt(_subgroupKey),
    );
  }

  void setThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        state = state.copyWith(clearDarkOverride: true);
        _prefs.remove(_darkKey);
      case ThemeMode.light || ThemeMode.dark:
        final bool dark = mode == ThemeMode.dark;
        state = state.copyWith(darkOverride: dark);
        _prefs.setBool(_darkKey, dark);
    }
  }

  void setDynamicColor(bool value) {
    state = state.copyWith(dynamicColor: value);
    _prefs.setBool(_dynamicKey, value);
  }

  void setPalette(AppPalette palette) {
    state = state.copyWith(palette: palette);
    _prefs.setString(_paletteKey, palette.name);
  }

  /// `null` — все подгруппы.
  void setSubgroup(int? value) {
    state = value == null
        ? state.copyWith(clearSubgroup: true)
        : state.copyWith(subgroup: value);
    if (value == null) {
      _prefs.remove(_subgroupKey);
    } else {
      _prefs.setInt(_subgroupKey, value);
    }
  }
}
