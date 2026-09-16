import 'dart:io';

import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/mitso/schedule_parser.dart';
import 'package:mitso_schedule/data/models/group_ref.dart';
import 'package:mitso_schedule/data/models/lesson.dart';

/// Среда, 16 сентября 2026, 10:30 — в это время у 2423 УИР идёт пара.
final DateTime fakeNow = DateTime(2026, 9, 16, 10, 30);

/// Группа из сохранённой страницы.
const GroupRef group2423 = GroupRef(
  facultyId: 'E`konomicheskij',
  facultyName: 'Экономический',
  formId: 'Dnevnaya',
  formName: 'Дневная',
  courseId: '3 kurs',
  courseName: '3 курс',
  groupId: '2423 UIR',
  groupName: '2423 УИР',
);

/// Подстановка сайта: расписание — настоящая страница 2423 УИР,
/// сохранённая 16.09.2026; списки выбора — реальные значения сайта.
class FakeMitsoApi implements MitsoApi {
  FakeMitsoApi({this.failSchedule = false});

  /// Имитировать недоступный сайт.
  final bool failSchedule;

  int scheduleRequests = 0;

  @override
  Future<List<MitsoOption>> faculties() async => const [
    MitsoOption(id: 'YUridicheskij', name: 'Юридический'),
    MitsoOption(id: 'Magistratura', name: 'Магистратура'),
    MitsoOption(id: 'E`konomicheskij', name: 'Экономический'),
  ];

  @override
  Future<List<MitsoOption>> forms(String facultyId) async => const [
    MitsoOption(id: 'Dnevnaya', name: 'Дневная'),
    MitsoOption(id: 'Zaochnaya', name: 'Заочная'),
  ];

  @override
  Future<List<MitsoOption>> courses(String facultyId, String formId) async =>
      const [
        MitsoOption(id: '2 kurs', name: '2 курс'),
        MitsoOption(id: '3 kurs', name: '3 курс'),
      ];

  @override
  Future<List<MitsoOption>> groups(
    String facultyId,
    String formId,
    String courseId,
  ) async => const [
    MitsoOption(id: '2421 ISIT', name: '2421 ИСИТ'),
    MitsoOption(id: '2423 UIR', name: '2423 УИР'),
  ];

  @override
  Future<List<ScheduleWeek>> groupSchedule(GroupRef group) async {
    scheduleRequests++;
    if (failSchedule) {
      throw const MitsoException('Нет соединения с сайтом расписания.');
    }
    return ScheduleParser.parse(
      File('test/fixtures/group_schedule_2423_uir.html').readAsStringSync(),
      today: fakeNow,
    );
  }
}
