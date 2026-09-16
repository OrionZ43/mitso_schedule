import 'package:flutter/material.dart' show DateUtils, immutable;

import '../../data/models/lesson.dart';

/// Где пара относительно текущего момента.
enum SlotTiming { past, now, upcoming }

/// Прогресс идущей пары.
@immutable
class LessonProgress {
  const LessonProgress({required this.fraction, required this.minutesLeft});

  /// Доля прошедшего времени, 0..1.
  final double fraction;

  /// Сколько минут до конца, с округлением вверх.
  final int minutesLeft;

  /// Прогресс [slot] в дне [day] на момент [now]; `null`, если пара не идёт.
  static LessonProgress? of(LessonSlot slot, DateTime day, DateTime now) {
    if (!DateUtils.isSameDay(day, now)) return null;
    final int seconds = now.hour * 3600 + now.minute * 60 + now.second;
    final int start = slot.startMinutes * 60;
    final int end = slot.endMinutes * 60;
    if (seconds < start || seconds >= end) return null;
    return LessonProgress(
      fraction: (seconds - start) / (end - start),
      minutesLeft: ((end - seconds) / 60).ceil(),
    );
  }
}

typedef SlotStatus = ({
  SlotTiming timing,
  LessonProgress? progress,
  int? startsIn,
});

/// Сроки пар дня на момент [now]: прошла, идёт или впереди, и через сколько
/// минут начнётся ближайшая сегодняшняя.
List<SlotStatus> slotTimings(
  List<LessonSlot> slots,
  DateTime day,
  DateTime now,
) {
  final DateTime today = DateUtils.dateOnly(now);
  final DateTime date = DateUtils.dateOnly(day);
  final int nowMinutes = now.hour * 60 + now.minute;
  bool nextFound = false;

  final List<SlotStatus> result = [];
  for (final LessonSlot slot in slots) {
    final LessonProgress? progress = LessonProgress.of(slot, day, now);
    final SlotTiming timing = date.isBefore(today)
        ? SlotTiming.past
        : date.isAfter(today)
        ? SlotTiming.upcoming
        : progress != null
        ? SlotTiming.now
        : slot.endMinutes <= nowMinutes
        ? SlotTiming.past
        : SlotTiming.upcoming;

    int? startsIn;
    if (date == today && timing == SlotTiming.upcoming && !nextFound) {
      startsIn = slot.startMinutes - nowMinutes;
      nextFound = true;
    }
    result.add((timing: timing, progress: progress, startsIn: startsIn));
  }
  return result;
}

/// `через 25 мин`, `через 1 ч`, `через 2 ч 5 мин`.
String startsInLabel(int minutes) {
  if (minutes < 60) return 'через $minutes мин';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? 'через $hours ч' : 'через $hours ч $rest мин';
}

/// Номер аудитории с сайта → подпись: `71` → `ауд. 71`, прочее без изменений.
String roomLabel(String room) =>
    RegExp(r'^\d').hasMatch(room) ? 'ауд. $room' : room;

/// Строка «кто и где» для строки пары: `Калинин М. А. · ауд. 71`, у подгрупп —
/// с номером впереди, у разных предметов — с названием.
String lessonDetailsLine(Lesson lesson, {bool withTitle = false}) => [
  if (lesson.subgroup != null) '${lesson.subgroup} подгруппа',
  if (withTitle) lesson.title,
  ?lesson.teacher,
  if (lesson.room != null) roomLabel(lesson.room!),
].join(' · ');
