import 'dart:math' as math;

import 'package:flutter/material.dart';

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

    return Semantics(
      label:
          'Пропущено $missedHours часов из $limitHours. '
          'Оправдано $justifiedHours часов, без справки $unjustifiedHours часов.',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _DonutPainter(
              // Внешняя дуга — весь пропуск, поверх неё дуга без справки.
              totalFraction: missedHours / limitHours,
              unjustifiedFraction: unjustifiedHours / limitHours,
              trackColor: colors.surfaceContainerHigh,
              totalColor: colors.primaryContainer,
              unjustifiedColor: colors.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$missedHours',
                    style: context.text.displaySmall!.emphasized.copyWith(
                      fontSize: 48,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'часов пропущено',
                    style: context.text.bodyMedium!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'лимит $limitHours ч',
                    style: context.text.labelMedium!.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
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
