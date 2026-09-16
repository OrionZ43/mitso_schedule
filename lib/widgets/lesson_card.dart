import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models/lesson.dart';
import '../theme/app_shapes.dart';
import '../theme/app_transitions.dart';
import '../theme/app_typography.dart';
import 'm3_wavy_linear_progress.dart';
import 'status_badge.dart';

/// Где пара относительно текущего момента.
enum SlotTiming {
  /// Уже закончилась — карточка приглушена.
  past,

  /// Идёт сейчас — залитая `primary` карточка с прогрессом.
  now,

  /// Ещё впереди.
  upcoming,
}

/// Карточка пары.
///
/// Одна карточка на время: если у подгрупп в это время разные преподаватели
/// и аудитории, они идут строками внутри карточки, а не отдельными парами.
///
/// Обычная — outlined card радиусом 28dp; текущая — залитая `primary`
/// радиусом 32dp с меткой «Сейчас идёт» и волнистой шкалой прогресса;
/// прошедшая — тональная `surfaceContainerLow` без обводки.
///
/// Нажатие открывает [details] паттерном container transform — карточка
/// разворачивается в страницу (MDC Motion.md: «card → details page»).
/// Используется `OpenContainer` из package:animations — реализация паттерна
/// от команды Flutter; длительность — из `MaterialContainerTransform`.
class LessonCard<T> extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.slot,
    this.timing = SlotTiming.upcoming,
    this.progress,
    this.startsInMinutes,
    this.details,
    this.onClosed,
  });

  final LessonSlot slot;
  final SlotTiming timing;

  /// Прогресс, если пара идёт прямо сейчас.
  final LessonProgress? progress;

  /// Через сколько минут начнётся — только у ближайшей сегодняшней пары.
  final int? startsInMinutes;

  /// Страница подробностей; `close` закрывает её с результатом.
  final Widget Function(
    BuildContext context,
    void Function({T? returnValue}) close,
  )?
  details;

  /// Результат страницы подробностей после завершения обратного перехода.
  final void Function(T? result)? onClosed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool isNow = timing == SlotTiming.now && progress != null;

    final Color container = switch (timing) {
      _ when isNow => colors.primary,
      SlotTiming.past => colors.surfaceContainerLow,
      _ => colors.surface,
    };
    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: AppShapes.all(
        isNow ? AppShapes.cardEmphasized : AppShapes.card,
      ),
      // Outlined card по card/tokens.xml: фон surface, обводка outlineVariant.
      side: timing == SlotTiming.upcoming && !isNow
          ? BorderSide(color: colors.outlineVariant)
          : BorderSide.none,
    );

    Widget content(VoidCallback? open) => Semantics(
      container: true,
      label: isNow ? 'Текущая пара' : null,
      child: InkWell(
        onTap: open,
        child: _CardContent(
          slot: slot,
          isNow: isNow,
          past: timing == SlotTiming.past,
          progress: progress,
          startsInMinutes: startsInMinutes,
        ),
      ),
    );

    if (details == null) {
      return Material(
        color: container,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content(null),
      );
    }

    return OpenContainer<T>(
      transitionDuration: AppTransitions.containerTransformDuration,
      closedColor: container,
      closedShape: shape,
      closedElevation: isNow ? 3 : 0,
      openColor: colors.surface,
      openElevation: 0,
      middleColor: colors.surface,
      // Нажатие обрабатывает InkWell внутри — с ripple.
      tappable: false,
      onClosed: onClosed,
      closedBuilder: (context, open) => content(open),
      openBuilder: (context, close) => details!(context, close),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.slot,
    required this.isNow,
    required this.past,
    required this.progress,
    required this.startsInMinutes,
  });

  final LessonSlot slot;
  final bool isNow;
  final bool past;
  final LessonProgress? progress;
  final int? startsInMinutes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color foreground = isNow ? colors.onPrimary : colors.onSurface;
    final Color secondary = isNow
        ? colors.onPrimary.withValues(alpha: 0.86)
        : colors.onSurfaceVariant;

    final Lesson single = slot.lessons.first;
    final String? title = slot.commonTitle;
    final bool oneRow = slot.lessons.length == 1;

    return Padding(
      padding: EdgeInsets.all(isNow ? 22 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // minWidth, а не фиксированная ширина: при крупном шрифте
              // время не должно обрезаться.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.start,
                      style: context.text.titleMedium!.copyWith(
                        color: past ? colors.onSurfaceVariant : foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.end,
                      style: context.text.bodySmall!.copyWith(
                        color: isNow
                            ? colors.onPrimary.withValues(alpha: 0.78)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                            onPrimarySurface: isNow,
                          ),
                        // Одна строка с номером — показана только своя
                        // подгруппа.
                        if (oneRow && single.subgroup != null)
                          SubgroupBadge(
                            number: single.subgroup!,
                            onPrimarySurface: isNow,
                          ),
                      ],
                    ),
                    if (title != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        title,
                        style: context.text.titleMedium!.emphasized.copyWith(
                          height: 1.5,
                          color: past ? colors.onSurfaceVariant : foreground,
                        ),
                      ),
                    ],
                    if (oneRow) ...[
                      if (single.teacher != null) ...[
                        const SizedBox(height: 10),
                        _MetaRow(
                          icon: Symbols.person,
                          text: single.teacher!,
                          color: secondary,
                        ),
                      ],
                      if (single.room != null) ...[
                        const SizedBox(height: 4),
                        _MetaRow(
                          icon: Symbols.door_front,
                          text: roomLabel(single.room!),
                          color: secondary,
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 12),
                      _SubgroupRows(
                        slot: slot,
                        isNow: isNow,
                        past: past,
                        showTitles: title == null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isNow) ...[
            const SizedBox(height: 18),
            _NowSection(progress: progress!),
          ] else if (startsInMinutes != null) ...[
            const SizedBox(height: 14),
            _StartsIn(minutes: startsInMinutes!),
          ],
        ],
      ),
    );
  }
}

