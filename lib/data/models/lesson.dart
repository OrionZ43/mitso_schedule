import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Тип занятия. Задаёт цвет бейджа на карточке.
///
/// На сайте тип пишется сокращением в скобках после названия: `(лек)`,
/// `(лаб)`, `(практ/сем)`, `(практическое)`. Всё, что не распознано, —
/// [other] с исходной подписью.
enum LessonType {
  lecture('Лекция'),
  practice('Практика'),
  lab('Лаб'),
  other('Занятие');

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
    required this.typeLabel,
    this.teacher,
    this.room,
    this.subgroup,
  });

  /// Начало и конец в формате `HH:mm`.
  final String start;
  final String end;

  final String title;
  final LessonType type;

  /// Подпись бейджа: для известных типов — [LessonType.label], для прочих —
  /// сокращение с сайта.
  final String typeLabel;

  /// `Клименко Т. В.`; `null`, если на сайте не указан.
  final String? teacher;

  /// `71`, `62 (к)`, `41-42`; `null`, если не указана.
  final String? room;

  /// Номер подгруппы, если пара идёт параллельно у нескольких подгрупп.
  final int? subgroup;

  /// Минуты от полуночи для начала и конца — для «Сейчас идёт».
  int get startMinutes => _minutes(start);
  int get endMinutes => _minutes(end);

  static int _minutes(String hhmm) {
    final List<String> parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'title': title,
    'type': type.name,
    'typeLabel': typeLabel,
    'teacher': teacher,
    'room': room,
    'subgroup': subgroup,
  };

  factory Lesson.fromJson(Map<String, Object?> json) => Lesson(
    start: json['start']! as String,
    end: json['end']! as String,
    title: json['title']! as String,
    type: LessonType.values.byName(json['type']! as String),
    typeLabel: json['typeLabel']! as String,
    teacher: json['teacher'] as String?,
    room: json['room'] as String?,
    subgroup: json['subgroup'] as int?,
  );
}

@immutable
class ScheduleDay {
  const ScheduleDay({required this.date, required this.lessons});

  /// Дата без времени.
  final DateTime date;

  /// Пары в порядке расписания; у подгрупп одно время на несколько пар.
  final List<Lesson> lessons;

  bool get isEmpty => lessons.isEmpty;

  /// `Пн`, `Вт`, ...
  String get shortName => _capitalize(DateFormat.E('ru').format(date));

  /// `Понедельник`, `Вторник`, ...
  String get title => _capitalize(DateFormat.EEEE('ru').format(date));

  /// Число месяца.
  String get dayNumber => date.day.toString();

  /// Сколько разных временных слотов занято: подгруппы в одно время — одна пара.
  int get pairCount => lessons.map((l) => l.start).toSet().length;

  /// Подпись справа от названия дня: `3 пары · 09:45—14:25` или `Выходной`.
  String get summary {
    if (lessons.isEmpty) return 'Выходной';
    final String first = lessons.map((l) => l.start).reduce(_min);
    final String last = lessons.map((l) => l.end).reduce(_max);
    return '$pairCount ${pairsWord(pairCount)} · $first—$last';
  }

  static String _min(String a, String b) => a.compareTo(b) <= 0 ? a : b;
  static String _max(String a, String b) => a.compareTo(b) >= 0 ? a : b;

  /// «пара», «пары», «пар» по правилам русского множественного числа.
  static String pairsWord(int n) {
    final int mod100 = n % 100;
    final int mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'пар';
    if (mod10 == 1) return 'пара';
    if (mod10 >= 2 && mod10 <= 4) return 'пары';
    return 'пар';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'lessons': [for (final l in lessons) l.toJson()],
  };

  factory ScheduleDay.fromJson(Map<String, Object?> json) => ScheduleDay(
    date: DateTime.parse(json['date']! as String),
    lessons: [
      for (final l in json['lessons']! as List<Object?>)
        Lesson.fromJson(l! as Map<String, Object?>),
    ],
  );
}

@immutable
class ScheduleWeek {
  const ScheduleWeek({required this.label, required this.days});

  /// Подпись недели с сайта: `Текущая неделя`, `21 сентября - 27 сентября`.
  final String label;

  final List<ScheduleDay> days;

  Map<String, Object?> toJson() => {
    'label': label,
    'days': [for (final d in days) d.toJson()],
  };

  factory ScheduleWeek.fromJson(Map<String, Object?> json) => ScheduleWeek(
    label: json['label']! as String,
    days: [
      for (final d in json['days']! as List<Object?>)
        ScheduleDay.fromJson(d! as Map<String, Object?>),
    ],
  );
}
