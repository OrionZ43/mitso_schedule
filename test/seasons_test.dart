import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/season_controller.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:mitso_schedule/theme/app_color_schemes.dart';
import 'package:mitso_schedule/theme/seasons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

Future<ProviderContainer> _container({
  required DateTime now,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
    ],
  );
}

void main() {
  test('сезон определяется по датам', () {
    expect(seasonOn(DateTime(2026, 10, 31))?.id, 'halloween');
    expect(seasonOn(DateTime(2026, 10, 25))?.id, 'halloween');
    expect(seasonOn(DateTime(2026, 11, 2))?.id, 'halloween');
    expect(seasonOn(DateTime(2026, 11, 3)), isNull);
    expect(seasonOn(DateTime(2026, 9, 1))?.id, 'firstBell');
    expect(seasonOn(DateTime(2026, 3, 8))?.id, 'spring');
  });

  test('новогодний сезон переходит через декабрь и январь', () {
    expect(seasonOn(DateTime(2026, 12, 31))?.id, 'newYear');
    expect(seasonOn(DateTime(2027, 1, 7))?.id, 'newYear');
    expect(seasonOn(DateTime(2027, 1, 11)), isNull);
  });

  test('обычный учебный день — без оформления', () {
    expect(seasonOn(DateTime(2026, 10, 13)), isNull);
  });

  test('ближайший сезон — следующий по календарю', () {
    final (Season season, DateTime starts) = nextSeasonAfter(
      DateTime(2026, 10, 18),
    );
    expect(season.id, 'halloween');
    expect(starts, DateTime(2026, 10, 25));

    // Хэллоуин позади — ближайший Новый год.
    final (Season after, DateTime afterStarts) = nextSeasonAfter(
      DateTime(2026, 11, 10),
    );
    expect(after.id, 'newYear');
    expect(afterStarts, DateTime(2026, 12, 15));

    // В январе всё сезоны этого года уже прошли, кроме весны.
    final (Season spring, DateTime springStarts) = nextSeasonAfter(
      DateTime(2027, 1, 20),
    );
    expect(spring.id, 'spring');
    expect(springStarts, DateTime(2027, 3, 1));
  });

  test('у каждого сезона есть чем украшать', () {
    for (final Season season in kSeasons) {
      expect(season.decorShapes, isNotEmpty, reason: season.id);
      expect(season.name, isNotEmpty);
      expect(season.decorHint, isNotEmpty);
    }
  });

  test('выключённое оформление сезона не даёт', () async {
    final ProviderContainer on = await _container(now: DateTime(2026, 10, 31));
    expect(on.read(activeSeasonProvider)?.id, 'halloween');

    final ProviderContainer off = await _container(
      now: DateTime(2026, 10, 31),
      preferences: {'settings.seasonalTheme': false},
    );
    expect(off.read(activeSeasonProvider), isNull);
    // В настройках сезон всё равно виден — чтобы было понятно, что включать.
    expect(off.read(seasonTodayProvider)?.id, 'halloween');
  });

  test('сезонный сид перебивает палитру и обои', () {
    final ColorScheme seasonal = AppColorSchemes.resolve(
      palette: AppPalette.baseline,
      brightness: Brightness.light,
      dynamicEnabled: true,
      wallpaperSeed: const Color(0xFF1F5FD0),
      seasonSeed: const Color(0xFFE8700A),
    );
    final ColorScheme wallpaper = AppColorSchemes.resolve(
      palette: AppPalette.baseline,
      brightness: Brightness.light,
      dynamicEnabled: true,
      wallpaperSeed: const Color(0xFF1F5FD0),
    );

    expect(seasonal.primary, isNot(wallpaper.primary));
  });
}