/// Строки подгрупп внутри карточки — segmented-список в миниатюре:
/// крайние углы 16dp, стыки 4dp, зазор 2dp, как у [SegmentedList].
class _SubgroupRows extends StatelessWidget {
  const _SubgroupRows({
    required this.slot,
    required this.isNow,
    required this.past,
    required this.showTitles,
  });

  final LessonSlot slot;
  final bool isNow;
  final bool past;

  /// У подгрупп разные предметы — название в каждой строке.
  final bool showTitles;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color rowColor = isNow
        ? colors.onPrimary.withValues(alpha: 0.14)
        : past
        ? colors.surfaceContainerHigh
        : colors.surfaceContainer;
    final Color foreground = isNow ? colors.onPrimary : colors.onSurface;
    final Color secondary = isNow
        ? colors.onPrimary.withValues(alpha: 0.86)
        : colors.onSurfaceVariant;
    final int count = slot.lessons.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          Semantics(
            container: true,
            label: subgroupSemantics(slot.lessons[i], withTitle: showTitles),
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    i == 0 ? AppShapes.large : AppShapes.extraSmall,
                  ),
                  bottom: Radius.circular(
                    i == count - 1 ? AppShapes.large : AppShapes.extraSmall,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubgroupNumber(
                    number: slot.lessons[i].subgroup,
                    onPrimarySurface: isNow,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showTitles)
                          Text(
                            slot.lessons[i].title,
                            style: context.text.titleSmall!.emphasized.copyWith(
                              color: foreground,
                            ),
                          ),
                        Text(
                          slot.lessons[i].teacher ?? 'Преподаватель не указан',
                          style: context.text.bodyMedium!.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (slot.lessons[i].room != null)
                          Text(
                            roomLabel(slot.lessons[i].room!),
                            style: context.text.bodySmall!.copyWith(
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Подпись строки подгруппы для TalkBack.
String subgroupSemantics(Lesson lesson, {bool withTitle = false}) => [
  if (lesson.subgroup != null) '${lesson.subgroup} подгруппа',
  if (withTitle) lesson.title,
  ?lesson.teacher,
  if (lesson.room != null) roomLabel(lesson.room!),
].join(', ');

/// Номер подгруппы в круге; без номера — значок человека.
class SubgroupNumber extends StatelessWidget {
  const SubgroupNumber({
    super.key,
    required this.number,
    this.onPrimarySurface = false,
  });

  final int? number;
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color foreground = onPrimarySurface
        ? colors.onPrimary
        : colors.onSecondaryContainer;
    final double size = MediaQuery.textScalerOf(context).scale(28);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onPrimarySurface
            ? colors.onPrimary.withValues(alpha: 0.22)
            : colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: number == null
          ? Icon(Symbols.person, size: 18, color: foreground)
          : Text(
              '$number',
              style: context.text.labelLarge!.emphasized.copyWith(
                color: foreground,
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// «Начнётся через 25 мин» у ближайшей сегодняшней пары.
class _StartsIn extends StatelessWidget {
  const _StartsIn({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final Color color = context.colors.primary;
    return Row(
      children: [
        Icon(Symbols.schedule, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Начнётся ${startsInLabel(minutes)}',
            style: context.text.labelLarge!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// `через 25 мин`, `через 1 ч`, `через 2 ч 5 мин`.
String startsInLabel(int minutes) {
  if (minutes < 60) return 'через $minutes мин';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? 'через $hours ч' : 'через $hours ч $rest мин';
}

/// Блок текущей пары: метка с пульсирующей точкой, остаток и шкала прогресса.
class _NowSection extends StatelessWidget {
  const _NowSection({required this.progress});

  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, а не Row: при крупном системном шрифте метка и остаток
        // переносятся на вторую строку вместо переполнения.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(),
                const SizedBox(width: 7),
                Text(
                  'СЕЙЧАС ИДЁТ',
                  style: context.text.labelMedium!.emphasized.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'осталось ${progress.minutesLeft} мин',
              style: context.text.labelMedium!.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Карточка залита primary, поэтому токенные цвета шкалы (primary на
        // secondaryContainer) здесь не читаются — берём onPrimary, как в макете.
        M3WavyLinearProgress(
          value: progress.fraction,
          color: colors.onPrimary,
          trackColor: colors.onPrimary.withValues(alpha: 0.32),
          semanticsLabel: 'Прогресс пары',
        ),
      ],
    );
  }
}

/// Пульсирующая точка у метки «Сейчас идёт» — элемент макета.
///
/// Пульсация — прозрачность, поэтому анимация относится к effects и идёт
/// без перелёта.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 1.0,
    end: 0.3,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: context.colors.onPrimary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Номер аудитории с сайта → подпись: `71` → `ауд. 71`, прочее без изменений.
String roomLabel(String room) =>
    RegExp(r'^\d').hasMatch(room) ? 'ауд. $room' : room;

/// Прогресс идущей пары.
@immutable
class LessonProgress {
  const LessonProgress({required this.fraction, required this.minutesLeft});

  /// Доля прошедшего времени, 0..1.
  final double fraction;

  /// Сколько минут до конца, с округлением вверх.
  final int minutesLeft;

  /// Прогресс [slot] в дне [day] на момент [now]; `null`, если пара не идёт.
  static LessonProgress? of(LessonSlot slot, DateTime day, DateTime now) {
    if (!DateUtils.isSameDay(day, now)) return null;
    final int seconds = now.hour * 3600 + now.minute * 60 + now.second;
    final int start = slot.startMinutes * 60;
    final int end = slot.endMinutes * 60;
    if (seconds < start || seconds >= end) return null;
    return LessonProgress(
      fraction: (seconds - start) / (end - start),
      minutesLeft: ((end - seconds) / 60).ceil(),
    );
  }
}

typedef SlotStatus = ({
  SlotTiming timing,
  LessonProgress? progress,
  int? startsIn,
});

/// Сроки пар дня на момент [now]: прошла, идёт или впереди, и через сколько
/// минут начнётся ближайшая сегодняшняя.
List<SlotStatus> slotTimings(
  List<LessonSlot> slots,
  DateTime day,
  DateTime now,
) {
  final DateTime today = DateUtils.dateOnly(now);
  final DateTime date = DateUtils.dateOnly(day);
  final int nowMinutes = now.hour * 60 + now.minute;
  bool nextFound = false;

  final List<SlotStatus> result = [];
  for (final LessonSlot slot in slots) {
    final LessonProgress? progress = LessonProgress.of(slot, day, now);
    final SlotTiming timing = date.isBefore(today)
        ? SlotTiming.past
        : date.isAfter(today)
        ? SlotTiming.upcoming
        : progress != null
        ? SlotTiming.now
        : slot.endMinutes <= nowMinutes
        ? SlotTiming.past
        : SlotTiming.upcoming;

    int? startsIn;
    if (date == today && timing == SlotTiming.upcoming && !nextFound) {
      startsIn = slot.startMinutes - nowMinutes;
      nextFound = true;
    }
    result.add((timing: timing, progress: progress, startsIn: startsIn));
  }
  return result;
}

/// «1 подгруппа» — когда показана только своя подгруппа.
class SubgroupBadge extends StatelessWidget {
  const SubgroupBadge({
    super.key,
    required this.number,
    this.onPrimarySurface = false,
  });

  final int number;
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onPrimarySurface
            ? colors.onPrimary.withValues(alpha: 0.22)
            : colors.surfaceContainerHigh,
        borderRadius: AppShapes.all(AppShapes.chip),
      ),
      child: Text(
        '$number подгруппа',
        style: context.text.labelSmall!.copyWith(
          color: onPrimarySurface ? colors.onPrimary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
