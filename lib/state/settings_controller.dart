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
    this.balanceAlerts = true,
    this.lessonReminders = false,
    this.reminderLead = const Duration(minutes: 15),
  });

  /// `null` — следовать системной теме, иначе явный выбор пользователя.
  final bool? darkOverride;

  /// Динамические цвета Material You.
  final bool dynamicColor;

  /// Статичная палитра — когда [dynamicColor] выключен или обоев нет.
  final AppPalette palette;

  /// Сообщать о долге по лицевому счёту.
  final bool balanceAlerts;

  /// Напоминать о начале пары.
  final bool lessonReminders;

  /// За сколько до начала пары напоминать.
  final Duration reminderLead;

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
    bool? balanceAlerts,
    bool? lessonReminders,
    Duration? reminderLead,
  }) {
    return Settings(
      darkOverride: clearDarkOverride
          ? null
          : (darkOverride ?? this.darkOverride),
      dynamicColor: dynamicColor ?? this.dynamicColor,
      palette: palette ?? this.palette,
      balanceAlerts: balanceAlerts ?? this.balanceAlerts,
      lessonReminders: lessonReminders ?? this.lessonReminders,
      reminderLead: reminderLead ?? this.reminderLead,
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

  /// Тот же ключ читает фоновая проверка баланса.
  static const String balanceAlertsKey = 'settings.balanceAlerts';

  static const String _remindersKey = 'settings.lessonReminders';
  static const String _leadKey = 'settings.reminderLeadMinutes';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final prefs = _prefs;
    return Settings(
      darkOverride: prefs.getBool(_darkKey),
      dynamicColor: prefs.getBool(_dynamicKey) ?? true,
      palette: AppPalette.byName(prefs.getString(_paletteKey)),
      balanceAlerts: prefs.getBool(balanceAlertsKey) ?? true,
      lessonReminders: prefs.getBool(_remindersKey) ?? false,
      reminderLead: Duration(minutes: prefs.getInt(_leadKey) ?? 15),
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

  void setBalanceAlerts(bool value) {
    state = state.copyWith(balanceAlerts: value);
    _prefs.setBool(balanceAlertsKey, value);
  }

  void setLessonReminders(bool value) {
    state = state.copyWith(lessonReminders: value);
    _prefs.setBool(_remindersKey, value);
  }

  /// Насколько заранее напоминать. Меньше минуты и больше трёх часов не
  /// имеет смысла: пара к тому времени или начнётся, или ещё не скоро.
  void setReminderLead(Duration lead) {
    final int minutes = lead.inMinutes.clamp(1, 180);
    state = state.copyWith(reminderLead: Duration(minutes: minutes));
    _prefs.setInt(_leadKey, minutes);
  }
}
