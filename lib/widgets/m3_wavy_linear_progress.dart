import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Волнистая линейная шкала прогресса Material 3 Expressive.
///
/// https://m3.material.io/components/progress-indicators/overview
///
/// Flutter 3.44 умеет часть новой спеки штатно (`LinearProgressIndicator`
/// с `year2023: false` даёт `trackGap` и `stopIndicator*`), но волнистого
/// варианта не поставляет — проверено по
/// `packages/flutter/lib/src/material/progress_indicator.dart`. Поэтому
/// активная часть рисуется здесь синусоидой на [CustomPainter].
class M3WavyLinearProgress extends StatefulWidget {
  const M3WavyLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.semanticsLabel,
  });

  /// Прогресс 0..1.
  final double value;

  /// Активная часть. По умолчанию `colorScheme.primary`.
  final Color? color;

  /// Трек. По умолчанию активный цвет с прозрачностью [trackOpacity].
  final Color? trackColor;

  final String? semanticsLabel;

  /// Длина волны.
  static const double wavelength = 40;

  /// Амплитуда синусоиды.
  static const double amplitude = 3;

  /// Толщина активной части и трека.
  static const double thickness = 4;

  /// Зазор между активной частью и треком.
  static const double trackGap = 4;

  /// Диаметр точки-ограничителя в конце шкалы.
  static const double stopIndicatorSize = 4;

  /// Высота виджета: волна плюс запас на амплитуду.
  static const double height = 14;

  /// Прозрачность трека относительно активного цвета.
  static const double trackOpacity = 0.32;

  /// Период бегущей волны.
  static const Duration wavePeriod = Duration(milliseconds: 2000);

  /// С этого значения амплитуда начинает уходить в ноль, на 1.0 волна плоская.
  static const double flattenFrom = 0.9;

  /// Амплитуда волны для заданного прогресса.
  ///
  /// Вынесено из painter-а, чтобы геометрию можно было проверить юнит-тестом.
  static double amplitudeFor(double value) {
    final double v = value.clamp(0.0, 1.0);
    if (v <= flattenFrom) return amplitude;
    final double t = ((v - flattenFrom) / (1 - flattenFrom)).clamp(0.0, 1.0);
    return amplitude * (1 - t);
  }

  @override
  State<M3WavyLinearProgress> createState() => _M3WavyLinearProgressState();
}

class _M3WavyLinearProgressState extends State<M3WavyLinearProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: M3WavyLinearProgress.wavePeriod,
  )..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color active = widget.color ?? Theme.of(context).colorScheme.primary;
    final double value = widget.value.clamp(0.0, 1.0);

    return Semantics(
      label: widget.semanticsLabel,
      value: '${(value * 100).round()}%',
      child: SizedBox(
        height: M3WavyLinearProgress.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _phase,
          builder: (context, _) {
            return CustomPaint(
              painter: _WavyPainter(
                value: value,
                phase: _phase.value,
                color: active,
                trackColor:
                    widget.trackColor ??
                    active.withValues(alpha: M3WavyLinearProgress.trackOpacity),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.trackColor,
  });

  final double value;

  /// Фаза бегущей волны, 0..1 за один период.
  final double phase;

  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double width = size.width;
    if (width <= 0) return;

    const double stroke = M3WavyLinearProgress.thickness;
    const double gap = M3WavyLinearProgress.trackGap;
    const double stopRadius = M3WavyLinearProgress.stopIndicatorSize / 2;

    // Точка-ограничитель всегда прижата к правому концу шкалы.
    final double stopCenterX = width - stopRadius;
    final double activeEnd = (value * width).clamp(0.0, width);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint activePaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Трек: от конца активной части с зазором и до правого края.
    final double trackStart = activeEnd + gap + stroke / 2;
    final double trackEnd = stopCenterX - gap;
    if (trackStart < trackEnd) {
      canvas.drawLine(
        Offset(trackStart, centerY),
        Offset(trackEnd, centerY),
        trackPaint,
      );
    }

    // Активная часть: синусоида с бегущей фазой.
    if (activeEnd > 0) {
      canvas.drawPath(_wavePath(activeEnd, centerY, stroke), activePaint);
    }

    // Stop indicator — того же цвета, что активная часть.
    canvas.drawCircle(
      Offset(stopCenterX, centerY),
      stopRadius,
      Paint()..color = color,
    );
  }

  Path _wavePath(double end, double centerY, double stroke) {
    final Path path = Path();
    final double amplitude = M3WavyLinearProgress.amplitudeFor(value);
    final double start = stroke / 2;
    final double last = math.max(start, end - stroke / 2);

    double yAt(double x) {
      if (amplitude == 0) return centerY;
      final double angle =
          2 * math.pi * ((x / M3WavyLinearProgress.wavelength) + phase);
      return centerY + amplitude * math.sin(angle);
    }

    path.moveTo(start, yAt(start));
    // Шаг в 1 логический пиксель: на длине волны 40dp этого достаточно,
    // чтобы ломаная читалась как гладкая синусоида.
    for (double x = start + 1; x < last; x += 1) {
      path.lineTo(x, yAt(x));
    }
    path.lineTo(last, yAt(last));
    return path;
  }

  @override
  bool shouldRepaint(_WavyPainter old) {
    return old.value != value ||
        old.phase != phase ||
        old.color != color ||
        old.trackColor != trackColor;
  }
}
