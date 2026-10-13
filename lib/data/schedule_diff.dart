import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'models/lesson.dart';

/// Что случилось с парой.
enum ScheduleChangeKind {
  added('Добавилась пара'),
  removed('Пару убрали'),
  moved('Пару перенесли'),
  edited('Пара изменилась');

  const ScheduleChangeKind(this.label);

  final String label;
}

/// Одна правка в расписании.
@immutable
class ScheduleChange {
  const ScheduleChange({
    required this.kind,
    required this.date,
    required this.title,
    required this.time,
    this.previousTime,
  });

  final ScheduleChangeKind kind;

  /// День, в котором произошла правка.
  final DateTime date;

  /// Название предмета.
  final String title;

  /// Время пары после правки: «13:05».
  final String time;

  /// Откуда перенесли — только у [ScheduleChangeKind.moved].
  final String? previousTime;

  /// «Добавилась пара 13:05 — Маркетинг».
  String get label => switch (kind) {
    ScheduleChangeKind.moved =>
      '${kind.label} с $previousTime на $time — $title',
    _ => '${kind.label} $time — $title',
  };

  /// То же, но с маленькой буквы — для середины фразы. Строчным становится
  /// только начало: название предмета остаётся как на сайте.
  String get lowerLabel =>
      kind.label.toLowerCase() + label.substring(kind.label.length);

  @override
  bool operator ==(Object other) =>
      other is ScheduleChange &&
      other.kind == kind &&
      other.date == date &&
      other.title == title &&
      other.time == time &&
      other.previousTime == previousTime;

  @override
  int get hashCode => Object.hash(kind, date, title, time, previousTime);

  @override
  String toString() => '${_dayName(date)}: $label';
}

/// Чем новое расписание отличается от прежнего.
@immutable
class ScheduleDiff {
  const ScheduleDiff({required this.changes, required this.newDays});

  /// Правки в днях, которые были и раньше.
  final List<ScheduleChange> changes;

  /// Дни, которых в прежнем расписании не было вовсе: сайт опубликовал
  /// следующую неделю.
  final List<ScheduleDay> newDays;

  bool get isEmpty => changes.isEmpty && newDays.isEmpty;

  /// Новая неделя — это когда появились учебные дни, а не пустые выходные.
  bool get hasNewWeek => newDays.any((d) => d.lessons.isNotEmpty);

  /// «19–25 октября» — края новой недели.
  String get newWeekRange {
    final List<ScheduleDay> days = [...newDays]
      ..sort((a, b) => a.date.compareTo(b.date));
    if (days.isEmpty) return '';
    final DateTime first = days.first.date;
    final DateTime last = days.last.date;
    final DateFormat day = DateFormat('d', 'ru');
    final DateFormat full = DateFormat('d MMMM', 'ru');
    if (first == last) return full.format(first);
    return first.month == last.month
        ? '${day.format(first)}–${full.format(last)}'
        : '${full.format(first)} – ${full.format(last)}';
  }

  /// «17 пар, зачёт в среду» — коротко о новой неделе.
  String get newWeekSummary {
    final int pairs = newDays.fold(0, (sum, day) => sum + day.pairCount);
    final List<String> parts = [
      '$pairs ${ScheduleDay.pairsWord(pairs)}',
      for (final ScheduleDay day in newDays)
        for (final LessonType type in day.assessments)
          '${type.label.toLowerCase()} в ${_weekdayIn(day.date)}',
    ];
    return parts.join(', ');
  }

  /// Заголовок уведомления об изменениях.
  String get changesTitle =>
      changes.length == 1 ? changes.single.kind.label : 'Расписание изменилось';

  /// Текст уведомления об изменениях: одна правка — целиком, несколько —
  /// по дням.
  String get changesBody {
    if (changes.length == 1) {
      final ScheduleChange change = changes.single;
      return '${_dayName(change.date)}, ${change.lowerLabel}';
    }
    final Map<DateTime, int> byDay = {};
    for (final ScheduleChange change in changes) {
      byDay[change.date] = (byDay[change.date] ?? 0) + 1;
    }
    final List<String> days = [
      for (final DateTime date in byDay.keys.toList()..sort()) _dayName(date),
    ];
    return '${changes.length} ${_changesWord(changes.length)}: '
        '${days.join(', ')}';
  }

