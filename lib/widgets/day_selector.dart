import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/lesson.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Горизонтальный селектор дней.
///
/// Выбранный день ведёт себя как toggle button из M3 Expressive: в Compose
/// Material3 (`ToggleButton.kt`) форма при выборе морфится пружиной
/// `FastSpatial`, а цвет — `DefaultEffects`. Здесь так же: радиус 16dp -> 28dp
/// на `fastSpatial`, заливка и текст на `defaultEffects`.
///
/// Выбранный день всегда прокручивается в видимую область — при свайпе по
/// списку пар или переходе из поиска он может оказаться за краем. Прокрутка —
/// пружина без перелёта: перелёт увёл бы ленту за её границы.
class DaySelector extends StatefulWidget {
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
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  final GlobalKey _selectedKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(animate: true),
      );
    }
  }

  void _reveal({required bool animate}) {
    final RenderObject? chip = _selectedKey.currentContext?.findRenderObject();
    if (!mounted || chip == null || !_scroll.hasClients) return;
    // Позиция именно ленты: Scrollable.ensureVisible прокрутил бы ещё и
    // вертикальный список экрана.
    _scroll.position.ensureVisible(
      chip,
      alignment: 0.5,
      duration: animate ? AppMotion.defaultEffects.duration : Duration.zero,
      curve: AppMotion.defaultEffects.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Горизонтальной ленте нужна явная высота, поэтому она считается из
    // текущего масштаба шрифта: 12 сверху + строка дня + 6 + число + 14 снизу.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double height = 12 + scaler.scale(16) + 6 + scaler.scale(27) + 14;

    // Не ListView: дней всего две недели, а ленивый список не построил бы
    // выбранный день за краем экрана и к нему нельзя было бы прокрутить.
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (int i = 0; i < widget.days.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _DayChip(
                key: i == widget.selectedIndex ? _selectedKey : null,
                day: widget.days[i],
                selected: i == widget.selectedIndex,
                onTap: () => widget.onSelected(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
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
        duration: AppMotion.fastSpatial.duration,
        curve: AppMotion.fastSpatial.curve,
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
