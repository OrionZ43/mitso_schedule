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
    this.lessonReminder = true,
    this.palette = AppPalette.baseline,
    this.subgroup,
  });

  /// `null` — следовать системной теме, иначе явный выбор пользователя.
  final bool? darkOverride;

  /// Динамические цвета Material You.
  final bool dynamicColor;

  /// Напоминание за 15 минут до пары.
  final bool lessonReminder;

  /// Статичная палитра — когда [dynamicColor] выключен или обоев нет.
  final AppPalette palette;

  /// Своя подгруппа: 1 или 2. `null` — показывать занятия всех подгрупп.
  final int? subgroup;

  ThemeMode get themeMode => switch (darkOverride) {
    null => ThemeMode.system,
    true => ThemeMode.dark,
    false => ThemeMode.light,
  };

  /// Подпись под тумблером «Тёмная тема».
  String get themeSubtitle => switch (darkOverride) {
    null => 'Следовать системной',
    true => 'Включена вручную',
    false => 'Выключена вручную',
  };

  Settings copyWith({
    bool? darkOverride,
    bool clearDarkOverride = false,
    bool? dynamicColor,
    bool? lessonReminder,
    AppPalette? palette,
    int? subgroup,
    bool clearSubgroup = false,
  }) {
    return Settings(
      darkOverride: clearDarkOverride
          ? null
          : (darkOverride ?? this.darkOverride),
      dynamicColor: dynamicColor ?? this.dynamicColor,
      lessonReminder: lessonReminder ?? this.lessonReminder,
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
  static const String _reminderKey = 'settings.lessonReminder';
  static const String _paletteKey = 'settings.palette';
  static const String _subgroupKey = 'settings.subgroup';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final prefs = _prefs;
    return Settings(
      darkOverride: prefs.getBool(_darkKey),
      dynamicColor: prefs.getBool(_dynamicKey) ?? true,
      lessonReminder: prefs.getBool(_reminderKey) ?? true,
      palette: AppPalette.byName(prefs.getString(_paletteKey)),
      subgroup: prefs.getInt(_subgroupKey),
    );
  }

  void setDark(bool value) {
    state = state.copyWith(darkOverride: value);
    _prefs.setBool(_darkKey, value);
  }

  /// Вернуться к системной теме.
  void followSystemTheme() {
    state = state.copyWith(clearDarkOverride: true);
    _prefs.remove(_darkKey);
  }

  void setDynamicColor(bool value) {
    state = state.copyWith(dynamicColor: value);
    _prefs.setBool(_dynamicKey, value);
  }

  void setLessonReminder(bool value) {
    state = state.copyWith(lessonReminder: value);
    _prefs.setBool(_reminderKey, value);
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
