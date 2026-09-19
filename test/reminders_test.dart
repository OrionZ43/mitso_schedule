import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/data/lesson_reminders.dart';
import 'package:mitso_schedule/data/models/lesson.dart';

/// Среда, 16 сентября 2026, 10:30 — как в остальных тестах.
final DateTime now = DateTime(2026, 9, 16, 10, 30);

Lesson _lesson({
  required String start,
  required String end,
  String title = 'Веб-дизайн и шаблоны проектирования',
  String? room = '71',
  String? group,
  int? subgroup,
}) => Lesson(
  start: start,
  end: end,
  title: title,
  type: LessonType.lecture,
  typeLabel: 'Лекция',
  room: room,
  group: group,
  subgroup: subgroup,
);

ScheduleDay _day(int day, List<Lesson> lessons) =>
    ScheduleDay(date: DateTime(2026, 9, day), lessons: lessons);

void main() {
  test('напоминание встаёт за указанный срок до начала пары', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        _day(16, [_lesson(start: '11:15', end: '12:35')]),
      ],
      before: const Duration(minutes: 15),
      now: now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.id, kReminderBaseId);
    expect(reminders.single.when, DateTime(2026, 9, 16, 11, 0));
    expect(reminders.single.title, 'Веб-дизайн и шаблоны проектирования');
    expect(reminders.single.body, 'Через 15 мин · ауд. 71');
  });

  test('пары, до которых осталось меньше срока, пропускаются', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        _day(16, [
          // Уже идёт.
          _lesson(start: '09:45', end: '11:05'),
          // Начнётся через 45 минут — при сроке в час напоминать поздно.
          _lesson(start: '11:15', end: '12:35'),
          _lesson(start: '13:00', end: '14:20'),
        ]),
      ],
      before: const Duration(hours: 1),
      now: now,
    );

    expect(reminders.map((r) => r.when), [DateTime(2026, 9, 16, 12, 0)]);
    expect(reminders.single.body, 'Через час · ауд. 71');
  });

  test('подгруппы в одно время — одно напоминание', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        _day(16, [
          _lesson(start: '11:15', end: '12:35', room: '62 (к)', subgroup: 1),
          _lesson(start: '11:15', end: '12:35', room: '63', subgroup: 2),
        ]),
      ],
      before: const Duration(minutes: 15),
      now: now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.body, 'Через 15 мин · ауд. 62 (к), 63');
  });

  test('у подгрупп разные предметы — общий заголовок', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        _day(16, [
          _lesson(start: '11:15', end: '12:35', title: 'Английский язык'),
          _lesson(start: '11:15', end: '12:35', title: 'Немецкий язык'),
        ]),
      ],
      before: const Duration(minutes: 15),
      now: now,
    );

    expect(reminders.single.title, 'Пары по подгруппам');
  });

  test('в расписании преподавателя в тексте есть группа', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        _day(16, [
          _lesson(start: '13:00', end: '14:20', group: '2423 УИР', room: '71'),
        ]),
      ],
      before: const Duration(minutes: 90),
      now: now,
    );

    expect(reminders.single.body, 'Через 1 ч 30 мин · 2423 УИР · ауд. 71');
  });

  test('напоминаний не больше лимита, номера идут по времени подряд', () {
    final List<LessonReminder> reminders = planLessonReminders(
      days: [
        for (int day = 17; day < 27; day++)
          _day(day, [
            _lesson(start: '13:00', end: '14:20'),
            _lesson(start: '11:15', end: '12:35'),
          ]),
      ],
      before: const Duration(minutes: 15),
      now: now,
      limit: 5,
    );

    expect(reminders, hasLength(5));
    expect(reminders.map((r) => r.id), [
      for (int i = 0; i < 5; i++) kReminderBaseId + i,
    ]);
    // Ближайшие пять: 17-го обе, 18-го обе, 19-го первая.
    expect(reminders.map((r) => r.when), [
      DateTime(2026, 9, 17, 11, 0),
      DateTime(2026, 9, 17, 12, 45),
      DateTime(2026, 9, 18, 11, 0),
      DateTime(2026, 9, 18, 12, 45),
      DateTime(2026, 9, 19, 11, 0),
    ]);
  });

  test('выходные пропускаются, расписание без пар ничего не планирует', () {
    expect(
      planLessonReminders(
        days: [_day(19, const []), _day(20, const [])],
        before: const Duration(minutes: 15),
        now: now,
      ),
      isEmpty,
    );
  });
}
