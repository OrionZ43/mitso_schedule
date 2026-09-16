import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/lesson.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import 'lesson_timing.dart';

/// Подробности пары: преподаватели и аудитории по подгруппам и ближайшие
/// занятия по тому же предмету в загруженных неделях.
///
/// Возвращает дату, если выбрано следующее занятие: расписание переключится
/// на этот день.
class LessonDetailsPage extends StatelessWidget {
  const LessonDetailsPage({
    super.key,
    required this.slot,
    required this.day,
    required this.days,
    required this.status,
    required this.subgroup,
  });

  final LessonSlot slot;
  final ScheduleDay day;

  /// Все загруженные дни — для «Дальше по предмету».
  final List<ScheduleDay> days;

  final SlotStatus status;

  /// Своя подгруппа из настроек.
  final int? subgroup;

  /// Сколько следующих занятий показывать.
  static const int upcomingLimit = 6;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String? title = slot.commonTitle;
    final String date = DateFormat('d MMMM', 'ru').format(day.date);
    final List<(ScheduleDay, LessonSlot)> upcoming = _upcoming();
    final bool several = slot.lessons.length > 1;
    final double margin = AppSpacing.screenMargin(context);

    final List<String> overline = [
      for (final Lesson lesson in slot.distinctTypes) lesson.typeLabel,
      if (!several && slot.lessons.first.subgroup != null)
        '${slot.lessons.first.subgroup} подгруппа',
    ];

    return Scaffold(
      appBar: M3SmallAppBar(
        title: day.title,
        subtitle: date,
        leading: M3IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Symbols.arrow_back),
          color: M3IconButtonColor.standard,
          tooltip: 'Назад',
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          margin,
          AppSpacing.space100,
          margin,
          AppSpacing.space800,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space200,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overline.join(' · '),
                  style: context.text.labelLarge!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space100),
                Semantics(
                  header: true,
                  child: Text(
                    title ?? 'Занятия подгрупп',
                    style: context.text.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.space100),
                Text(
                  '${slot.start} — ${slot.end}',
                  style: context.text.titleMedium!.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (status.progress != null)
                  _NowSection(progress: status.progress!)
                else if (status.startsIn != null)
                  _Status('Начнётся ${startsInLabel(status.startsIn!)}')
                else if (status.timing == SlotTiming.past)
                  const _Status('Пара закончилась'),
              ],
            ),
          ),
          SectionHeader(several ? 'Подгруппы' : 'Преподаватель и аудитория'),
          SegmentedList(
            children: [
              for (final Lesson lesson in slot.lessons)
                M3ListItem(
                  leading: lesson.subgroup == null
                      ? const Icon(Symbols.person)
                      : _SubgroupAvatar(number: lesson.subgroup!),
                  overline: title == null ? Text(lesson.title) : null,
                  headline: Text(lesson.teacher ?? 'Преподаватель не указан'),
                  supporting: Text(
                    lesson.room == null
                        ? 'Аудитория не указана'
                        : roomLabel(lesson.room!),
                  ),
                  semanticsLabel: lessonDetailsLine(
                    lesson,
                    withTitle: title == null,
                  ),
                ),
            ],
          ),
          const SectionHeader('Дальше по предмету'),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space200,
              ),
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
                for (final (ScheduleDay d, LessonSlot s) in upcoming)
                  M3ListItem(
                    leading: const Icon(Symbols.event),
                    headline: Text(
                      '${d.shortName}, '
                      '${DateFormat('d MMMM', 'ru').format(d.date)} · '
                      '${s.start}',
                    ),
                    supporting: Text(
                      [
                        for (final Lesson l in s.distinctTypes) l.typeLabel,
                        if (s.lessons.length == 1) ?s.lessons.first.teacher,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => Navigator.of(context).pop(d.date),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Следующие пары с тем же названием после этой.
  List<(ScheduleDay, LessonSlot)> _upcoming() {
    final Set<String> titles = {for (final l in slot.lessons) l.title};
    final List<(ScheduleDay, LessonSlot)> result = [];
    bool afterThis = false;

    for (final ScheduleDay d in days) {
      for (final LessonSlot s in d.slots(subgroup: subgroup)) {
        if (DateUtils.isSameDay(d.date, day.date) && s.start == slot.start) {
          afterThis = true;
          continue;
        }
        if (!afterThis) continue;
        if (s.lessons.any((l) => titles.contains(l.title))) {
          result.add((d, s));
          if (result.length == upcomingLimit) return result;
        }
      }
    }
    return result;
  }
}

/// Номер подгруппы — аватар пункта списка (`ListTokens.ItemLeadingAvatar*`:
/// 40dp, primaryContainer / onPrimaryContainer, titleMedium).
class _SubgroupAvatar extends StatelessWidget {
  const _SubgroupAvatar({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: context.text.titleMedium!.copyWith(
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Идущая пара: остаток и прогресс. Индикатор на поверхности — цвета по
/// умолчанию (primary на secondaryContainer) со stop indicator.
class _NowSection extends StatelessWidget {
  const _NowSection({required this.progress});

  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Status('Идёт сейчас · осталось ${progress.minutesLeft} мин'),
        const SizedBox(height: AppSpacing.space150),
        M3WavyLinearProgress(
          value: progress.fraction,
          semanticsLabel: 'Прогресс пары',
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space200),
      child: Text(
        text,
        style: context.text.labelLarge!.copyWith(
          color: context.colors.primary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
