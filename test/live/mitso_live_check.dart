// Проверка клиента на живом apps.mitso.by. Не входит в обычный `flutter test`
// (имя без _test.dart): ходит в сеть и зависит от текущего расписания.
//
//   flutter test test/live/mitso_live_check.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/models/group_ref.dart';
import 'package:mitso_schedule/data/models/lesson.dart';

List<int> _read(String path) => File(path).readAsBytesSync();

void main() {
  // flutter_test по умолчанию подменяет HttpClient заглушкой — здесь нужна сеть.
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('ru');
  });

  // Отрицательный случай (без вложенных сертификатов) здесь не проверить:
  // на Windows Dart сверяет цепочку через системное хранилище, которое само
  // докачивает промежуточный сертификат. Android так не умеет — проверяется
  // на устройстве.

  test(
    'цепочка выбора и расписание 2423 УИР',
    () async {
      final client = MitsoClient.withCertificates([
        for (final a in MitsoClient.certificateAssets) _read(a),
      ]);

      final faculties = await client.faculties();
      debugPrint(
        'факультеты: ${faculties.map((f) => '${f.name}[${f.id}]').join(', ')}',
      );
      final econ = faculties.firstWhere((f) => f.name == 'Экономический');

      final forms = await client.forms(econ.id);
      final day = forms.firstWhere((f) => f.name == 'Дневная');
      final courses = await client.courses(econ.id, day.id);
      final third = courses.firstWhere((c) => c.name == '3 курс');
      final groups = await client.groups(econ.id, day.id, third.id);
      final uir = groups.firstWhere((g) => g.name == '2423 УИР');
      debugPrint('группа: ${uir.name}[${uir.id}]');

      final weeks = await client.groupSchedule(
        GroupRef(
          facultyId: econ.id,
          facultyName: econ.name,
          formId: day.id,
          formName: day.name,
          courseId: third.id,
          courseName: third.name,
          groupId: uir.id,
          groupName: uir.name,
        ),
      );
      for (final w in weeks) {
        debugPrint(
          '— ${w.label}: ${w.days.map((d) => '${d.shortName} ${d.dayNumber} (${d.pairCount})').join(', ')}',
        );
      }
      expect(weeks, isNotEmpty);
      expect(weeks.first.days, isNotEmpty);
      client.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('расписание преподавателя', () async {
    final client = MitsoClient.withCertificates([
      for (final a in MitsoClient.certificateAssets) _read(a),
    ]);

    final List<String> teachers = await client.teachers();
    debugPrint('преподавателей на сайте: ${teachers.length}');
    expect(teachers.length, greaterThan(100));

    // Берём первого, у кого есть занятия: у части преподавателей на
    // текущей неделе пусто, и это нормально.
    List<ScheduleWeek> weeks = const [];
    String? withLessons;
    for (final String teacher in teachers.take(5)) {
      weeks = await client.teacherSchedule(teacher);
      if (weeks.any((w) => w.days.any((d) => d.lessons.isNotEmpty))) {
        withLessons = teacher;
        break;
      }
    }
    expect(withLessons, isNotNull, reason: 'ни у кого из пятерых нет пар');
    debugPrint('преподаватель: $withLessons');
    for (final w in weeks) {
      debugPrint(
        '— ${w.label}: ${w.days.map((d) => '${d.shortName} ${d.dayNumber} (${d.pairCount})').join(', ')}',
      );
    }

    // В расписании преподавателя вместо его имени стоит группа.
    final lesson = weeks.expand((w) => w.days).expand((d) => d.lessons).first;
    debugPrint(
      'пара: ${lesson.start}-${lesson.end} ${lesson.title} '
      '· группа ${lesson.group} · ауд. ${lesson.room}',
    );
    expect(lesson.group, isNotNull);
    expect(lesson.teacher, isNull);
    client.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
