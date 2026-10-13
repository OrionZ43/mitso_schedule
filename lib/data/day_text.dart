import 'package:intl/intl.dart';

import 'models/lesson.dart';

/// День расписания текстом — чтобы скинуть в чат.
///
/// Формат простой и читаемый без приложения: заголовок с датой и строки пар.
String dayAsText(ScheduleDay day, {String? title}) {
  final List<LessonSlot> slots = day.slots();
  final String date = DateFormat('EEEE, d MMMM', 'ru').format(day.date);
  final String heading = _capitalize(date);

  final StringBuffer text = StringBuffer();
  text.writeln(title == null ? heading : '$heading · $title');
  if (slots.isEmpty) {
    text.writeln('Занятий нет');
    return text.toString().trimRight();
  }

  text.writeln(day.summary);
  for (final LessonSlot slot in slots) {
    text.writeln();
    text.writeln('${slot.start}–${slot.end} · ${_slotTitle(slot)}');
    for (final Lesson lesson in slot.lessons) {
      final List<String> parts = [
        if (lesson.subgroup != null) '${lesson.subgroup} подгруппа',
        if (slot.commonTitle == null) lesson.title,
        lesson.typeLabel,
        if (lesson.room != null) 'ауд. ${lesson.room}',
        if (lesson.group != null) lesson.group!,
        if (lesson.teacher != null) lesson.teacher!,
      ];
      text.writeln('  ${parts.join(' · ')}');
    }
  }
  return text.toString().trimRight();
}

/// Название пары: общее для подгрупп или пометка, что предметы разные.
String _slotTitle(LessonSlot slot) => slot.commonTitle ?? 'Пары по подгруппам';

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
