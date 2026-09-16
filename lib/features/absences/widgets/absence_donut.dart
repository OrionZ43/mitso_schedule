import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

/// Кольцевая диаграмма пропусков.
///
/// Это инфографика, а не компонент прогресса: у неё две наложенные дуги и своя
/// семантика, поэтому она намеренно не переиспользует
/// `LinearProgressIndicator`/`M3WavyLinearProgress`.
class AbsenceDonut extends StatelessWidget {
  const AbsenceDonut({
    super.key,
    required this.missedHours,
    required this.justifiedHours,
    required this.unjustifiedHours,
    required this.limitHours,
    this.size = 212,
  });

  final int missedHours;
  final int justifiedHours;
  final int unjustifiedHours;
  final int limitHours;
  final double size;

  /// Толщина дуг.
  static const double strokeWidth = 18;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    // Диаметр растёт вместе с подписями в центре: при системном шрифте 200%
    // три строки иначе не помещаются внутрь кольца.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double effectiveSize = math.max(
      size,
      scaler.scale(150) + 2 * strokeWidth,
    );

    return Semantics(
      label:
          'Пропущено $missedHours часов из $limitHours. '
          'Оправдано $justifiedHours часов, без справки $unjustifiedHours часов.',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: effectiveSize,
          child: CustomPaint(
            painter: _DonutPainter(
              // Внешняя дуга — весь пропуск, поверх неё дуга без справки.
              totalFraction: missedHours / limitHours,
              unjustifiedFraction: unjustifiedHours / limitHours,
              // Трек дуги — роль трека индикаторов прогресса.
              trackColor: colors.secondaryContainer,
              // Дуги различимы с треком и друг с другом: tertiary и primary
              // (контейнерная роль сливалась бы с треком secondaryContainer).
              totalColor: colors.tertiary,
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
                    const SizedBox(height: AppSpacing.space25),
                    Text(
                      'лимит $limitHours ч',
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium!.copyWith(
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
    required this.totalFraction,
    required this.unjustifiedFraction,
    required this.trackColor,
    required this.totalColor,
    required this.unjustifiedColor,
  });

  final double totalFraction;
  final double unjustifiedFraction;
  final Color trackColor;
  final Color totalColor;
  final Color unjustifiedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - AbsenceDonut.strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color, {bool round = true}) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AbsenceDonut.strokeWidth
      ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

    // Трек — полный круг.
    canvas.drawCircle(center, radius, arcPaint(trackColor, round: false));

    const double start = -math.pi / 2;
    canvas.drawArc(
      rect,
      start,
      2 * math.pi * totalFraction.clamp(0.0, 1.0),
      false,
      arcPaint(totalColor),
    );
    canvas.drawArc(
      rect,
      start,
      2 * math.pi * unjustifiedFraction.clamp(0.0, 1.0),
      false,
      arcPaint(unjustifiedColor),
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) {
    return old.totalFraction != totalFraction ||
        old.unjustifiedFraction != unjustifiedFraction ||
        old.trackColor != trackColor ||
        old.totalColor != totalColor ||
        old.unjustifiedColor != unjustifiedColor;
  }
}
