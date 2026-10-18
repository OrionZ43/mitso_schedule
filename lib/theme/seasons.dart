import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Сезонное оформление: свои цвета и фигуры в дни, когда это уместно.
///
/// Рисунков в приложении нет — украшения собраны из библиотеки форм M3
/// (https://m3.material.io/styles/shape: «Use abstract shapes on imagery and
/// decorative UI», «Emphasize aesthetic moments with shape»). Цвет —
/// статичная схема из сида сезона, как у палитр в настройках.
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
    required this.decorShapes,
    required this.decorHint,
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

  /// Что падает сверху: листья, снежинки.
  final List<RoundedPolygon> decorShapes;

  /// Чем украшено — строкой в настройках: «тыквы и листья».
  final String decorHint;

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
/// Узкие окна: оформление должно быть событием, а не фоном на полгода.
final List<Season> kSeasons = [
  Season(
    id: 'halloween',
    name: 'Хэллоуин',
    from: (10, 25),
    to: (11, 2),
    // Тыквенный оранжевый.
    seed: const Color(0xFFE8700A),
    icon: Symbols.mode_night,
    // Круглая дольчатая фигура — силуэт тыквы.
    accentShape: MaterialShapes.puffy,
    decorShapes: [
      MaterialShapes.clover4Leaf,
      MaterialShapes.arch,
      MaterialShapes.ghostish,
      MaterialShapes.fan,
    ],
    decorHint: 'тыквы, листья и привидения',
  ),
  Season(
    id: 'newYear',
    name: 'Новый год',
    from: (12, 15),
    to: (1, 10),
    // Хвойный зелёный.
    seed: const Color(0xFF1F7A4D),
    icon: Symbols.ac_unit,
    // Снежинка.
    accentShape: MaterialShapes.sunny,
    decorShapes: [
      MaterialShapes.sunny,
      MaterialShapes.verySunny,
      MaterialShapes.cookie4Sided,
      MaterialShapes.cookie6Sided,
    ],
    decorHint: 'снежинки и ёлочные огни',
  ),
  Season(
    id: 'spring',
    name: 'Весна',
    from: (3, 1),
    to: (3, 10),
    // Цветущий розовый.
    seed: const Color(0xFFD9477E),
    icon: Symbols.local_florist,
    accentShape: MaterialShapes.flower,
    decorShapes: [
      MaterialShapes.flower,
      MaterialShapes.clover8Leaf,
      MaterialShapes.softBurst,
      MaterialShapes.puffyDiamond,
    ],
    decorHint: 'цветы',
  ),
  Season(
    id: 'firstBell',
    name: 'Первое сентября',
    from: (9, 1),
    to: (9, 7),
    // Осенняя охра.
    seed: const Color(0xFFBE8A00),
    icon: Symbols.school,
    accentShape: MaterialShapes.cookie9Sided,
    decorShapes: [
      MaterialShapes.arch,
      MaterialShapes.fan,
      MaterialShapes.clover4Leaf,
      MaterialShapes.boom,
    ],
    decorHint: 'осенние листья',
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