  static String _changesWord(int n) {
    final int mod100 = n % 100;
    final int mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'изменений';
    if (mod10 == 1) return 'изменение';
    if (mod10 >= 2 && mod10 <= 4) return 'изменения';
    return 'изменений';
  }
}

/// «среда, 15 октября».
String _dayName(DateTime date) => DateFormat('EEEE, d MMMM', 'ru').format(date);

/// «среду», «понедельник» — для «зачёт в среду».
String _weekdayIn(DateTime date) {
  final String name = DateFormat.EEEE('ru').format(date);
  // Винительный падеж: «среда» → «среду», «пятница» → «пятницу».
  if (name.endsWith('а')) return '${name.substring(0, name.length - 1)}у';
  return name;
}

/// Чем [after] отличается от [before].
///
/// Дни сопоставляются по дате: окно сайта (текущая и следующая неделя)
/// едет вперёд, и дни, которые из него выпали, изменением не считаются.
/// Дни позже последнего известного — это опубликованная новая неделя, а не
/// правка.
ScheduleDiff diffSchedules({
  required List<ScheduleWeek> before,
  required List<ScheduleWeek> after,
}) {
  final Map<DateTime, ScheduleDay> old = {
    for (final ScheduleWeek week in before)
      for (final ScheduleDay day in week.days) _dateOnly(day.date): day,
  };
  if (old.isEmpty) {
    // Сравнивать не с чем: первая загрузка — это не изменение.
    return const ScheduleDiff(changes: [], newDays: []);
  }
  final DateTime lastKnown = old.keys.reduce((a, b) => a.isAfter(b) ? a : b);

  final List<ScheduleChange> changes = [];
  final List<ScheduleDay> newDays = [];

  for (final ScheduleWeek week in after) {
    for (final ScheduleDay day in week.days) {
      final DateTime date = _dateOnly(day.date);
      if (date.isAfter(lastKnown)) {
        newDays.add(day);
        continue;
      }
      final ScheduleDay? previous = old[date];
      if (previous == null) continue;
      changes.addAll(_dayChanges(date, previous, day));
    }
  }

  return ScheduleDiff(changes: changes, newDays: newDays);
}

/// Правки одного дня.
List<ScheduleChange> _dayChanges(
  DateTime date,
  ScheduleDay before,
  ScheduleDay after,
) {
  final Map<String, Lesson> old = {
    for (final Lesson lesson in before.lessons) _key(lesson): lesson,
  };
  final Map<String, Lesson> fresh = {
    for (final Lesson lesson in after.lessons) _key(lesson): lesson,
  };

  final List<Lesson> added = [
    for (final MapEntry<String, Lesson> e in fresh.entries)
      if (!old.containsKey(e.key)) e.value,
  ];
  final List<Lesson> removed = [
    for (final MapEntry<String, Lesson> e in old.entries)
      if (!fresh.containsKey(e.key)) e.value,
  ];

  final List<ScheduleChange> changes = [];
  final List<Lesson> rest = [...removed];

  for (final Lesson lesson in added) {
    // Тот же предмет исчез в другое время — это перенос, а не новая пара.
    final int moved = rest.indexWhere((l) => l.title == lesson.title);
    if (moved >= 0) {
      final Lesson from = rest.removeAt(moved);
      changes.add(
        ScheduleChange(
          kind: from.start == lesson.start
              ? ScheduleChangeKind.edited
              : ScheduleChangeKind.moved,
          date: date,
          title: lesson.title,
          time: lesson.start,
          previousTime: from.start,
        ),
      );
      continue;
    }
    changes.add(
      ScheduleChange(
        kind: ScheduleChangeKind.added,
        date: date,
        title: lesson.title,
        time: lesson.start,
      ),
    );
  }

  for (final Lesson lesson in rest) {
    changes.add(
      ScheduleChange(
        kind: ScheduleChangeKind.removed,
        date: date,
        title: lesson.title,
        time: lesson.start,
      ),
    );
  }

  changes.sort((a, b) => a.time.compareTo(b.time));
  return changes;
}

/// Всё, что отличает одну строку расписания от другой.
String _key(Lesson lesson) => [
  lesson.start,
  lesson.end,
  lesson.title,
  lesson.typeLabel,
  lesson.teacher ?? '',
  lesson.group ?? '',
  lesson.room ?? '',
  lesson.subgroup?.toString() ?? '',
].join('|');

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
