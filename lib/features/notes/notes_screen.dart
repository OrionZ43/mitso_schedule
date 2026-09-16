import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/task_item.dart';
import '../../state/tasks_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/empty_state.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> tasks = ref.watch(visibleTasksProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final String summary = ref.watch(tasksSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: ref.read(tasksControllerProvider.notifier).add,
        tooltip: 'Добавить задачу',
        child: const Icon(Symbols.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Заметки', style: context.text.headlineMedium!.emphasized),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: context.text.labelLarge!.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            // Connected button group: segmented button в M3 Expressive устарел.
            child: ConnectedButtonGroup<TaskFilter>(
              values: TaskFilter.values,
              labelOf: (filter) => filter.label,
              selected: filter,
              onSelected: ref.read(taskFilterProvider.notifier).select,
            ),
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EmptyState(
                title: 'Дедлайнов пока нет,\nможно отдыхать!',
                description:
                    'Новая задача добавится сюда — или прилетит из бота вместе с расписанием.',
                withAccentDot: true,
                illustrationSize: Size(148, 132),
              ),
            )
          else
            for (final TaskItem task in tasks)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TaskCard(
                  task: task,
                  onToggle: () => ref
                      .read(tasksControllerProvider.notifier)
                      .toggle(task.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onToggle});

  final TaskItem task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    // Отметка выполнения — затухание и зачёркивание, то есть effects.
    return AnimatedOpacity(
      opacity: task.isDone ? 0.6 : 1.0,
      duration: AppMotion.defaultEffects.duration,
      curve: AppMotion.defaultEffects.curve,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          // Outlined card: фон surface, обводка outlineVariant.
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: AppShapes.all(AppShapes.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox сам держит зону нажатия 48x48 при стандартном
            // materialTapTargetSize, отрицательные отступы возвращают
            // визуальную рамку на место.
            Transform.translate(
              offset: const Offset(-12, -11),
              child: Checkbox(
                value: task.isDone,
                onChanged: (_) => onToggle(),
                semanticLabel: task.text,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.defaultEffects.duration,
                    curve: AppMotion.defaultEffects.curve,
                    style: context.text.titleMedium!.copyWith(
                      height: 1.5,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    child: Text(task.text),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TaskChip(
                        label: task.subject,
                        background: colors.primaryContainer,
                        foreground: colors.onPrimaryContainer,
                      ),
                      _TaskChip(
                        label: task.due,
                        background: task.isUrgent && !task.isDone
                            ? colors.errorContainer
                            : colors.surfaceContainerHigh,
                        foreground: task.isUrgent && !task.isDone
                            ? colors.onErrorContainer
                            : colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.all(AppShapes.chip),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: context.text.labelMedium!.copyWith(color: foreground),
        ),
      ),
    );
  }
}
