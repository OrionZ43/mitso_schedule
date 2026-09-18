import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/task_item.dart';
import '../../state/mitso_providers.dart';
import '../../state/tasks_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/m3_checkbox.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import 'task_sheet.dart';

/// Задачи с предметом и сроком: разделы от просроченных к дальним, отдельная
/// вкладка выполненных.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<TaskGroup, List<TaskItem>> groups = ref.watch(
      groupedTasksProvider,
    );
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final String summary = ref.watch(tasksSummaryProvider);
    final DateTime now = ref.watch(nowProvider);
    final double margin = AppSpacing.screenMargin(context);

    return M3AppBarSettle(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverMediumFlexibleAppBar(title: 'Заметки', subtitle: summary),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            sliver: SliverList.list(
              children: [
                // Переключение вида списка — connected button group
                // (segmented button в M3 Expressive устарел).
                ConnectedButtonGroup<TaskFilter>(
                  values: TaskFilter.values,
                  labelOf: (filter) => filter.label,
                  selected: filter,
                  onSelected: ref.read(taskFilterProvider.notifier).select,
                ),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space200),
                    child: EmptyState(
                      title: filter == TaskFilter.active
                          ? 'Задач нет,\nможно отдыхать!'
                          : 'Выполненных задач нет',
                      description: filter == TaskFilter.active
                          ? 'Добавьте, что нужно сделать: к паре, к сессии '
                                'или просто на неделю.'
                          : 'Отмеченные задачи переедут сюда.',
                      withAccentDot: true,
                      illustrationSize: const Size(148, 132),
                    ),
                  )
                else
                  for (final MapEntry<TaskGroup, List<TaskItem>> group
                      in groups.entries) ...[
                    SectionHeader(group.key.title),
                    SegmentedList(
                      children: [
                        for (final TaskItem task in group.value)
                          _taskItem(
                            context,
                            task: task,
                            now: now,
                            onToggle: () => ref
                                .read(tasksControllerProvider.notifier)
                                .toggle(task.id),
                            onEdit: () => showTaskSheet(context, task: task),
                          ),
                      ],
                    ),
                  ],
                // Место под medium FAB.
                const SizedBox(
                  height: AppSpacing.space800 + AppSpacing.space800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Задача — пункт списка с ведущим чекбоксом (lists → Anatomy, «Leading
  /// checkbox»). Чекбокс и нажатие по строке делают разное: отметить и
  /// открыть правку, поэтому у чекбокса своя зона нажатия.
  M3ListItem _taskItem(
    BuildContext context, {
    required TaskItem task,
    required DateTime now,
    required VoidCallback onToggle,
    required VoidCallback onEdit,
  }) {
    final bool overdue = task.overdue(now);
    final String? due = dueLabel(task.dueAt, now);
    final String details = [?task.subject, ?due].join(' · ');

    return M3ListItem(
      leading: M3Checkbox(value: task.isDone, onChanged: (_) => onToggle()),
      headline: Text(task.text),
      supporting: details.isEmpty
          ? null
          : Text(
              details,
              style: overdue ? TextStyle(color: context.colors.error) : null,
            ),
      trailing: overdue
          ? Icon(Symbols.alarm, color: context.colors.error)
          : null,
      onTap: onEdit,
      semanticsLabel: [
        task.text,
        if (details.isNotEmpty) details,
        if (overdue) 'просрочено',
        task.isDone ? 'выполнено' : 'не выполнено',
      ].join(', '),
    );
  }
}

/// Срок словами: «Сегодня», «Завтра», «Вчера», «22 сентября»,
/// «22 сентября 2027».
String? dueLabel(DateTime? due, DateTime now) {
  if (due == null) return null;
  final int days = DateUtils.dateOnly(
    due,
  ).difference(DateUtils.dateOnly(now)).inDays;
  return switch (days) {
    0 => 'Сегодня',
    1 => 'Завтра',
    -1 => 'Вчера',
    _ when due.year == now.year => DateFormat('d MMMM', 'ru').format(due),
    _ => DateFormat('d MMMM y', 'ru').format(due),
  };
}
