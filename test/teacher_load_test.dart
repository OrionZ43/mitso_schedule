import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/day_text.dart';
import 'package:mitso_schedule/data/models/lesson.dart';
import 'package:mitso_schedule/data/teacher_load.dart';

Lesson _lesson({
  required String start,
  required String end,
  String title = 'Системы баз данных',
  String? group,
  String? teacher,
  String? room = '71',
  int? subgroup,
  LessonType type = LessonType.lecture,
}) => Lesson(
  start: start,
  end: end,
  title: title,
  type: type,
  typeLabel: type.label,
  teacher: teacher,
  group: group,
  room: room,
  subgroup: subgroup,
);

ScheduleDay _day(int day, List<Lesson> lessons) =>
    ScheduleDay(date: DateTime(2026, 10, day), lessons: lessons);

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('нагрузка преподавателя', () {
    final ScheduleWeek week = ScheduleWeek(
      label: 'Текущая неделя',
      days: [
        _day(12, [
          _lesson(start: '09:45', end: '11:05', group: '2423 УИР'),
          _lesson(start: '11:15', end: '12:35', group: '2343 МП'),
        ]),
        // Пара с подгруппами — одна пара, а не две.
        _day(13, [
          _lesson(start: '09:45', end: '11:05', group: '2423 УИР', subgroup: 1),
          _lesson(start: '09:45', end: '11:05', group: '2423 УИР', subgroup: 2),
        ]),
        _day(14, const []),
      ],
    );

    test('пары, группы и свободные дни', () {
      final TeacherLoad load = teacherLoadOf(week);

      expect(load.pairs, 3);
      expect(load.groups.map((g) => '${g.group}: ${g.pairs}'), [
        '2423 УИР: 2',
        '2343 МП: 1',
      ]);
      expect(load.freeDays.single.date, DateTime(2026, 10, 14));
      expect(load.busiestDay!.date, DateTime(2026, 10, 12));
      expect(load.isEmpty, isFalse);
    });

    test('неделя без пар — пустая нагрузка', () {
      final TeacherLoad load = teacherLoadOf(
        ScheduleWeek(label: 'Пусто', days: [_day(12, const [])]),
      );

      expect(load.isEmpty, isTrue);
      expect(load.busiestDay, isNull);
    });

    test('берётся неделя, которая ещё не прошла', () {
      final ScheduleWeek past = ScheduleWeek(
        label: 'Прошлая',
        days: [_day(5, const [])],
      );
      expect(
        weekOf([past, week], DateTime(2026, 10, 13))?.label,
        'Текущая неделя',
      );
    });
  });

  group('день текстом', () {
    test('пары, аудитории и преподаватели', () {
      final String text = dayAsText(
        _day(12, [
          _lesson(
            start: '09:45',
            end: '11:05',
            teacher: 'Гардейчик С. М.',
            room: '62 (к)',
          ),
        ]),
      );

      expect(text, contains('Понедельник, 12 октября'));
      expect(text, contains('1 пара · 09:45—11:05'));
      expect(text, contains('09:45–11:05 · Системы баз данных'));
      expect(text, contains('Лекция · ауд. 62 (к) · Гардейчик С. М.'));
    });

    test('подгруппы — отдельными строками', () {
      final String text = dayAsText(
        _day(13, [
          _lesson(
            start: '09:45',
            end: '11:05',
            teacher: 'Гардейчик С. М.',
            subgroup: 1,
          ),
          _lesson(
            start: '09:45',
            end: '11:05',
            teacher: 'Пархимович А. В.',
            subgroup: 2,
            room: '63 (к)',
          ),
        ]),
      );

      expect(text, contains('1 подгруппа'));
      expect(text, contains('2 подгруппа'));
      expect(text, contains('Пархимович А. В.'));
    });

    test('выходной', () {
      expect(dayAsText(_day(18, const [])), contains('Занятий нет'));
    });
  });
}
