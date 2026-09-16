import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Волнистая линейная шкала прогресса Material 3 Expressive.
///
/// Порт determinate-варианта `Widget.Material3Expressive.LinearProgressIndicator.Wavy`
/// из material-components-android:
/// https://github.com/material-components/material-components-android/blob/master/docs/components/ProgressIndicator.md
///
/// Во Flutter 3.44 волнистого варианта нет (`LinearProgressIndicator` умеет
/// только зазор и stop indicator). Размеры — из `progressindicator/res/values/tokens.xml`,
/// поведение амплитуды и зазора — из `DeterminateDrawable.java`.
class M3WavyLinearProgress extends StatefulWidget {
  const M3WavyLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.waveSpeed = 0,
    this.semanticsLabel,
  });

  /// Прогресс 0..1.
  final double value;

  /// Активная часть и stop indicator. По умолчанию `colorScheme.primary`
  /// (`m3_comp_progress_indicator_active_indicator_color`).
  final Color? color;

  /// Трек. По умолчанию `colorScheme.secondaryContainer`
  /// (`m3_comp_progress_indicator_track_color`).
  final Color? trackColor;

  /// Скорость бега волны, dp в секунду. Как и `waveSpeed` в MDC, по умолчанию
  /// 0 — волна неподвижна.
  final double waveSpeed;

  final String? semanticsLabel;

  /// `m3_comp_progress_indicator_linear_track_thickness`.
  static const double thickness = 4;

  /// `m3_comp_progress_indicator_linear_track_active_indicator_space`.
  static const double trackGap = 4;

  /// `m3_comp_progress_indicator_linear_stop_indicator_size`.
  static const double stopIndicatorSize = 4;

  /// `m3_comp_progress_indicator_linear_active_indicator_wave_amplitude`.
  static const double amplitude = 3;

  /// `m3_comp_progress_indicator_linear_active_indicator_wave_wavelength`.
  static const double wavelength = 40;

  /// Высота: толщина плюс размах волны в обе стороны.
  static const double height = thickness + 2 * amplitude;

  /// `FULL_AMPLITUDE_PROGRESS_MIN` / `_MAX`: вне этого диапазона волна гаснет.
  static const double fullAmplitudeProgressMin = 0.1;
  static const double fullAmplitudeProgressMax = 0.9;

  /// `AMPLITUDE_ANIMATION_DURATION_MS`.
  static const Duration amplitudeAnimationDuration = Duration(
    milliseconds: 500,
  );

  /// `GAP_RAMP_DOWN_THRESHOLD`: у самого начала зазор сходит на нет.
  static const double gapRampDownThreshold = 0.01;

  /// Должна ли волна быть включена при данном прогрессе.
  static bool hasFullAmplitude(double value) =>
      value >= fullAmplitudeProgressMin && value <= fullAmplitudeProgressMax;

  /// Зазор между активной частью и треком при данном прогрессе.
  static double displayedGap(double value) =>
      trackGap * math.min(1.0, value.clamp(0.0, 1.0) / gapRampDownThreshold);

  @override
  State<M3WavyLinearProgress> createState() => _M3WavyLinearProgressState();
}

