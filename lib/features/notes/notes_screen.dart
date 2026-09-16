import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/task_item.dart';
import '../../state/tasks_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/m3_checkbox.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/segmented_list.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> tasks = ref.watch(visibleTasksProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final String summary = ref.watch(tasksSummaryProvider);
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
                const SizedBox(height: AppSpacing.space200),
                if (tasks.isEmpty)
                  const EmptyState(
                    title: 'Дедлайнов пока нет,\nможно отдыхать!',
                    description:
                        'Новая задача добавится сюда — или прилетит из бота '
                        'вместе с расписанием.',
                    withAccentDot: true,
                    illustrationSize: Size(148, 132),
                  )
                else
                  SegmentedList(
                    children: [
                      for (final TaskItem task in tasks)
                        _taskItem(
                          context,
                          task,
                          () => ref
                              .read(tasksControllerProvider.notifier)
                              .toggle(task.id),
                        ),
                    ],
                  ),
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
  /// checkbox»). Отметить можно нажатием по всей строке, не только по
  /// чекбоксу (checkbox → Accessibility). Цвет подписи от отметки не меняется
  /// (checkbox → Specs, Adjacent text label color): выполненная задача просто
  /// переходит в фильтр «Выполненные».
  M3ListItem _taskItem(
    BuildContext context,
    TaskItem task,
    VoidCallback onToggle,
  ) {
    final bool urgent = task.isUrgent && !task.isDone;
    return M3ListItem(
      leading: ExcludeSemantics(
        child: M3Checkbox(value: task.isDone, onChanged: (_) => onToggle()),
      ),
      headline: Text(task.text),
      supporting: Text('${task.subject} · ${task.due}'),
      trailing: urgent
          ? Icon(Symbols.alarm, color: context.colors.error)
          : null,
      onTap: onToggle,
      semanticsLabel: [
        task.text,
        task.subject,
        task.due,
        if (urgent) 'срочно',
        task.isDone ? 'выполнено' : 'не выполнено',
      ].join(', '),
    );
  }
}
