import 'package:flutter/material.dart';

import '../../data/models/lesson.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import '../../widgets/segmented_list.dart';
import 'lesson_timing.dart';

/// Пара дня — пункт segmented-списка.
///
/// https://m3.material.io/components/lists — на compact-экранах вместо
/// карточек рекомендуется список (cards → Adaptive design), пункт с одним
/// действием открывает подробности. Слоты:
///   * leading — начало и конец пары (цифры моноширинные: время меняется,
///     typography → Tabular numbers);
///   * overline — тип занятия (и подгруппа, если показана только своя);
///   * headline — предмет;
///   * supporting — преподаватель и аудитория, у подгрупп по строке на каждую;
///     у ближайшей — «Начнётся через…», у идущей — остаток и прогресс.
///
/// Идущая пара — выбранный пункт (`secondaryContainer`, углы 16dp): выбор
/// передаётся не только цветом, но и текстом «Идёт сейчас».
///
/// Функция, а не виджет-обёртка: [SegmentedList] анимирует форму только у
/// прямых детей-[M3ListItem].
M3ListItem lessonSlotItem(
  BuildContext context, {
  required LessonSlot slot,
  required SlotStatus status,
  required VoidCallback onTap,
}) {
  final ColorScheme colors = context.colors;
  final bool isNow = status.progress != null;
  final String? title = slot.commonTitle;
  final Lesson single = slot.lessons.first;
  final bool oneRow = slot.lessons.length == 1;

  final List<String> overline = [
    for (final Lesson lesson in slot.distinctTypes) lesson.typeLabel,
    if (oneRow && single.subgroup != null) '${single.subgroup} подгруппа',
  ];

  const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  return M3ListItem(
    selected: isNow,
    onTap: onTap,
    leading: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slot.start,
          style: context.text.titleMedium!.copyWith(fontFeatures: tabular),
        ),
        Text(
          slot.end,
          style: context.text.bodySmall!.copyWith(fontFeatures: tabular),
        ),
      ],
    ),
    overline: Text(overline.join(' · ')),
    headline: Text(title ?? 'Занятия подгрупп'),
    supporting: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final Lesson lesson in slot.lessons)
          if (lessonDetailsLine(lesson, withTitle: title == null).isNotEmpty)
            Text(
              oneRow
                  ? [
                      ?lesson.teacher,
                      if (lesson.room != null) roomLabel(lesson.room!),
                    ].join(' · ')
                  : lessonDetailsLine(lesson, withTitle: title == null),
            ),
        if (status.startsIn != null)
          Text('Начнётся ${startsInLabel(status.startsIn!)}'),
        if (isNow) ...[
          Text(
            'Идёт сейчас · осталось ${status.progress!.minutesLeft} мин',
            style: TextStyle(fontFeatures: tabular),
          ),
          const SizedBox(height: AppSpacing.space100),
          // Индикатор внутри компонента: цвет содержимого пункта, без
          // трека (progress indicators → Accessibility).
          M3WavyLinearProgress(
            value: status.progress!.fraction,
            color: colors.onSecondaryContainer,
            showTrack: false,
            semanticsLabel: 'Прогресс пары',
          ),
        ],
      ],
    ),
  );
}

/// Пары дня сегментированным списком.
class LessonSlotList extends StatelessWidget {
  const LessonSlotList({
    super.key,
    required this.slots,
    required this.statuses,
    required this.onOpen,
  });

  final List<LessonSlot> slots;
  final List<SlotStatus> statuses;
  final void Function(LessonSlot slot, SlotStatus status) onOpen;

  @override
  Widget build(BuildContext context) {
    return SegmentedList(
      children: [
        for (int i = 0; i < slots.length; i++)
          lessonSlotItem(
            context,
            slot: slots[i],
            status: statuses[i],
            onTap: () => onOpen(slots[i], statuses[i]),
          ),
      ],
    );
  }
}
