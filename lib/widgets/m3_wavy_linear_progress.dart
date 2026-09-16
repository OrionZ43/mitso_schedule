import 'dart:math' as math;
import 'dart:ui' show PathMetric, SemanticsRole;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_motion.dart';

/// Волнистая линейная шкала прогресса Material 3 Expressive — порт
/// определённого `LinearWavyProgressIndicator(progress, ...)` из Compose
/// Material3 (`WavyProgressIndicator.kt`,
/// `internal/LinearWavyProgressModifiers.kt`).
///
/// Во Flutter 3.44 волнистого варианта нет (`LinearProgressIndicator` умеет
/// только зазор и stop indicator).
///
/// Отличия от Compose, которые добавляет обёртка:
/// * [value] анимируется внутри виджета за 500 мс линейно —
///   `WavyProgressIndicatorDefaults.ProgressAnimationSpec`, которую
///   документация `LinearWavyProgressIndicator` советует вызывающему коду;
/// * по умолчанию шкала растягивается на ширину родителя (гайдлайн:
///   «along the edge of a container»), 240dp (`LinearContainerWidth`) — только
///   при неограниченной ширине.
///
/// Уменьшение движения (`MediaQuery.disableAnimations`): как Compose при
/// `MotionDurationScale` = 0 — значение и амплитуда меняются сразу, волна не
/// бежит.
class M3WavyLinearProgress extends StatefulWidget {
  const M3WavyLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.showTrack = true,
    this.waveSpeed,
    this.semanticsLabel,
  });

  /// Прогресс 0..1; значения вне диапазона приводятся к нему.
  final double value;

  /// Активная часть и stop indicator. По умолчанию `primary`
  /// (`ProgressIndicatorTokens.ActiveIndicatorColor` и `StopColor`).
  final Color? color;

  /// Трек. По умолчанию `secondaryContainer`
  /// (`ProgressIndicatorTokens.TrackColor`).
  final Color? trackColor;

  /// `false` убирает трек вместе со stop indicator. Гайдлайн (Accessibility →
  /// Interaction & style): внутри компонента, например кнопки, активная часть
  /// берёт цвет подписи, а трек убирается.
  final bool showTrack;

  /// Скорость бега волны, dp/с. По умолчанию — [wavelength], то есть одна
  /// волна в секунду (`waveSpeed: Dp = wavelength`). 0 — волна стоит.
  final double? waveSpeed;

  /// Подпись для TalkBack: процесс и объект («Loading news article»).
  final String? semanticsLabel;

  /// `LinearProgressIndicatorTokens.ActiveThickness`.
  static const double thickness = 4;

  /// `LinearProgressIndicatorTokens.TrackThickness`.
  static const double trackThickness = 4;

  /// `LinearProgressIndicatorTokens.TrackActiveSpace` →
  /// `LinearIndicatorTrackGapSize`.
  static const double trackGap = 4;

  /// `LinearProgressIndicatorTokens.StopSize` →
  /// `LinearTrackStopIndicatorSize`.
  static const double stopIndicatorSize = 4;

  /// `LinearProgressIndicatorTokens.ActiveWaveAmplitude`: пик
  /// `(height − thickness) / 2`.
  static const double amplitude = 3;

  /// `LinearProgressIndicatorTokens.ActiveWaveWavelength` →
  /// `LinearDeterminateWavelength`.
  static const double wavelength = 40;

  /// `LinearProgressIndicatorTokens.WaveHeight` → `LinearContainerHeight`.
  static const double height = 10;

  /// `WavyProgressIndicatorDefaults.LinearContainerWidth`.
  static const double containerWidth = 240;

  /// `ProgressAnimationSpec`: tween `DurationLong2`, `EasingLinearCubicBezier`.
  static const Duration progressAnimationDuration = Duration(milliseconds: 500);

  /// `IncreasingAmplitudeAnimationSpec` / `DecreasingAmplitudeAnimationSpec`:
  /// tween `DurationLong2`, `EasingStandardCubicBezier` /
  /// `EasingEmphasizedAccelerateCubicBezier`.
  static const Duration amplitudeAnimationDuration = Duration(
    milliseconds: 500,
  );
  static const Curve increasingAmplitudeEasing = Easing.standard;
  static const Curve decreasingAmplitudeEasing = Easing.emphasizedAccelerate;

  /// `MinAnimationDuration`: волна не бежит быстрее цикла в 50 мс.
  static const Duration minWaveAnimationDuration = Duration(milliseconds: 50);

  /// `WavyProgressIndicatorDefaults.indicatorAmplitude`: полная амплитуда
  /// только при `0.1 < progress < 0.95`.
  static double indicatorAmplitude(double progress) =>
      progress <= 0.1 || progress >= 0.95 ? 0 : 1;

  /// Длительность одного цикла волны: `round(wavelength / waveSpeed × 1000)`,
  /// не меньше [minWaveAnimationDuration]. `null` — волна стоит.
  static Duration? waveCycleDuration(double wavelength, double waveSpeed) {
    if (waveSpeed <= 0 || wavelength <= 0) return null;
    final int millis = (wavelength / waveSpeed * 1000).round();
    return Duration(
      milliseconds: math.max(millis, minWaveAnimationDuration.inMilliseconds),
    );
  }

  @override
  State<M3WavyLinearProgress> createState() => _M3WavyLinearProgressState();
}

