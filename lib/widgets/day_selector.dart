import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/lesson.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Горизонтальный селектор дней Пн–Сб.
///
/// У выбранного дня радиус морфится 16dp -> 28dp пружиной `defaultSpatial`,
/// а заливка меняется по `defaultEffects` — движение формы и движение цвета
/// разведены, как требует
/// https://m3.material.io/styles/motion/overview/specs
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ScheduleDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Горизонтальному списку нужна явная высота, поэтому она считается из
    // текущего масштаба шрифта: 12 сверху + строка дня + 6 + число + 14 снизу.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double height = 12 + scaler.scale(16) + 6 + scaler.scale(27) + 14;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _DayChip(
          day: days[index],
          selected: index == selectedIndex,
          onTap: () => onSelected(index),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final ScheduleDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    final Color background = selected
        ? colors.primary
        : colors.surfaceContainer;
    final Color nameColor = selected
        ? colors.onPrimary.withValues(alpha: 0.82)
        : colors.onSurfaceVariant;
    final Color numberColor = selected ? colors.onPrimary : colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '${day.title}, ${DateFormat.MMMMd('ru').format(day.date)}',
      child: TweenAnimationBuilder<double>(
        // Форма — spatial-пружина, с перелётом.
        tween: Tween<double>(
          end: selected ? AppShapes.extraLarge : AppShapes.dayUnselected,
        ),
        duration: AppMotion.defaultSpatial.duration,
        curve: AppMotion.defaultSpatial.curve,
        builder: (context, radius, child) {
          return TweenAnimationBuilder<Color?>(
            // Цвет — effects-пружина, без перелёта.
            tween: ColorTween(end: background),
            duration: AppMotion.defaultEffects.duration,
            curve: AppMotion.defaultEffects.curve,
            builder: (context, color, child) {
              return Material(
                color: color,
                borderRadius: AppShapes.all(radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: onTap, child: child),
              );
            },
            child: child,
          );
        },
        // Текст внутри озвучивать не нужно — метка задана выше целиком,
        // при этом действие нажатия у InkWell сохраняется.
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.defaultEffects.duration,
                    curve: AppMotion.defaultEffects.curve,
                    style: context.text.labelMedium!.copyWith(color: nameColor),
                    child: Text(day.shortName),
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.defaultEffects.duration,
                    curve: AppMotion.defaultEffects.curve,
                    style: context.text.titleMedium!.emphasized.copyWith(
                      fontSize: 18,
                      color: numberColor,
                    ),
                    child: Text(day.dayNumber),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
