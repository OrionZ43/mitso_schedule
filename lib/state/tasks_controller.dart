import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/lesson.dart';
import '../data/models/task_item.dart';
import 'mitso_providers.dart';
import 'schedule_controller.dart';
import 'settings_controller.dart';

/// Вкладка списка: активные или выполненные.
enum TaskFilter {
  active('Активные'),
  done('Выполненные');

  const TaskFilter(this.label);

  final String label;
}

final taskFilterProvider = NotifierProvider<TaskFilterController, TaskFilter>(
  TaskFilterController.new,
);

class TaskFilterController extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.active;

  void select(TaskFilter filter) => state = filter;
}

final tasksControllerProvider =
    NotifierProvider<TasksController, List<TaskItem>>(TasksController.new);

class TasksController extends Notifier<List<TaskItem>> {
  static const String storageKey = 'tasks.items';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<TaskItem> build() {
    final String? raw = _prefs.getString(storageKey);
    if (raw == null) return const [];
    try {
      return [
        for (final Object? item in jsonDecode(raw) as List<Object?>)
          TaskItem.fromJson(item! as Map<String, Object?>),
      ];
    } catch (_) {
      // Повреждённая запись — начинаем с пустого списка.
      return const [];
    }
  }

  void _save() {
    _prefs.setString(
      storageKey,
      jsonEncode([for (final TaskItem task in state) task.toJson()]),
    );
  }

  /// Добавляет задачу и возвращает список к вкладке «Активные».
  void add({required String text, String? subject, DateTime? dueAt}) {
    ref.read(taskFilterProvider.notifier).select(TaskFilter.active);
    state = [
      TaskItem(
        id: ref.read(clockProvider)().microsecondsSinceEpoch.toString(),
        text: text,
        subject: subject,
        dueAt: dueAt,
      ),
      ...state,
    ];
    _save();
  }

  void update(
    String id, {
    required String text,
    String? subject,
    DateTime? dueAt,
  }) {
    state = [
      for (final TaskItem task in state)
        if (task.id == id)
          task.copyWith(
            text: text,
            subject: subject,
            clearSubject: subject == null,
            dueAt: dueAt,
            clearDueAt: dueAt == null,
          )
        else
          task,
    ];
    _save();
  }

  void toggle(String id) {
    state = [
      for (final TaskItem task in state)
        task.id == id ? task.copyWith(isDone: !task.isDone) : task,
    ];
    _save();
  }

  void remove(String id) {
    state = [
      for (final TaskItem task in state)
        if (task.id != id) task,
    ];
    _save();
  }
}

/// Задачи текущей вкладки, разложенные по срокам: просроченные первыми,
/// внутри раздела — по дате.
final groupedTasksProvider = Provider<Map<TaskGroup, List<TaskItem>>>((ref) {
  final TaskFilter filter = ref.watch(taskFilterProvider);
  final List<TaskItem> tasks = ref.watch(tasksControllerProvider);
  final DateTime now = ref.watch(nowProvider);

  final List<TaskItem> visible =
      tasks
          .where((t) => filter == TaskFilter.active ? !t.isDone : t.isDone)
          .toList()
        ..sort((a, b) {
          final DateTime? x = a.dueAt;
          final DateTime? y = b.dueAt;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return x.compareTo(y);
        });

  final Map<TaskGroup, List<TaskItem>> groups = {};
  for (final TaskItem task in visible) {
    groups.putIfAbsent(TaskGroup.of(task, now), () => []).add(task);
  }
  return {
    for (final TaskGroup group in TaskGroup.values)
      if (groups[group] != null) group: groups[group]!,
  };
});

/// Строка под заголовком: «2 на сегодня · 1 просрочена».
final tasksSummaryProvider = Provider<String>((ref) {
  final List<TaskItem> tasks = ref.watch(tasksControllerProvider);
  final DateTime now = ref.watch(nowProvider);
  final List<TaskItem> active = [
    for (final t in tasks)
      if (!t.isDone) t,
  ];

  if (tasks.isEmpty) return 'Задач пока нет';
  if (active.isEmpty) return 'Все задачи закрыты';

  final int overdue = active.where((t) => t.overdue(now)).length;
  final int today = active.where((t) => t.today(now)).length;
  return [
    if (overdue > 0)
      '$overdue ${_word(overdue, 'просрочена', 'просрочены', 'просрочено')}',
    if (today > 0) '$today на сегодня',
    if (overdue == 0 && today == 0)
      '${active.length} ${_word(active.length, 'задача', 'задачи', 'задач')}',
  ].join(' · ');
});

/// Предметы из загруженного расписания — подсказки при выборе предмета.
final taskSubjectsProvider = Provider<List<String>>((ref) {
  final ScheduleState? schedule = ref.watch(scheduleControllerProvider).value;
  if (schedule == null) return const [];
  final Set<String> subjects = {
    for (final ScheduleDay day in schedule.days)
      for (final Lesson lesson in day.lessons) lesson.title,
  };
  return subjects.toList()..sort();
});

String _word(int count, String one, String few, String many) {
  final int mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  return switch (count % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}
