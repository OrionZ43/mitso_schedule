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
  const LessonCard({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool isNow = lesson.isNow;

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
          color: isNow ? colors.primary : colors.surfaceContainerLow,
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
                      LessonTypeBadge(
                        type: lesson.type,
                        onPrimarySurface: isNow,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        lesson.title,
                        style: context.text.titleMedium!.emphasized.copyWith(
                          height: 1.5,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MetaRow(
                        icon: Symbols.person,
                        text: lesson.teacher,
                        color: secondary,
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(
                        icon: Symbols.door_front,
                        text: lesson.room,
                        color: secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isNow) ...[
              const SizedBox(height: 18),
              _NowSection(lesson: lesson),
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
  const _NowSection({required this.lesson});

  final Lesson lesson;

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
            if (lesson.timeLeft != null)
              Text(
                'осталось ${lesson.timeLeft}',
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
          value: lesson.progress ?? 0,
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
