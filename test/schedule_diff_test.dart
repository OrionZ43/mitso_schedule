import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/models/lesson.dart';
import 'package:mitso_schedule/data/schedule_diff.dart';

Lesson _lesson({
  required String start,
  String end = '12:35',
  String title = 'Системы баз данных',
  LessonType type = LessonType.lecture,
  String? room = '71',
}) => Lesson(
  start: start,
  end: end,
  title: title,
  type: type,
  typeLabel: type.label,
  teacher: 'Гардейчик С. М.',
  room: room,
);

ScheduleDay _day(int day, List<Lesson> lessons) =>
    ScheduleDay(date: DateTime(2026, 10, day), lessons: lessons);

ScheduleWeek _week(String label, List<ScheduleDay> days) =>
    ScheduleWeek(label: label, days: days);

/// Неделя 12–17 октября с одной парой в понедельник.
List<ScheduleWeek> _base() => [
  _week('Текущая неделя', [
    _day(12, [_lesson(start: '09:45', end: '11:05')]),
    _day(13, const []),
  ]),
];

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  test('первая загрузка изменением не считается', () {
    expect(diffSchedules(before: const [], after: _base()).isEmpty, isTrue);
  });

  test('одинаковое расписание — пусто', () {
    expect(diffSchedules(before: _base(), after: _base()).isEmpty, isTrue);
  });

  test('добавилась пара', () {
    final ScheduleDiff diff = diffSchedules(
      before: _base(),
      after: [
        _week('Текущая неделя', [
          _day(12, [
            _lesson(start: '09:45', end: '11:05'),
            _lesson(start: '11:15', title: 'Маркетинг'),
          ]),
          _day(13, const []),
        ]),
      ],
    );

    expect(diff.changes, hasLength(1));
    expect(diff.changes.single.kind, ScheduleChangeKind.added);
    expect(diff.changes.single.title, 'Маркетинг');
    expect(diff.changesTitle, 'Добавилась пара');
    expect(
      diff.changesBody,
      'понедельник, 12 октября, добавилась пара 11:15 — Маркетинг',
    );
  });

  test('пару убрали', () {
    final ScheduleDiff diff = diffSchedules(
      before: _base(),
      after: [
        _week('Текущая неделя', [_day(12, const []), _day(13, const [])]),
      ],
    );

    expect(diff.changes.single.kind, ScheduleChangeKind.removed);
    expect(diff.changes.single.time, '09:45');
  });

  test('пару перенесли на другое время', () {
    final ScheduleDiff diff = diffSchedules(
      before: _base(),
      after: [
        _week('Текущая неделя', [
          _day(12, [_lesson(start: '13:05', end: '14:25')]),
          _day(13, const []),
        ]),
      ],
    );

    expect(diff.changes.single.kind, ScheduleChangeKind.moved);
    expect(diff.changes.single.previousTime, '09:45');
    expect(diff.changes.single.time, '13:05');
  });

  test('сменилась аудитория — пара изменилась, а не добавилась', () {
    final ScheduleDiff diff = diffSchedules(
      before: _base(),
      after: [
        _week('Текущая неделя', [
          _day(12, [_lesson(start: '09:45', end: '11:05', room: '62 (к)')]),
          _day(13, const []),
        ]),
      ],
    );

    expect(diff.changes.single.kind, ScheduleChangeKind.edited);
  });

  test('появилась следующая неделя', () {
    final ScheduleDiff diff = diffSchedules(
      before: _base(),
      after: [
        ..._base(),
        _week('19 октября - 25 октября', [
          _day(19, [
            _lesson(start: '09:45', end: '11:05', type: LessonType.credit),
            _lesson(start: '11:15', title: 'Маркетинг'),
          ]),
          _day(20, [_lesson(start: '09:45', end: '11:05')]),
        ]),
      ],
    );

    expect(diff.changes, isEmpty);
    expect(diff.hasNewWeek, isTrue);
    expect(diff.newWeekRange, '19–20 октября');
    expect(diff.newWeekSummary, '3 пары, зачёт в понедельник');
  });

  test('несколько правок — уведомление по дням', () {
    final ScheduleDiff diff = diffSchedules(
      before: [
        _week('Текущая неделя', [
          _day(12, [_lesson(start: '09:45', end: '11:05')]),
          _day(13, [_lesson(start: '09:45', end: '11:05')]),
        ]),
      ],
      after: [
        _week('Текущая неделя', [
          _day(12, [
            _lesson(start: '09:45', end: '11:05'),
            _lesson(start: '11:15', title: 'Маркетинг'),
          ]),
          _day(13, const []),
        ]),
      ],
    );

    expect(diff.changes, hasLength(2));
    expect(diff.changesTitle, 'Расписание изменилось');
    expect(
      diff.changesBody,
      '2 изменения: понедельник, 12 октября, вторник, 13 октября',
    );
  });
}
