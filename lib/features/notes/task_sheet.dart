import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/task_item.dart';
import '../../state/mitso_providers.dart';
import '../../state/tasks_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_bottom_sheet.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_filter_chip.dart';

/// Лист новой задачи или правки существующей.
Future<void> showTaskSheet(BuildContext context, {TaskItem? task}) {
  return showM3ModalBottomSheet<void>(
    context: context,
    builder: (context, scrollController) =>
        _TaskSheet(scrollController: scrollController, task: task),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({required this.scrollController, this.task});

  final ScrollController scrollController;

  /// Правка: `null` — новая задача.
  final TaskItem? task;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.task?.text ?? '',
  );
  late String? _subject = widget.task?.subject;
  late DateTime? _dueAt = widget.task?.dueAt;

  bool get _editing => widget.task != null;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final String text = _text.text.trim();
    if (text.isEmpty) return;
    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );
    if (_editing) {
      controller.update(
        widget.task!.id,
        text: text,
        subject: _subject,
        dueAt: _dueAt,
      );
    } else {
      controller.add(text: text, subject: _subject, dueAt: _dueAt);
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final DateTime now = ref.read(clockProvider)();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Срок задачи',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final DateTime now = ref.read(clockProvider)();
    final List<String> subjects = ref.watch(taskSubjectsProvider);

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space200,
        0,
        AppSpacing.space200,
        AppSpacing.space300,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            _editing ? 'Задача' : 'Новая задача',
            style: context.text.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.space200),
        TextField(
          controller: _text,
          autofocus: !_editing,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Что сделать',
            hintText: 'Например: сдать лабораторную',
            border: OutlineInputBorder(),
            // Метка сразу в вырезе рамки: при автофокусе она иначе
            // анимируется наверх прямо во время выезда листа и мигает.
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),

        const SizedBox(height: AppSpacing.space300),
        Text('Срок', style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.space100),
        Wrap(
          spacing: AppSpacing.space100,
          runSpacing: AppSpacing.space100,
          children: [
            _DueChip(
              label: 'Сегодня',
              selected: _isSameDay(_dueAt, now),
              onSelected: () => setState(() => _dueAt = _dateOnly(now)),
            ),
            _DueChip(
              label: 'Завтра',
              selected: _isSameDay(_dueAt, now.add(const Duration(days: 1))),
              onSelected: () => setState(
                () => _dueAt = _dateOnly(now.add(const Duration(days: 1))),
              ),
            ),
            _DueChip(
              label: _dueAt == null || _isWithinTwoDays(_dueAt!, now)
                  ? 'Выбрать дату'
                  : DateFormat('d MMMM', 'ru').format(_dueAt!),
              selected: _dueAt != null && !_isWithinTwoDays(_dueAt!, now),
              icon: Symbols.event,
              onSelected: _pickDate,
            ),
            if (_dueAt != null)
              _DueChip(
                label: 'Без срока',
                selected: false,
                icon: Symbols.close,
                onSelected: () => setState(() => _dueAt = null),
              ),
          ],
        ),

        if (subjects.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space300),
          Text('Предмет', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.space100),
          Wrap(
            spacing: AppSpacing.space100,
            runSpacing: AppSpacing.space100,
            children: [
              for (final String subject in subjects)
                M3FilterChip(
                  label: Text(subject),
                  selected: subject == _subject,
                  onSelected: (selected) =>
                      setState(() => _subject = selected ? subject : null),
                ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.space300),
        Row(
          children: [
            if (_editing)
              Expanded(
                child: M3Button(
                  onPressed: () {
                    ref
                        .read(tasksControllerProvider.notifier)
                        .remove(widget.task!.id);
                    Navigator.of(context).pop();
                  },
                  color: M3ButtonColor.text,
                  size: M3ButtonSize.medium,
                  child: Text('Удалить', style: TextStyle(color: colors.error)),
                ),
              )
            else
              Expanded(
                child: M3Button(
                  onPressed: () => Navigator.of(context).pop(),
                  color: M3ButtonColor.outlined,
                  size: M3ButtonSize.medium,
                  child: const Text('Отмена'),
                ),
              ),
            const SizedBox(width: AppSpacing.space150),
            Expanded(
              child: ListenableBuilder(
                listenable: _text,
                builder: (context, _) => M3Button(
                  onPressed: _text.text.trim().isEmpty ? null : _save,
                  size: M3ButtonSize.medium,
                  child: Text(_editing ? 'Сохранить' : 'Добавить'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  /// Сегодня или завтра — эти дни выбираются отдельными чипами.
  static bool _isWithinTwoDays(DateTime date, DateTime now) =>
      _isSameDay(date, now) ||
      _isSameDay(date, now.add(const Duration(days: 1)));
}

/// Вариант срока — filter chip с одиночным выбором.
class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return M3FilterChip(
      label: Text(label),
      selected: selected,
      leading: icon == null ? null : Icon(icon, size: 18),
      onSelected: (_) => onSelected(),
    );
  }
}