class _M3WavyLinearProgressState extends State<M3WavyLinearProgress>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    value: _coerce(widget.value),
    animationBehavior: AnimationBehavior.preserve,
  );

  /// `amplitudeAnimatable`: стартует сразу в целевом значении.
  late final AnimationController _amplitude = AnimationController(
    vsync: this,
    value: M3WavyLinearProgress.indicatorAmplitude(_coerce(widget.value)),
    animationBehavior: AnimationBehavior.preserve,
  );
  late double _amplitudeTarget = _amplitude.value;

  /// `waveOffset`, доля длины волны 0..1.
  final ValueNotifier<double> _waveOffset = ValueNotifier(0);
  late final Ticker _waveTicker = createTicker(_onWaveTick);
  double _waveOffsetAtStart = 0;

  bool _reduceMotion = false;

  static double _coerce(double value) =>
      value.isNaN ? 0 : value.clamp(0.0, 1.0);

  double get _waveSpeed => widget.waveSpeed ?? M3WavyLinearProgress.wavelength;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_updateAmplitudeAnimation);
    _amplitude.addListener(_syncWaveTicker);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
    _syncWaveTicker();
  }

  @override
  void didUpdateWidget(M3WavyLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double target = _coerce(widget.value);
    if (target != _coerce(oldWidget.value)) {
      if (_reduceMotion) {
        _progress.value = target;
      } else {
        _progress.animateTo(
          target,
          duration: M3WavyLinearProgress.progressAnimationDuration,
        );
      }
    }
    if (oldWidget.waveSpeed != widget.waveSpeed) {
      // `updateOffsetAnimation()`: перезапуск с текущего смещения.
      if (_waveTicker.isActive) _waveTicker.stop();
      _syncWaveTicker();
    }
  }

  /// `updateAmplitudeAnimation`: новая анимация запускается, только если цель
  /// изменилась и предыдущая уже закончилась.
  void _updateAmplitudeAnimation() {
    final double target = M3WavyLinearProgress.indicatorAmplitude(
      _progress.value,
    );
    if (target == _amplitudeTarget || _amplitude.isAnimating) return;
    _amplitudeTarget = target;
    if (_reduceMotion) {
      _amplitude.value = target;
      return;
    }
    _amplitude.animateTo(
      target,
      duration: M3WavyLinearProgress.amplitudeAnimationDuration,
      curve: _amplitude.value < target
          ? M3WavyLinearProgress.increasingAmplitudeEasing
          : M3WavyLinearProgress.decreasingAmplitudeEasing,
    );
  }

  /// Смещение волны в Compose крутится всегда, но применяется только при
  /// амплитуде больше нуля, поэтому тикер работает лишь пока волна видна.
  /// `TickerMode` глушит его за пределами видимого экрана.
  void _syncWaveTicker() {
    final bool shouldRun =
        !_reduceMotion &&
        _amplitude.value > 0 &&
        M3WavyLinearProgress.waveCycleDuration(
              M3WavyLinearProgress.wavelength,
              _waveSpeed,
            ) !=
            null;
    if (shouldRun && !_waveTicker.isActive) {
      _waveOffsetAtStart = _waveOffset.value;
      _waveTicker.start();
    } else if (!shouldRun && _waveTicker.isActive) {
      _waveTicker.stop();
    }
  }

  void _onWaveTick(Duration elapsed) {
    final Duration? cycle = M3WavyLinearProgress.waveCycleDuration(
      M3WavyLinearProgress.wavelength,
      _waveSpeed,
    );
    if (cycle == null) return;
    _waveOffset.value =
        (_waveOffsetAtStart + elapsed.inMicroseconds / cycle.inMicroseconds) %
        1;
  }

  @override
  void dispose() {
    _waveTicker.dispose();
    _waveOffset.dispose();
    _amplitude.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double target = _coerce(widget.value);

    return Semantics(
      label: widget.semanticsLabel,
      role: SemanticsRole.progressBar,
      minValue: '0',
      maxValue: '100',
      value: '${(target * 100).round()}',
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.hasBoundedWidth
              ? double.infinity
              : M3WavyLinearProgress.containerWidth,
          height: M3WavyLinearProgress.height,
          child: ClipRect(
            child: CustomPaint(
              painter: WavyLinearProgressPainter(
                progress: _progress,
                amplitude: _amplitude,
                waveOffset: _waveOffset,
                color: widget.color ?? colors.primary,
                trackColor: widget.showTrack
                    ? (widget.trackColor ?? colors.secondaryContainer)
                    : null,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Размеры определённой шкалы по `LinearProgressDrawingCache.updateDrawPaths`
/// и `drawStopIndicator` (для пары долей `[0, progress]`).
@immutable
class LinearWavyProgressGeometry {
  const LinearWavyProgressGeometry._({
    required this.capWidth,
    required this.barHead,
    required this.activeStart,
    required this.activeEnd,
    required this.hasActiveIndicator,
    required this.trackGap,
    required this.trackStart,
    required this.trackEnd,
    required this.stopIndicatorSize,
    required this.stopIndicatorX,
  });

  /// Расчёт для области [width] × [height] и прогресса [progress].
  factory LinearWavyProgressGeometry.compute({
    required double width,
    required double height,
    required double progress,
    double stroke = M3WavyLinearProgress.thickness,
    double trackStroke = M3WavyLinearProgress.trackThickness,
    double gapSize = M3WavyLinearProgress.trackGap,
    double stopSize = M3WavyLinearProgress.stopIndicatorSize,
  }) {
    final double p = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);

    // `currentStrokeCapWidth`: у круглых концов — половина толщины, если
    // шкала не выше своей ширины.
    final double cap = height > width
        ? 0
        : math.max(stroke / 2, trackStroke / 2);

    const double barTail = 0;
    final double barHead = p * width;

    // Зазор сужается, пока голова только входит на трек.
    final double adjustedGap = barHead < cap
        ? 0
        : math.min(barHead - cap, gapSize);
    final bool activeVisible = barHead >= cap;

    final double adjustedHead = barHead.clamp(cap, math.max(cap, width - cap));
    final double adjustedTail = barTail.clamp(cap, math.max(cap, width - cap));

    final double spacing = activeVisible ? adjustedGap + cap * 2 : adjustedGap;
    final double nextEnd = width - cap;
    final double trackStart = math.max(cap, adjustedHead + spacing);
    final bool hasTrack = nextEnd > adjustedHead + spacing;

    // `drawStopIndicator`.
    double stopIndicatorSize = math.min(trackStroke, stopSize);
    final double indicatorXOffset = stopIndicatorSize == trackStroke
        ? 0
        : trackStroke / 4;
    double indicatorX = width - stopIndicatorSize - indicatorXOffset;
    final double progressX = width * p + cap;
    if (indicatorX <= progressX) {
      stopIndicatorSize = math.max(
        0,
        stopIndicatorSize - (progressX - indicatorX),
      );
      indicatorX = progressX;
    }

    return LinearWavyProgressGeometry._(
      capWidth: cap,
      barHead: barHead,
      activeStart: adjustedTail,
      activeEnd: adjustedHead,
      hasActiveIndicator: p > 0,
      trackGap: adjustedGap,
      trackStart: hasTrack ? trackStart : null,
      trackEnd: nextEnd,
      stopIndicatorSize: stopIndicatorSize,
      stopIndicatorX: indicatorX,
    );
  }

  /// `currentStrokeCapWidth`.
  final double capWidth;

  /// `barHead = progress × width` без ограничений.
  final double barHead;

  /// Начало и конец активной части (`adjustedBarTail` / `adjustedBarHead`),
  /// зажаты в `[cap, width − cap]`.
  final double activeStart;
  final double activeEnd;

  /// Активная часть рисуется, только если прогресс больше нуля.
  final bool hasActiveIndicator;

  /// `adjustedTrackGapSize`.
  final double trackGap;

  /// Начало трека после активной части и зазора; `null` — трека не видно.
  final double? trackStart;

  /// Конец трека: `width − cap`.
  final double trackEnd;

  /// Диаметр stop indicator; уменьшается, когда голова его догоняет.
  final double stopIndicatorSize;

  /// Левый край stop indicator.
  final double stopIndicatorX;
}

/// Отрисовка из `DeterminateLinearWavyProgressNode` и
/// `LinearProgressDrawingCache`.
@visibleForTesting
class WavyLinearProgressPainter extends CustomPainter {
  WavyLinearProgressPainter({
    required this.progress,
    required this.amplitude,
    required this.waveOffset,
    required this.color,
    required this.trackColor,
    required this.textDirection,
  }) : super(repaint: Listenable.merge([progress, amplitude, waveOffset]));

  /// Отображаемый (анимированный) прогресс.
  final ValueListenable<double> progress;

  /// Доля амплитуды 0..1.
  final ValueListenable<double> amplitude;

  /// Смещение волны, доля длины волны.
  final ValueListenable<double> waveOffset;

  final Color color;

  /// `null` — трек убран.
  final Color? trackColor;

  final TextDirection textDirection;

  // Кэш полного пути (`updateFullPaths`): пересчитывается при смене размера
  // и когда амплитуда становится нулевой или ненулевой.
  Size? _cachedSize;
  bool? _cachedFlat;
  PathMetric? _metric;
  double _progressPathScale = 1;

  void _updateFullPath(Size size, bool flat) {
    if (_cachedSize == size && _cachedFlat == flat && _metric != null) return;
    final double width = size.width;
    final double height = size.height;
    final Path full = Path()..moveTo(0, 0);
    if (flat) {
      full.lineTo(width, 0);
    } else {
      const double wavelength = M3WavyLinearProgress.wavelength;
      const double halfWavelength = wavelength / 2;
      double anchorX = halfWavelength;
      const double anchorY = 0;
      double controlX = halfWavelength / 2;
      // Высота контрольной точки квадратичной кривой: пик волны — половина.
      double controlY = height - M3WavyLinearProgress.thickness;
      final double widthWithExtraPhase = width + wavelength * 2;
      while (anchorX <= widthWithExtraPhase) {
        full.quadraticBezierTo(controlX, controlY, anchorX, anchorY);
        anchorX += halfWavelength;
        controlX += halfWavelength;
        controlY *= -1;
      }
    }
    final Path shifted = full.shift(Offset(0, height / 2));
    final Iterator<PathMetric> metrics = shifted.computeMetrics().iterator;
    _metric = metrics.moveNext() ? metrics.current : null;
    _progressPathScale =
        (_metric?.length ?? 0) / (shifted.getBounds().width + 0.00000001);
    _cachedSize = size;
    _cachedFlat = flat;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double width = size.width;
    final double height = size.height;
    final double currentAmplitude = amplitude.value.clamp(0.0, 1.0);
    final double offset = currentAmplitude > 0 ? waveOffset.value : 0;
    final LinearWavyProgressGeometry geometry =
        LinearWavyProgressGeometry.compute(
          width: width,
          height: height,
          progress: progress.value,
        );

    // `rotate(if (Ltr) 0f else 180f)` вокруг центра.
    if (textDirection == TextDirection.rtl) {
      canvas.translate(width / 2, height / 2);
      canvas.rotate(math.pi);
      canvas.translate(-width / 2, -height / 2);
    }

    Paint stroke(Color c, double strokeWidth) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Трек: от головы с зазором до `width − cap`.
    if (trackColor != null && geometry.trackStart != null) {
      canvas.drawLine(
        Offset(geometry.trackEnd, height / 2),
        Offset(geometry.trackStart!, height / 2),
        stroke(trackColor!, M3WavyLinearProgress.trackThickness),
      );
    }

    // Активная часть: отрезок полного пути, сдвинутый на фазу и сжатый по
    // вертикали до текущей амплитуды.
    if (geometry.hasActiveIndicator) {
      _updateFullPath(size, currentAmplitude == 0);
      final PathMetric? metric = _metric;
      if (metric != null) {
        final double waveShift = currentAmplitude != 0
            ? offset * M3WavyLinearProgress.wavelength
            : 0;
        final Path segment = metric.extractPath(
          (geometry.activeStart + waveShift) * _progressPathScale,
          (geometry.activeEnd + waveShift) * _progressPathScale,
        );
        final Matrix4 matrix = Matrix4.diagonal3Values(1, currentAmplitude, 1)
          ..setTranslationRaw(
            waveShift > 0 ? -waveShift : 0,
            (1 - currentAmplitude) * height / 2,
            0,
          );
        canvas.drawPath(
          segment.transform(matrix.storage),
          stroke(color, M3WavyLinearProgress.thickness),
        );
      }
    }

    // Stop indicator: круг у правого края трека. Он часть трека — без трека
    // (индикатор внутри компонента) не рисуется: иначе остаётся одинокая
    // точка, которая ничего не обозначает.
    if (geometry.stopIndicatorSize > 0 && trackColor != null) {
      canvas.drawCircle(
        Offset(
          geometry.stopIndicatorX + geometry.stopIndicatorSize / 2,
          height / 2,
        ),
        geometry.stopIndicatorSize / 2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(WavyLinearProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.waveOffset != waveOffset ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.textDirection != textDirection;
  }
}
