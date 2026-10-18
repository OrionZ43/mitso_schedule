import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Сезонное оформление: свои цвета, картина на весь фон, фигура под номером
/// аудитории и картинка пустых состояний в дни, когда это уместно.
///
/// Картина — готовая иллюстрация (`assets/seasons`, Storyset), приглушённая
/// до фона; форма аудитории — из библиотеки форм M3
/// (https://m3.material.io/styles/shape: «Emphasize aesthetic moments with
/// shape»). Цвет — статичная схема из сида сезона, как у палитр в настройках.
@immutable
class Season {
  const Season({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    required this.seed,
    required this.icon,
    required this.accentShape,
    required this.decorHint,
    this.backdrops = const {},
    this.backdropDayColors = const {},
    this.marker,
    this.emptyArt,
  });

  /// Ключ для настроек и тестов.
  final String id;

  /// «Хэллоуин», «Новый год».
  final String name;

  /// Границы включительно: (месяц, день).
  final (int month, int day) from;
  final (int month, int day) to;

  /// Опорный цвет схемы сезона.
  final Color seed;

  /// Значок сезона — в настройках рядом с переключателем.
  final IconData icon;

  /// Форма номера аудитории на карточке пары.
  final RoundedPolygon accentShape;

  /// Чем украшено — строкой в настройках после названия сезона.
  final String decorHint;

  /// Картины на весь фон по вкладкам (`assets/seasons/…svg`): у каждой своя
  /// сцена. Вкладки нет в словаре — там только цвета сезона.
  final Map<SeasonPage, String> backdrops;

  /// Какие цвета картины подменить в светлой теме: ночная картина днём
  /// серая, тёплая подложка вместо тёмной делает её вечерней.
  final Map<String, String> backdropDayColors;

  /// Значок на шкале идущей пары — летучая мышь летит по линии;
  /// `null` — обычная шкала.
  final String? marker;

  /// Картинка пустых состояний («Занятий нет», «Задач нет») на месте
  /// геометрической композиции; `null` — фигуры, как вне сезона.
  final String? emptyArt;

  /// Сезон идёт в дату [date]; интервал может переходить через Новый год.
  bool covers(DateTime date) {
    final int day = date.month * 100 + date.day;
    final int start = from.$1 * 100 + from.$2;
    final int end = to.$1 * 100 + to.$2;
    return start <= end
        ? day >= start && day <= end
        : day >= start || day <= end;
  }
}

/// Сезоны по порядку в году.
///
/// Окна широкие: оформление должно успеть попасться на глаза, но не висеть
/// полгода. Хэллоуин и первое сентября — по две недели, Новый год — от первых
/// ёлок до старого Нового года, весна — первая половина марта.
final List<Season> kSeasons = [
  Season(
    id: 'halloween',
    name: 'Хэллоуин',
    from: (10, 18),
    to: (11, 2),
    // Тыквенный оранжевый.
    seed: const Color(0xFFE8700A),
    icon: Symbols.mode_night,
    // Круглая дольчатая фигура — силуэт тыквы.
    accentShape: MaterialShapes.puffy,
    decorHint: 'дом с привидениями, летучая мышь и кот в тыкве',
    backdrops: {
      // Дом с привидениями, тыквенная лавка с пугалом, праздничный стол.
      SeasonPage.schedule: 'assets/seasons/halloween-schedule.svg',
      SeasonPage.notes: 'assets/seasons/halloween-notes.svg',
      SeasonPage.profile: 'assets/seasons/halloween-profile.svg',
    },
    // Тёмно-серая подложка ночи → тёплый закат.
    backdropDayColors: {'#37474f': '#F4B98E'},
    marker: 'assets/seasons/bat.svg',
    emptyArt: 'assets/seasons/halloween-cat.svg',
  ),
  Season(
    id: 'newYear',
    name: 'Новый год',
    from: (12, 5),
    to: (1, 15),
    // Хвойный зелёный.
    seed: const Color(0xFF1F7A4D),
    icon: Symbols.ac_unit,
    // Снежинка.
    accentShape: MaterialShapes.sunny,
    // Картин пока нет: цвета и фигура номера аудитории.
    decorHint: 'хвойные цвета и снежинка у номера аудитории',
  ),
  Season(
    id: 'spring',
    name: 'Весна',
    from: (3, 1),
    to: (3, 15),
    // Цветущий розовый.
    seed: const Color(0xFFD9477E),
    icon: Symbols.local_florist,
    accentShape: MaterialShapes.flower,
    decorHint: 'весенние цвета и цветок у номера аудитории',
  ),
  Season(
    id: 'firstBell',
    name: 'Первое сентября',
    from: (9, 1),
    to: (9, 14),
    // Осенняя охра.
    seed: const Color(0xFFBE8A00),
    icon: Symbols.school,
    accentShape: MaterialShapes.cookie9Sided,
    decorHint: 'осенние цвета',
  ),
];

/// Ближайший сезон после [date] и дата его начала.
///
/// Показывается в настройках, когда праздников сейчас нет: видно, чего ждать
/// и что именно включено.
(Season season, DateTime starts) nextSeasonAfter(DateTime date) {
  final DateTime today = DateTime(date.year, date.month, date.day);
  (Season, DateTime)? best;
  for (final Season season in kSeasons) {
    for (final int year in [today.year, today.year + 1]) {
      final DateTime start = DateTime(year, season.from.$1, season.from.$2);
      if (!start.isAfter(today)) continue;
      if (best == null || start.isBefore(best.$2)) best = (season, start);
    }
  }
  return best!;
}

/// Какой сезон идёт в [date]; `null` — обычные дни.
Season? seasonOn(DateTime date) {
  for (final Season season in kSeasons) {
    if (season.covers(date)) return season;
  }
  return null;
}

/// Идущий сезон в теме: общим виджетам (пустому состоянию) не нужно знать о
/// провайдерах — сезон приходит вместе с цветами, из которых он и собран.
class SeasonTheme extends ThemeExtension<SeasonTheme> {
  const SeasonTheme({this.season});

  /// Сезон, если сезонное оформление включено и он идёт; иначе `null`.
  final Season? season;

  @override
  SeasonTheme copyWith({Season? season}) =>
      SeasonTheme(season: season ?? this.season);

  /// Картинки не смешиваются: сезон, как и схема, меняется сразу
  /// (`themeAnimationDuration: Duration.zero`).
  @override
  SeasonTheme lerp(ThemeExtension<SeasonTheme>? other, double t) =>
      other is SeasonTheme && t >= 0.5 ? other : this;
}

/// Вкладка, у которой своя картина сезона.
enum SeasonPage { schedule, notes, profile }