class _M3WavyLinearProgressState extends State<M3WavyLinearProgress>
    with TickerProviderStateMixin {
  late final AnimationController _amplitude = AnimationController(
    vsync: this,
    duration: M3WavyLinearProgress.amplitudeAnimationDuration,
    value: M3WavyLinearProgress.hasFullAmplitude(widget.value) ? 1 : 0,
  );

  /// Включение волны — стандартный easing, выключение — emphasized
  /// accelerate, как `amplitudeOnInterpolator` / `amplitudeOffInterpolator`.
  late CurvedAnimation _amplitudeCurve = _curveFor(on: true);

  Ticker? _phaseTicker;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _syncPhaseTicker();
  }

  @override
  void didUpdateWidget(M3WavyLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasOn = M3WavyLinearProgress.hasFullAmplitude(oldWidget.value);
    final bool isOn = M3WavyLinearProgress.hasFullAmplitude(widget.value);
    if (wasOn != isOn) {
      _amplitudeCurve.dispose();
      _amplitudeCurve = _curveFor(on: isOn);
      isOn ? _amplitude.forward() : _amplitude.reverse();
    }
    if (oldWidget.waveSpeed != widget.waveSpeed) _syncPhaseTicker();
  }

  CurvedAnimation _curveFor({required bool on}) => CurvedAnimation(
    parent: _amplitude,
    curve: on ? Easing.standard : Easing.emphasizedAccelerate,
    reverseCurve: on ? Easing.standard : Easing.emphasizedAccelerate,
  );

  /// Бегущая волна требует покадровой перерисовки, неподвижная — нет.
  void _syncPhaseTicker() {
    _phaseTicker?.dispose();
    _phaseTicker = null;
    if (widget.waveSpeed == 0) return;
    _phaseTicker = createTicker((elapsed) {
      final double seconds =
          elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      setState(() => _phase = seconds * widget.waveSpeed);
    })..start();
  }

  @override
  void dispose() {
    _phaseTicker?.dispose();
    _amplitudeCurve.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double value = widget.value.clamp(0.0, 1.0);

    return Semantics(
      label: widget.semanticsLabel,
      value: '${(value * 100).round()}%',
      child: SizedBox(
        height: M3WavyLinearProgress.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _amplitudeCurve,
          builder: (context, _) => CustomPaint(
            painter: _WavyPainter(
              value: value,
              amplitudeFraction: _amplitudeCurve.value,
              phase: _phase,
              color: widget.color ?? colors.primary,
              trackColor: widget.trackColor ?? colors.secondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.value,
    required this.amplitudeFraction,
    required this.phase,
    required this.color,
    required this.trackColor,
  });

  final double value;

  /// Доля от полной амплитуды, 0..1.
  final double amplitudeFraction;

  /// Сдвиг волны в dp.
  final double phase;

  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    if (width <= 0) return;

    const double stroke = M3WavyLinearProgress.thickness;
    final double centerY = size.height / 2;
    final double gap = M3WavyLinearProgress.displayedGap(value);

    // Скругления концов — половина толщины (`trackCornerRadius` 50%),
    // поэтому отрезки отступают от краёв на радиус скругления.
    const double cap = stroke / 2;
    final double activeEnd = cap + value * (width - 2 * cap);

    Paint strokePaint(Color c) => Paint()
      ..color = c
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Трек — от конца активной части с зазором до самого края: stop indicator
    // в MDC лежит поверх трека, а не отделён от него.
    final double trackStart = value <= 0 ? cap : activeEnd + gap + stroke;
    final double trackEnd = width - cap;
    if (trackStart < trackEnd) {
      canvas.drawLine(
        Offset(trackStart, centerY),
        Offset(trackEnd, centerY),
        strokePaint(trackColor),
      );
    }

    if (value > 0) {
      canvas.drawPath(_wave(cap, activeEnd, centerY), strokePaint(color));
    }

    // Stop indicator: центр отступает от края на половину толщины трека.
    const double stopRadius = M3WavyLinearProgress.stopIndicatorSize / 2;
    canvas.drawCircle(
      Offset(width - cap, centerY),
      stopRadius,
      Paint()..color = color,
    );
  }

  Path _wave(double start, double end, double centerY) {
    final Path path = Path();
    final double amplitude = M3WavyLinearProgress.amplitude * amplitudeFraction;

    double yAt(double x) {
      if (amplitude == 0) return centerY;
      return centerY +
          amplitude *
              math.sin(
                2 * math.pi * (x - phase) / M3WavyLinearProgress.wavelength,
              );
    }

    path.moveTo(start, yAt(start));
    // Шаг в 1dp: на длине волны 40dp ломаная неотличима от синусоиды.
    for (double x = start + 1; x < end; x += 1) {
      path.lineTo(x, yAt(x));
    }
    path.lineTo(end, yAt(end));
    return path;
  }

  @override
  bool shouldRepaint(_WavyPainter old) {
    return old.value != value ||
        old.amplitudeFraction != amplitudeFraction ||
        old.phase != phase ||
        old.color != color ||
        old.trackColor != trackColor;
  }
}
