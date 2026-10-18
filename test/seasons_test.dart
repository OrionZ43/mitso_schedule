import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/state/app_icon_controller.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/season_controller.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:mitso_schedule/theme/app_color_schemes.dart';
import 'package:mitso_schedule/theme/seasons.dart';
import 'package:mitso_schedule/widgets/empty_state.dart';
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
    expect(seasonOn(DateTime(2026, 10, 18))?.id, 'halloween');
    expect(seasonOn(DateTime(2026, 11, 2))?.id, 'halloween');
    expect(seasonOn(DateTime(2026, 10, 17)), isNull);
    expect(seasonOn(DateTime(2026, 11, 3)), isNull);
    expect(seasonOn(DateTime(2026, 9, 1))?.id, 'firstBell');
    expect(seasonOn(DateTime(2026, 9, 14))?.id, 'firstBell');
    expect(seasonOn(DateTime(2026, 9, 15)), isNull);
    expect(seasonOn(DateTime(2026, 3, 8))?.id, 'spring');
    expect(seasonOn(DateTime(2026, 3, 15))?.id, 'spring');
  });

  test('новогодний сезон переходит через декабрь и январь', () {
    expect(seasonOn(DateTime(2026, 12, 5))?.id, 'newYear');
    expect(seasonOn(DateTime(2026, 12, 31))?.id, 'newYear');
    // Старый Новый год ещё в сезоне, 16 января — уже нет.
    expect(seasonOn(DateTime(2027, 1, 14))?.id, 'newYear');
    expect(seasonOn(DateTime(2027, 1, 16)), isNull);
  });

  test('обычный учебный день — без оформления', () {
    expect(seasonOn(DateTime(2026, 10, 13)), isNull);
  });

  test('ближайший сезон — следующий по календарю', () {
    final (Season season, DateTime starts) = nextSeasonAfter(
      DateTime(2026, 10, 1),
    );
    expect(season.id, 'halloween');
    expect(starts, DateTime(2026, 10, 18));

    // Хэллоуин позади — ближайший Новый год.
    final (Season after, DateTime afterStarts) = nextSeasonAfter(
      DateTime(2026, 11, 10),
    );
    expect(after.id, 'newYear');
    expect(afterStarts, DateTime(2026, 12, 5));

    // В январе всё сезоны этого года уже прошли, кроме весны.
    final (Season spring, DateTime springStarts) = nextSeasonAfter(
      DateTime(2027, 1, 20),
    );
    // 20 января сезон уже кончился.
    expect(spring.id, 'spring');
    expect(springStarts, DateTime(2027, 3, 1));
  });

  test('у каждого сезона есть чем украшать', () {
    for (final Season season in kSeasons) {
      expect(season.name, isNotEmpty);
      expect(season.decorHint, isNotEmpty, reason: season.id);
    }
  });

  test('картины сезонов лежат в ассетах', () {
    for (final Season season in kSeasons) {
      final List<String> assets = [
        ...season.backdrops.values,
        if (season.marker != null) season.marker!,
        if (season.emptyArt != null) season.emptyArt!,
      ];
      for (final String asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
  });

  testWidgets('в сезон с картинкой пустое состояние показывает её', (
    tester,
  ) async {
    final Season halloween = kSeasons.firstWhere((s) => s.id == 'halloween');
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: halloween.seed);
    Future<void> pump(Season? season) => tester.pumpWidget(
      MaterialApp(
        // Как в приложении: тема меняется сразу, без анимации.
        themeAnimationDuration: Duration.zero,
        theme: buildTheme(scheme, season: season),
        home: const Scaffold(body: EmptyState(title: 'Занятий нет')),
      ),
    );

    await pump(halloween);
    expect(find.byType(SvgPicture), findsOneWidget);

    // Вне сезона — геометрическая композиция, картинки нет.
    await pump(null);
    expect(find.byType(SvgPicture), findsNothing);
  });

  test('тыквы в выборе значков — на Хэллоуин или пока выбраны', () {
    expect(AppIcon.pumpkin.offeredIn(seasonId: 'halloween'), isTrue);
    expect(AppIcon.pumpkinNight.offeredIn(seasonId: 'halloween'), isTrue);
    expect(AppIcon.pumpkin.offeredIn(seasonId: 'newYear'), isFalse);
    expect(AppIcon.pumpkin.offeredIn(), isFalse);
    // Выбранную тыкву после сезона не прячем: её видно в лаунчере.
    expect(AppIcon.pumpkin.offeredIn(selected: AppIcon.pumpkin), isTrue);
    expect(AppIcon.cookieCap.offeredIn(), isTrue);
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
