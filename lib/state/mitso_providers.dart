import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mitso/mitso_client.dart';
import '../data/models/group_ref.dart';
import 'settings_controller.dart';

/// Не повторять упавшие сетевые провайдеры автоматически.
///
/// Riverpod 3 по умолчанию перезапускает провайдер с ошибкой с нарастающей
/// паузой — для сайта МИТСО это лишняя нагрузка. Обновление только по
/// действию пользователя.
Duration? noRetry(int retryCount, Object error) => null;

/// Источник расписания. В тестах переопределяется подстановкой.
final mitsoApiProvider = FutureProvider<MitsoApi>((ref) async {
  final MitsoClient client = await MitsoClient.create();
  ref.onDispose(client.close);
  return client;
}, retry: noRetry);

/// Текущее время. В тестах — фиксированное.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// «Сейчас» для «Сейчас идёт» и остатка пары: обновляется раз в 30 секунд.
final nowProvider = NotifierProvider<NowController, DateTime>(
  NowController.new,
);

class NowController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime Function() clock = ref.watch(clockProvider);
    final Timer timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => state = clock(),
    );
    ref.onDispose(timer.cancel);
    return clock();
  }
}

/// Чьё расписание показывает приложение.
///
/// Сайт умеет два вида: расписание группы (для студентов) и расписание
/// преподавателя. Данные у них одинаковые — недели, дни, пары, — отличается
/// только то, что стоит в строке рядом с предметом: у студента преподаватель,
/// у преподавателя группа.
@immutable
sealed class ScheduleTarget {
  const ScheduleTarget();

  /// Заголовок экрана: «2423 УИР» или «Абухович Ю. К.».
  String get title;

  /// Строка под заголовком в профиле: «3 курс · Экономический» или
  /// «Преподаватель».
  String? get subtitle;

  /// Подпись под заголовком экрана расписания: там нужно имя, а не только
  /// уточнение.
  String get appBarSubtitle;

  /// Часть ключа кэша: у каждой цели своё сохранённое расписание.
  String get cacheKey;

  Map<String, Object?> toJson();

  static ScheduleTarget? fromJson(Map<String, Object?> json) =>
      switch (json['kind']) {
        'teacher' => TeacherTarget(json['name']! as String),
        'group' => GroupTarget(
          GroupRef.fromJson(json['group']! as Map<String, Object?>),
        ),
        // Записи старых версий: там лежала только группа.
        _ =>
          json.containsKey('groupId')
              ? GroupTarget(GroupRef.fromJson(json))
              : null,
      };
}

/// Расписание группы.
class GroupTarget extends ScheduleTarget {
  const GroupTarget(this.group);

  final GroupRef group;

  @override
  String get title => group.groupName;

  @override
  String? get subtitle => group.details;

  @override
  String get appBarSubtitle => '${group.groupName} · ${group.courseName}';

  @override
  String get cacheKey =>
      '${group.facultyId}|${group.formId}|${group.courseId}|${group.groupId}';

  @override
  Map<String, Object?> toJson() => {'kind': 'group', 'group': group.toJson()};

  @override
  bool operator ==(Object other) =>
      other is GroupTarget && other.group == group;

  @override
  int get hashCode => group.hashCode;
}

/// Расписание преподавателя.
class TeacherTarget extends ScheduleTarget {
  const TeacherTarget(this.name);

  /// Фамилия с инициалами, как на сайте: «Абухович Ю. К.».
  final String name;

  @override
  String get title => name;

  @override
  String? get subtitle => 'Преподаватель';

  @override
  String get appBarSubtitle => '$name · преподаватель';

  @override
  String get cacheKey => 'teacher|$name';

  @override
  Map<String, Object?> toJson() => {'kind': 'teacher', 'name': name};

  @override
  bool operator ==(Object other) =>
      other is TeacherTarget && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Чьё расписание показывать. `null` — ещё не выбрано.
final scheduleTargetProvider =
    NotifierProvider<ScheduleTargetController, ScheduleTarget?>(
      ScheduleTargetController.new,
    );

class ScheduleTargetController extends Notifier<ScheduleTarget?> {
  static const String _key = 'schedule.target';

  /// Ключ старых версий: там лежала только выбранная группа.
  static const String _legacyKey = 'group.selected';

  @override
  ScheduleTarget? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final String? raw = prefs.getString(_key) ?? prefs.getString(_legacyKey);
    if (raw == null) return null;
    try {
      return ScheduleTarget.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // Повреждённая запись — считаем, что ничего не выбрано.
      return null;
    }
  }

  void select(ScheduleTarget target) {
    state = target;
    ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(target.toJson()));
  }
}

/// Выбранная группа; `null` — выбран преподаватель или ничего.
final selectedGroupProvider = Provider<GroupRef?>((ref) {
  final ScheduleTarget? target = ref.watch(scheduleTargetProvider);
  return target is GroupTarget ? target.group : null;
});
