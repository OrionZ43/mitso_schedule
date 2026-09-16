import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models/lesson.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import 'm3_wavy_linear_progress.dart';
import 'status_badge.dart';

/// Карточка пары.
///
/// Обычная — outlined card радиусом 28dp; текущая — залитая `primary`
/// радиусом 32dp с меткой «Сейчас идёт» и волнистой шкалой прогресса.
class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson, this.now});

  final Lesson lesson;

  /// Прогресс пары, если она идёт прямо сейчас.
  final LessonProgress? now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool isNow = now != null;

    final Color foreground = isNow ? colors.onPrimary : colors.onSurface;
    final Color secondary = isNow
        ? colors.onPrimary.withValues(alpha: 0.86)
        : colors.onSurfaceVariant;

    return Semantics(
      container: true,
      label: isNow ? 'Текущая пара' : null,
      child: Container(
        padding: EdgeInsets.all(isNow ? 22 : 20),
        decoration: BoxDecoration(
          // Outlined card по card/tokens.xml: фон surface, обводка outlineVariant.
          color: isNow ? colors.primary : colors.surface,
          borderRadius: AppShapes.all(
            isNow ? AppShapes.cardEmphasized : AppShapes.card,
          ),
          border: isNow ? null : Border.all(color: colors.outlineVariant),
          boxShadow: isNow
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
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
                        lesson.start,
                        style: context.text.titleMedium!.copyWith(
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.end,
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
                          LessonTypeBadge(
                            type: lesson.type,
                            label: lesson.typeLabel,
                            onPrimarySurface: isNow,
                          ),
                          if (lesson.subgroup != null)
                            _SubgroupBadge(
                              number: lesson.subgroup!,
                              onPrimarySurface: isNow,
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        lesson.title,
                        style: context.text.titleMedium!.emphasized.copyWith(
                          height: 1.5,
                          color: foreground,
                        ),
                      ),
                      if (lesson.teacher != null) ...[
                        const SizedBox(height: 10),
                        _MetaRow(
                          icon: Symbols.person,
                          text: lesson.teacher!,
                          color: secondary,
                        ),
                      ],
                      if (lesson.room != null) ...[
                        const SizedBox(height: 4),
                        _MetaRow(
                          icon: Symbols.door_front,
                          text: roomLabel(lesson.room!),
                          color: secondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (isNow) ...[
              const SizedBox(height: 18),
              _NowSection(progress: now!),
            ],
          ],
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

/// Пульсирующая точка у метки «Сейчас идёт».
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

  /// Прогресс [lesson] в дне [day] на момент [now]; `null`, если пара не идёт.
  static LessonProgress? of(Lesson lesson, DateTime day, DateTime now) {
    if (!DateUtils.isSameDay(day, now)) return null;
    final int seconds = now.hour * 3600 + now.minute * 60 + now.second;
    final int start = lesson.startMinutes * 60;
    final int end = lesson.endMinutes * 60;
    if (seconds < start || seconds >= end) return null;
    return LessonProgress(
      fraction: (seconds - start) / (end - start),
      minutesLeft: ((end - seconds) / 60).ceil(),
    );
  }
}

class _SubgroupBadge extends StatelessWidget {
  const _SubgroupBadge({required this.number, required this.onPrimarySurface});

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
