import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

/// Кольцевая диаграмма пропусков: всё кольцо — пропущенные часы, дуги —
/// доли со справкой и без.
///
/// Это инфографика, а не компонент прогресса: у неё две дуги и своя
/// семантика, поэтому она намеренно не переиспользует `M3WavyLinearProgress`.
class AbsenceDonut extends StatelessWidget {
  const AbsenceDonut({
    super.key,
    required this.justifiedHours,
    required this.unjustifiedHours,
    this.size = 212,
  });

  final int justifiedHours;
  final int unjustifiedHours;
  final double size;

  int get missedHours => justifiedHours + unjustifiedHours;

  /// Толщина дуг.
  static const double strokeWidth = 18;

  /// Зазор между дугами — `ProgressIndicatorDefaults.CircularIndicatorTrackGapSize`.
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    // Диаметр растёт вместе с подписями в центре: при системном шрифте 200%
    // две строки иначе не помещаются внутрь кольца.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double effectiveSize = math.max(
      size,
      scaler.scale(130) + 2 * strokeWidth,
    );

    return Semantics(
      label:
          'Пропущено $missedHours часов. '
          'По справке $justifiedHours часов, без справки $unjustifiedHours часов.',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: effectiveSize,
          child: CustomPaint(
            painter: _DonutPainter(
              justifiedHours: justifiedHours,
              unjustifiedHours: unjustifiedHours,
              // Пустое кольцо — роль трека индикаторов прогресса.
              trackColor: colors.secondaryContainer,
              // Дуги различимы между собой и с треком: tertiary и primary.
              justifiedColor: colors.tertiary,
              unjustifiedColor: colors.primary,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: strokeWidth + effectiveSize * 0.06,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$missedHours',
                      // Крупное число — editorial-момент: стиль шкалы
                      // displayMedium без изменения размера
                      // (typography → «Avoid changing the type size»).
                      style: context.text.displayMedium!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space75),
                    Text(
                      'часов пропущено',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.justifiedHours,
    required this.unjustifiedHours,
    required this.trackColor,
    required this.justifiedColor,
    required this.unjustifiedColor,
  });

  final int justifiedHours;
  final int unjustifiedHours;
  final Color trackColor;
  final Color justifiedColor;
  final Color unjustifiedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - AbsenceDonut.strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    Paint stroke(Color color, StrokeCap cap) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AbsenceDonut.strokeWidth
      ..strokeCap = cap;

    final int total = justifiedHours + unjustifiedHours;
    if (total == 0 || justifiedHours == 0 || unjustifiedHours == 0) {
      // Одна доля или пропусков нет — сплошное кольцо без зазоров.
      final Color color = total == 0
          ? trackColor
          : (justifiedHours > 0 ? justifiedColor : unjustifiedColor);
      canvas.drawCircle(center, radius, stroke(color, StrokeCap.butt));
      return;
    }

    // Зазор с круглыми концами расширяется на толщину дуги, как
    // `adjustedGapSize` в `CircularProgressIndicator`.
    final double gapAngle =
        (AbsenceDonut.gap + AbsenceDonut.strokeWidth) / radius;
    const double start = -math.pi / 2;
    final double justifiedSweep = 2 * math.pi * justifiedHours / total;

    void arc(double from, double sweep, Color color) {
      final double visible = sweep - gapAngle;
      if (visible <= 0) {
        // Доля короче зазора — точка на месте дуги.
        canvas.drawArc(
          rect,
          from + sweep / 2,
          0.0001,
          false,
          stroke(color, StrokeCap.round),
        );
        return;
      }
      canvas.drawArc(
        rect,
        from + gapAngle / 2,
        visible,
        false,
        stroke(color, StrokeCap.round),
      );
    }

    arc(start, justifiedSweep, justifiedColor);
    arc(start + justifiedSweep, 2 * math.pi - justifiedSweep, unjustifiedColor);
  }

  @override
  bool shouldRepaint(_DonutPainter old) {
    return old.justifiedHours != justifiedHours ||
        old.unjustifiedHours != unjustifiedHours ||
        old.trackColor != trackColor ||
        old.justifiedColor != justifiedColor ||
        old.unjustifiedColor != unjustifiedColor;
  }
}
