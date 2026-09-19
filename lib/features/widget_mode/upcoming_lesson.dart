import 'package:flutter/material.dart' show DateUtils, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lesson.dart';
import '../../state/mitso_providers.dart';
import '../../state/schedule_controller.dart';
import '../schedule/lesson_timing.dart';

/// Пара, которую показывает компактное окно.
@immutable
class UpcomingLesson {
  const UpcomingLesson({
    required this.slot,
    required this.day,
    this.progress,
    this.startsIn,
  });

  final LessonSlot slot;

  /// День пары.
  final DateTime day;

  /// Пара идёт — сколько её прошло; `null` — ещё впереди.
  final LessonProgress? progress;

  /// Через сколько минут начнётся; `null` — не сегодня.
  final int? startsIn;

  bool get isNow => progress != null;
}

/// Ближайшая пара: идущая сейчас, следующая сегодня, а если сегодня всё —
/// первая в ближайшем учебном дне. `null` — расписания нет или оно кончилось.
final upcomingLessonProvider = Provider<UpcomingLesson?>((ref) {
  final ScheduleState? schedule = ref.watch(scheduleControllerProvider).value;
  if (schedule == null) return null;

  final DateTime now = ref.watch(nowProvider);
  final DateTime today = DateUtils.dateOnly(now);

  for (final ScheduleDay day in schedule.days) {
    if (DateUtils.dateOnly(day.date).isBefore(today)) continue;
    final List<LessonSlot> slots = day.slots();
    if (slots.isEmpty) continue;

    final List<SlotStatus> timings = slotTimings(slots, day.date, now);
    for (int i = 0; i < slots.length; i++) {
      if (timings[i].timing == SlotTiming.past) continue;
      return UpcomingLesson(
        slot: slots[i],
        day: day.date,
        progress: timings[i].progress,
        startsIn: timings[i].startsIn,
      );
    }
  }
  return null;
});
