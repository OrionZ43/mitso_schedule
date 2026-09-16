import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/task_item.dart';

/// Вкладка сегментированной кнопки: активные или выполненные.
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
  @override
  // Задачи — локальные записи пользователя, без стартовых примеров.
  List<TaskItem> build() => const [];

  void toggle(String id) {
    state = [
      for (final task in state)
        task.id == id ? task.copyWith(isDone: !task.isDone) : task,
    ];
  }

  /// Добавляет пустую задачу и возвращает список к вкладке «Активные».
  void add() {
    ref.read(taskFilterProvider.notifier).select(TaskFilter.active);
    state = [
      TaskItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: 'Новая задача',
        subject: 'Без предмета',
        due: 'Без срока',
      ),
      ...state,
    ];
  }
}

/// Задачи, видимые при текущем фильтре.
final visibleTasksProvider = Provider<List<TaskItem>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final tasks = ref.watch(tasksControllerProvider);
  return tasks
      .where((t) => filter == TaskFilter.active ? !t.isDone : t.isDone)
      .toList();
});

/// Строка под заголовком: `3 активных дедлайна · 1 закрыто`.
final tasksSummaryProvider = Provider<String>((ref) {
  final tasks = ref.watch(tasksControllerProvider);
  final active = tasks.where((t) => !t.isDone).length;
  if (active == 0) return 'Все задачи закрыты';
  return '$active активных дедлайна · ${tasks.length - active} закрыто';
});
