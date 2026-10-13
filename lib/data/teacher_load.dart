import 'package:flutter/foundation.dart';

import 'models/lesson.dart';

/// Сколько пар у группы на неделе.
@immutable
class GroupLoad {
  const GroupLoad({required this.group, required this.pairs});

  final String group;
  final int pairs;
}

/// Нагрузка преподавателя за неделю.
///
/// Считается из уже загруженного расписания: на сайт за этим ходить не надо.
@immutable
class TeacherLoad {
  const TeacherLoad({
    required this.pairs,
    required this.groups,
    required this.freeDays,
    required this.busiestDay,
  });

  /// Всего пар на неделе.
  final int pairs;

  /// Группы по убыванию числа пар.
  final List<GroupLoad> groups;

  /// Учебные дни недели без пар.
  final List<ScheduleDay> freeDays;

  /// День с наибольшим числом пар; `null` — пар нет вовсе.
  final ScheduleDay? busiestDay;

  bool get isEmpty => pairs == 0;
}

/// Нагрузка по неделе [week].
///
/// Пара с подгруппами считается одной: преподаватель проводит её один раз.
/// Группа берётся из строки расписания — в расписании преподавателя там
/// стоит именно она.
TeacherLoad teacherLoadOf(ScheduleWeek week) {
  final Map<String, int> byGroup = {};
  final List<ScheduleDay> freeDays = [];
  int pairs = 0;
  ScheduleDay? busiest;

  for (final ScheduleDay day in week.days) {
    final List<LessonSlot> slots = day.slots();
    if (slots.isEmpty) {
      freeDays.add(day);
      continue;
    }
    pairs += slots.length;
    if (busiest == null || slots.length > busiest.slots().length) {
      busiest = day;
    }
    for (final LessonSlot slot in slots) {
      // Одна пара — один раз за группу, даже если у неё две подгруппы.
      for (final String group in {
        for (final Lesson lesson in slot.lessons)
          if (lesson.group != null) lesson.group!,
      }) {
        byGroup[group] = (byGroup[group] ?? 0) + 1;
      }
    }
  }

  final List<GroupLoad> groups =
      [
        for (final MapEntry<String, int> entry in byGroup.entries)
          GroupLoad(group: entry.key, pairs: entry.value),
      ]..sort((a, b) {
        final int byPairs = b.pairs.compareTo(a.pairs);
        return byPairs != 0 ? byPairs : a.group.compareTo(b.group);
      });

  return TeacherLoad(
    pairs: pairs,
    groups: groups,
    freeDays: freeDays,
    busiestDay: busiest,
  );
}

/// Неделя, в которой лежит [now]; если такой нет — первая.
ScheduleWeek? weekOf(List<ScheduleWeek> weeks, DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  for (final ScheduleWeek week in weeks) {
    for (final ScheduleDay day in week.days) {
      final DateTime date = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
      );
      if (!date.isBefore(today)) return week;
    }
  }
  return weeks.isEmpty ? null : weeks.first;
}
