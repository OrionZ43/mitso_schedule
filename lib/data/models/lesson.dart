import 'package:flutter/foundation.dart';

/// Тип занятия. Задаёт цвет бейджа на карточке.
enum LessonType {
  lecture('Лекция'),
  practice('Практика'),
  lab('Лаб');

  const LessonType(this.label);

  final String label;
}

@immutable
class Lesson {
  const Lesson({
    required this.start,
    required this.end,
    required this.title,
    required this.type,
    required this.teacher,
    required this.room,
    this.isNow = false,
    this.timeLeft,
    this.progress,
  });

  final String start;
  final String end;
  final String title;
  final LessonType type;
  final String teacher;
  final String room;

  /// Пара идёт прямо сейчас — карточка становится залитой.
  final bool isNow;

  /// Человекочитаемый остаток, например `32 мин`.
  final String? timeLeft;

  /// Доля прошедшего времени пары, 0..1.
  final double? progress;
}

@immutable
class ScheduleDay {
  const ScheduleDay({
    required this.key,
    required this.shortName,
    required this.dayNumber,
    required this.date,
    required this.title,
    required this.lessons,
  });

  /// `mon`, `tue`, ...
  final String key;

  /// `Пн`, `Вт`, ...
  final String shortName;

  /// Число месяца: `14`, `15`, ...
  final String dayNumber;

  /// Реальная дата — используется для форматирования через `intl`.
  final DateTime date;

  /// `Понедельник`, `Вторник`, ...
  final String title;

  final List<Lesson> lessons;

  bool get isEmpty => lessons.isEmpty;

  /// Подпись справа от названия дня: `4 пары · 08:30—15:45` или `Выходной`.
  String get summary {
    if (lessons.isEmpty) return 'Выходной';
    return '${lessons.length} пары · ${lessons.first.start}—${lessons.last.end}';
  }
}
