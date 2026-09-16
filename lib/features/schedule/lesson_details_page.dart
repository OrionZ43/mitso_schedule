import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/lesson.dart';
import '../../theme/app_typography.dart';
import '../../widgets/lesson_card.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import '../../widgets/segmented_list.dart';
import '../../widgets/status_badge.dart';

/// Подробности пары: преподаватели и аудитории по подгруппам и ближайшие
/// занятия по тому же предмету в загруженных неделях.
///
/// Открывается из карточки паттерном container transform; `close` с датой
/// закрывает страницу и переключает расписание на этот день.
class LessonDetailsPage extends StatelessWidget {
  const LessonDetailsPage({
    super.key,
    required this.slot,
    required this.day,
    required this.days,
    required this.status,
    required this.subgroup,
    required this.close,
  });

  final LessonSlot slot;
  final ScheduleDay day;

  /// Все загруженные дни — для «Дальше по предмету».
  final List<ScheduleDay> days;

  final SlotStatus status;

  /// Своя подгруппа из настроек.
  final int? subgroup;

  final void Function({DateTime? returnValue}) close;

  /// Сколько следующих занятий показывать.
  static const int upcomingLimit = 6;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String? title = slot.commonTitle;
    final String date = DateFormat('d MMMM', 'ru').format(day.date);
    final List<_Occurrence> upcoming = _upcoming();
    final bool several = slot.lessons.length > 1;

    return Scaffold(
      appBar: M3SmallAppBar(
        title: day.title,
        subtitle: date,
        leading: M3IconButton(
          onPressed: close,
          icon: const Icon(Symbols.arrow_back),
          color: M3IconButtonColor.standard,
          tooltip: 'Назад',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final Lesson lesson in slot.distinctTypes)
                      LessonTypeBadge(
                        type: lesson.type,
                        label: lesson.typeLabel,
                      ),
                    if (!several && slot.lessons.first.subgroup != null)
                      SubgroupBadge(number: slot.lessons.first.subgroup!),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    title ?? 'Занятия подгрупп',
                    style: context.text.headlineSmall!.emphasized,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${slot.start} — ${slot.end}',
                  style: context.text.titleMedium!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (status.progress != null)
            _NowPanel(progress: status.progress!)
          else if (status.startsIn != null)
            _Hint(
              icon: Symbols.schedule,
              text: 'Начнётся ${startsInLabel(status.startsIn!)}',
              color: colors.primary,
            )
          else if (status.timing == SlotTiming.past)
            _Hint(
              icon: Symbols.check_circle,
              text: 'Пара закончилась',
              color: colors.onSurfaceVariant,
            ),
          _SectionTitle(several ? 'Подгруппы' : 'Преподаватель и аудитория'),
          SegmentedList(
            children: [
              for (final Lesson lesson in slot.lessons)
                Semantics(
                  label: subgroupSemantics(lesson, withTitle: title == null),
                  excludeSemantics: true,
                  child: ListTile(
                    leading: SubgroupNumber(number: lesson.subgroup),
                    title: Text(lesson.teacher ?? 'Преподаватель не указан'),
                    subtitle: Text(
                      [
                        if (title == null) lesson.title,
                        lesson.room == null
                            ? 'Аудитория не указана'
                            : roomLabel(lesson.room!),
                      ].join(' · '),
                    ),
                  ),
                ),
            ],
          ),
          _SectionTitle('Дальше по предмету'),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'В загруженных неделях больше нет.',
                style: context.text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            SegmentedList(
              children: [
                for (final _Occurrence o in upcoming)
                  ListTile(
                    leading: const Icon(Symbols.event),
                    title: Text(
                      '${o.day.shortName}, '
                      '${DateFormat('d MMMM', 'ru').format(o.day.date)} · '
                      '${o.slot.start}',
                    ),
                    subtitle: Text(
                      [
                        for (final Lesson l in o.slot.distinctTypes)
                          l.typeLabel,
                        if (o.slot.lessons.length == 1)
                          ?o.slot.lessons.first.teacher,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => close(returnValue: o.day.date),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Следующие пары с тем же названием после этой.
  List<_Occurrence> _upcoming() {
    final Set<String> titles = {for (final l in slot.lessons) l.title};
    final List<_Occurrence> result = [];
    bool afterThis = false;

    for (final ScheduleDay d in days) {
      for (final LessonSlot s in d.slots(subgroup: subgroup)) {
        if (DateUtils.isSameDay(d.date, day.date) && s.start == slot.start) {
          afterThis = true;
          continue;
        }
        if (!afterThis) continue;
        if (s.lessons.any((l) => titles.contains(l.title))) {
          result.add(_Occurrence(d, s));
          if (result.length == upcomingLimit) return result;
        }
      }
    }
    return result;
  }
}

class _Occurrence {
  const _Occurrence(this.day, this.slot);

  final ScheduleDay day;
  final LessonSlot slot;
}

class _NowPanel extends StatelessWidget {
  const _NowPanel({required this.progress});

  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(SegmentedList.outerCorner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Идёт сейчас · осталось ${progress.minutesLeft} мин',
            style: context.text.labelLarge!.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 10),
          M3WavyLinearProgress(
            value: progress.fraction,
            semanticsLabel: 'Прогресс пары',
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.labelLarge!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 28, 8, 12),
      child: Text(
        title,
        style: context.text.titleSmall!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
