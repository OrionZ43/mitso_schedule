import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/lesson.dart';
import '../../state/schedule_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_filter_chip.dart';
import '../../widgets/m3_search.dart';
import '../../widgets/segmented_list.dart';
import 'lesson_timing.dart';

/// Поиск по загруженному расписанию — кнопка-иконка в app bar.
///
/// https://m3.material.io/components/search — поиск по содержимому одного
/// экрана: по нажатию открывается contained full-screen поиск
/// ([showM3Search]). Фильтр-чипы сужают поиск (Guidelines → Search
/// suggestions & results), результаты — пункты списка, группы разделены
/// зазорами, без разделителей. Запрос сохраняется между открытиями.
class ScheduleSearchButton extends StatefulWidget {
  const ScheduleSearchButton({super.key, required this.days});

  final List<ScheduleDay> days;

  @override
  State<ScheduleSearchButton> createState() => _ScheduleSearchButtonState();
}

class _ScheduleSearchButtonState extends State<ScheduleSearchButton> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return M3IconButton(
      onPressed: () => showM3Search(
        context: context,
        // Короткая подсказка: гайдлайн — «Search your messages».
        hintText: 'Поиск по расписанию',
        controller: _query,
        contentBuilder: (context, query) =>
            _SearchContent(days: widget.days, query: query),
      ),
      icon: const Icon(Symbols.search),
      color: M3IconButtonColor.standard,
      tooltip: 'Поиск по расписанию',
    );
  }
}

class _SearchContent extends ConsumerStatefulWidget {
  const _SearchContent({required this.days, required this.query});

  final List<ScheduleDay> days;
  final String query;

  @override
  ConsumerState<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends ConsumerState<_SearchContent> {
  String? _announced;

  List<(ScheduleDay, Lesson)> _matches(ScheduleSearchField field) {
    final String query = widget.query.trim().toLowerCase();
    if (query.isEmpty) return const [];

    String? valueOf(Lesson lesson) => switch (field) {
      ScheduleSearchField.subject => lesson.title,
      ScheduleSearchField.teacher => lesson.teacher,
      ScheduleSearchField.room => lesson.room,
    };

    // Подгруппы одной пары с тем же значением — одна строка результата.
    final Set<String> seen = {};
    return [
      for (final ScheduleDay day in widget.days)
        for (final Lesson lesson in day.lessons)
          if ((valueOf(lesson)?.toLowerCase().contains(query) ?? false) &&
              seen.add(
                '${day.date}|${lesson.start}|${lesson.title}|${valueOf(lesson)}',
              ))
            (day, lesson),
    ];
  }

  /// Озвучить число результатов, когда оно меняется (Search → Accessibility).
  void _announce(String message) {
    if (message == _announced) return;
    _announced = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) M3SearchScope.of(context).announce(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScheduleSearchField field = ref.watch(searchFieldProvider);
    final List<(ScheduleDay, Lesson)> matches = _matches(field);
    final bool hasQuery = widget.query.trim().isNotEmpty;

    if (hasQuery) {
      _announce(
        matches.isEmpty ? 'Ничего не найдено' : 'Найдено: ${matches.length}',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space200,
        0,
        AppSpacing.space200,
        AppSpacing.space300,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.space100,
          runSpacing: AppSpacing.space100,
          children: [
            for (final ScheduleSearchField value in ScheduleSearchField.values)
              M3FilterChip(
                label: Text(value.label),
                selected: field == value,
                onSelected: (_) =>
                    ref.read(searchFieldProvider.notifier).select(value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space200),
        if (!hasQuery)
          _Hint('Ищет по неделям, загруженным с сайта.')
        else if (matches.isEmpty)
          _Hint('Ничего не найдено.')
        else
          SegmentedList(
            children: [
              for (final (ScheduleDay day, Lesson lesson) in matches)
                M3ListItem(
                  leading: const Icon(Symbols.event),
                  headline: Text(lesson.title),
                  supporting: Text(
                    [
                      '${day.shortName}, '
                          '${DateFormat('d MMMM', 'ru').format(day.date)} · '
                          '${lesson.start}',
                      ?lesson.teacher,
                      if (lesson.room != null) roomLabel(lesson.room!),
                    ].join(' · '),
                  ),
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).select(day.date);
                    M3SearchScope.of(context).close();
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space200),
      child: Text(
        text,
        style: context.text.bodyMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
