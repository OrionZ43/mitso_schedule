import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/mitso/schedule_parser.dart';
import 'package:mitso_schedule/data/models/lesson.dart';

/// Реальный ответ apps.mitso.by для группы 2423 УИР, сохранённый 16.09.2026.
final String fixture = File(
  'test/fixtures/group_schedule_2423_uir.html',
).readAsStringSync();

final DateTime today = DateTime(2026, 9, 16);

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('разбор реальной страницы 2423 УИР', () {
    late List<ScheduleWeek> weeks;
    setUp(() => weeks = ScheduleParser.parse(fixture, today: today));

    ScheduleDay day(int week, int weekday) =>
        weeks[week].days.firstWhere((d) => d.date.weekday == weekday);

    test('в одном ответе две недели с подписями сайта', () {
      expect(weeks.map((w) => w.label), [
        'Текущая неделя',
        '21 сентября - 27 сентября',
      ]);
    });

    test('даты дней с годом, Пн–Сб', () {
      expect(weeks[0].days.map((d) => d.date), [
        for (int d = 14; d <= 19; d++) DateTime(2026, 9, d),
      ]);
      expect(weeks[1].days.first.date, DateTime(2026, 9, 21));
      expect(day(0, DateTime.monday).shortName, 'Пн');
      expect(day(0, DateTime.monday).title, 'Понедельник');
    });

    test('пустые слоты «(нет занятий)» пропускаются', () {
      final ScheduleDay monday = day(0, DateTime.monday);
      expect(monday.lessons, hasLength(3));
      expect(monday.lessons.first.start, '09:45');
    });

    test('обычная пара: название, тип, преподаватель, аудитория', () {
      final Lesson lesson = day(0, DateTime.monday).lessons.first;
      expect(lesson.start, '09:45');
      expect(lesson.end, '11:05');
      expect(
        lesson.title,
        'Правовое регулирование информационной деятельности',
      );
      expect(lesson.type, LessonType.lecture);
      expect(lesson.typeLabel, 'Лекция');
      expect(lesson.teacher, 'Клименко Т. В.');
      expect(lesson.room, '71');
      expect(lesson.subgroup, isNull);
    });

    test('подгруппы: две пары в одно время', () {
      final List<Lesson> labs = day(
        0,
        DateTime.tuesday,
      ).lessons.where((l) => l.start == '11:15').toList();
      expect(labs.map((l) => l.subgroup), [1, 2]);
      expect(labs.map((l) => l.title).toSet(), {
        'Веб-дизайн и шаблоны проектирования',
      });
      expect(labs.map((l) => l.type).toSet(), {LessonType.lab});
      expect(labs.map((l) => l.teacher), ['Калинин М. А.', 'Пархимович А. В.']);
      expect(labs.map((l) => l.room), ['62 (к)', '63 (к)']);
    });

    test('физкультура без аудитории, тип «практическое»', () {
      final Lesson pe = day(
        0,
        DateTime.wednesday,
      ).lessons.firstWhere((l) => l.title == 'Физическая культура');
      expect(pe.type, LessonType.practice);
      expect(pe.room, isNull);
      expect(pe.teacher, 'Преподаватель к.');
    });

    test('«практ/сем» — практика; аудитории с буквами и диапазоном', () {
      final Lesson seminar = day(
        1,
        DateTime.tuesday,
      ).lessons.firstWhere((l) => l.subgroup == 2 && l.start == '09:45');
      expect(seminar.type, LessonType.practice);
      expect(seminar.room, '409 чжф');
      expect(day(0, DateTime.friday).lessons.first.room, '41-42');
    });

    test('сводка дня считает подгруппы одной парой', () {
      // Вторник: 08.15, 09.45 и две подгруппы в 11.15 — три пары.
      expect(day(0, DateTime.tuesday).pairCount, 3);
      expect(day(0, DateTime.tuesday).summary, '3 пары · 08:15—12:35');
    });

    test('модели переживают сериализацию для кэша', () {
      final List<ScheduleWeek> restored = [
        for (final w in weeks) ScheduleWeek.fromJson(w.toJson()),
      ];
      expect(
        restored.map((w) => w.toJson()).toList(),
        weeks.map((w) => w.toJson()).toList(),
      );
    });
  });

  group('отдельные поля', () {
    test('время без ведущего нуля', () {
      expect(ScheduleParser.parseTime('08.15-9.35'), ('08:15', '09:35'));
      expect(ScheduleParser.parseTime(' 13.05-14.25 '), ('13:05', '14:25'));
    });

    test('год — ближайший к сегодняшней дате', () {
      expect(
        ScheduleParser.parseDayHeading(
          'Понедельник, 28 декабря',
          today: DateTime(2027, 1, 3),
        ),
        DateTime(2026, 12, 28),
      );
      expect(
        ScheduleParser.parseDayHeading(
          'Вторник, 5 января',
          today: DateTime(2026, 12, 30),
        ),
        DateTime(2027, 1, 5),
      );
    });

    test('скобки внутри названия не путаются с типом', () {
      final Lesson? lesson = ScheduleParser.parseRow(
        time: '09.45-11.05',
        description: 'Иностранный язык (английский)(практ/сем) Пайгерт Е. А.',
        room: '211',
      );
      expect(lesson!.title, 'Иностранный язык (английский)');
      expect(lesson.type, LessonType.practice);
      expect(lesson.teacher, 'Пайгерт Е. А.');
    });

    test('незнакомые типы сохраняют подпись сайта', () {
      expect(ScheduleParser.parseType('экз'), (LessonType.other, 'Экзамен'));
      expect(ScheduleParser.parseType('кср'), (LessonType.other, 'Кср'));
    });

    test('множественное число пар', () {
      expect([1, 2, 4, 5, 11, 21, 22].map(ScheduleDay.pairsWord), [
        'пара',
        'пары',
        'пары',
        'пар',
        'пар',
        'пара',
        'пары',
      ]);
    });

    test('страница без расписания — понятная ошибка', () {
      expect(
        () =>
            ScheduleParser.parse('<html><body>400</body></html>', today: today),
        throwsA(isA<ScheduleParseException>()),
      );
    });
  });

  group('расписание преподавателя', () {
    final String teacherFixture = File(
      'test/fixtures/teacher_schedule.html',
    ).readAsStringSync();

    late List<ScheduleWeek> weeks;

    setUp(() => weeks = ScheduleParser.parse(teacherFixture, today: today));

    test('недели и дни разбираются', () {
      expect(weeks, hasLength(3));
      expect(weeks.first.label, 'Текущая неделя');
      expect(weeks.expand((w) => w.days), isNotEmpty);
    });

    test('вместо преподавателя в строке стоит группа', () {
      final Lesson lesson = weeks
          .expand((w) => w.days)
          .expand((d) => d.lessons)
          .first;

      expect(lesson.group, isNotNull);
      expect(lesson.teacher, isNull);
      expect(lesson.room, isNotNull);
      expect(lesson.title, isNotEmpty);
    });

    test('подгруппы помечены так же, как у студентов', () {
      final Iterable<Lesson> lessons = weeks
          .expand((w) => w.days)
          .expand((d) => d.lessons);

      // В расписании преподавателя подгруппа тоже пишется «2. Предмет».
      expect(lessons.any((l) => l.subgroup != null), isTrue);
      expect(lessons.every((l) => !l.title.startsWith('2.')), isTrue);
    });
  });
}
