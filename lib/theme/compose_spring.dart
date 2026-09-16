import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Пружина с семантикой завершения из Compose animation-core.
///
/// Flutter считает [SpringSimulation] законченной, когда положение и скорость
/// оба попали в [Tolerance]. Compose поступает иначе: `FloatSpringSpec`
/// заранее оценивает длительность функцией `estimateAnimationDurationMillis`
/// (порог — `visibilityThreshold`), до этого момента отдаёт аналитическое
/// решение `SpringSimulation.updateValues`, а в момент завершения
/// `TargetBasedAnimation` ставит ровно целевое значение.
///
/// Порт нужен там, где момент завершения влияет на поведение: в
/// `LoadingIndicator` по завершении морфа меняется форма, в
/// `PullToRefreshModifierNode` протяжка не принимается, пока
/// `Animatable.isRunning`.
///
/// Источники (androidx-main, `compose/animation/animation-core`):
/// `FloatAnimationSpec.kt` (`FloatSpringSpec`), `SpringSimulation.kt`,
/// `SpringEstimation.kt`, `AnimationSpec.kt` (`spring()`).
class ComposeSpringSimulation extends Simulation {
  ComposeSpringSimulation({
    required this.dampingRatio,
    required this.stiffness,
    this.visibilityThreshold = defaultDisplacementThreshold,
    required this.start,
    required this.end,
    this.velocity = 0,
  }) : duration = estimateDuration(
         dampingRatio: dampingRatio,
         stiffness: stiffness,
         visibilityThreshold: visibilityThreshold,
         start: start,
         end: end,
         velocity: velocity,
       );

  /// `Spring.DefaultDisplacementThreshold` — порог по умолчанию у
  /// `Animatable(0f)` и у `spring()` без `visibilityThreshold`.
  static const double defaultDisplacementThreshold = 0.01;

  /// `Spring.StiffnessMedium` — жёсткость `spring()` по умолчанию.
  static const double stiffnessMedium = 1500;

  /// `Spring.DampingRatioNoBouncy` — демпфирование `spring()` по умолчанию.
  static const double dampingRatioNoBouncy = 1;

  final double dampingRatio;
  final double stiffness;
  final double visibilityThreshold;
  final double start;
  final double end;
  final double velocity;

  /// Длительность, после которой анимация завершена и стоит в [end].
  final Duration duration;

  double get _durationSeconds =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  double x(double time) => isDone(time) ? end : _solve(time < 0 ? 0 : time).$1;

  @override
  double dx(double time) => isDone(time) ? 0 : _solve(time < 0 ? 0 : time).$2;

  @override
  bool isDone(double time) => time >= _durationSeconds;

  /// `FloatSpringSpec.getDurationNanos`: смещение и скорость делятся на порог,
  /// затем `estimateAnimationDurationMillis(..., delta = 1)`.
  static Duration estimateDuration({
    required double dampingRatio,
    required double stiffness,
    double visibilityThreshold = defaultDisplacementThreshold,
    required double start,
    required double end,
    double velocity = 0,
  }) {
    return Duration(
      milliseconds: estimateAnimationDurationMillis(
        stiffness: stiffness,
        dampingRatio: dampingRatio,
        initialVelocity: velocity / visibilityThreshold,
        initialDisplacement: (start - end) / visibilityThreshold,
        delta: 1,
      ),
    );
  }

  /// `SpringSimulation.updateValues` (масса 1): положение и скорость.
  (double, double) _solve(double t) {
    final double naturalFreq = math.sqrt(stiffness);
    final double adjustedDisplacement = start - end;
    final double r = -dampingRatio * naturalFreq;
    final double displacement;
    final double currentVelocity;

    if (dampingRatio > 1) {
      final double s = naturalFreq * math.sqrt(dampingRatio * dampingRatio - 1);
      final double gammaPlus = r + s;
      final double gammaMinus = r - s;
      final double coeffB =
          (gammaMinus * adjustedDisplacement - velocity) /
          (gammaMinus - gammaPlus);
      final double coeffA = adjustedDisplacement - coeffB;
      displacement =
          coeffA * math.exp(gammaMinus * t) + coeffB * math.exp(gammaPlus * t);
      currentVelocity =
          coeffA * gammaMinus * math.exp(gammaMinus * t) +
          coeffB * gammaPlus * math.exp(gammaPlus * t);
    } else if (dampingRatio == 1) {
      final double coeffA = adjustedDisplacement;
      final double coeffB = velocity + naturalFreq * adjustedDisplacement;
      final double nFdT = -naturalFreq * t;
      displacement = (coeffA + coeffB * t) * math.exp(nFdT);
      currentVelocity =
          (coeffA + coeffB * t) * math.exp(nFdT) * -naturalFreq +
          coeffB * math.exp(nFdT);
    } else {
      final double dampedFreq =
          naturalFreq * math.sqrt(1 - dampingRatio * dampingRatio);
      final double cosCoeff = adjustedDisplacement;
      final double sinCoeff =
          (1 / dampedFreq) * (-r * adjustedDisplacement + velocity);
      final double dFdT = dampedFreq * t;
      displacement =
          math.exp(r * t) *
          (cosCoeff * math.cos(dFdT) + sinCoeff * math.sin(dFdT));
      currentVelocity =
          displacement * r +
          math.exp(r * t) *
              (-dampedFreq * cosCoeff * math.sin(dFdT) +
                  dampedFreq * sinCoeff * math.cos(dFdT));
    }
    return (displacement + end, currentVelocity);
  }
}

/// `estimateAnimationDurationMillis(stiffness, dampingRatio, ...)` из
/// `SpringEstimation.kt`: время, когда пружина в последний раз находится на
/// расстоянии [delta] от цели, в целых миллисекундах.
int estimateAnimationDurationMillis({
  required double stiffness,
  required double dampingRatio,
  required double initialVelocity,
  required double initialDisplacement,
  required double delta,
}) {
  if (dampingRatio == 0) return _maxLongMillis;

  final double dampingCoefficient = 2.0 * dampingRatio * math.sqrt(stiffness);
  final double partialRoot =
      dampingCoefficient * dampingCoefficient - 4.0 * stiffness;
  final double partialRootReal = partialRoot < 0.0
      ? 0.0
      : math.sqrt(partialRoot);
  final double partialRootImaginary = partialRoot < 0.0
      ? math.sqrt(partialRoot.abs())
      : 0.0;

  final double firstRootReal = (-dampingCoefficient + partialRootReal) * 0.5;
  final double firstRootImaginary = partialRootImaginary * 0.5;
  final double secondRootReal = (-dampingCoefficient - partialRootReal) * 0.5;

  if (initialDisplacement == 0.0 && initialVelocity == 0.0) return 0;

  final double v0 = initialDisplacement < 0
      ? -initialVelocity
      : initialVelocity;
  final double p0 = initialDisplacement.abs();

  final double seconds;
  if (dampingRatio > 1.0) {
    seconds = _estimateOverDamped(firstRootReal, secondRootReal, p0, v0, delta);
  } else if (dampingRatio < 1.0) {
    seconds = _estimateUnderDamped(
      firstRootReal,
      firstRootImaginary,
      p0,
      v0,
      delta,
    );
  } else {
    seconds = _estimateCriticallyDamped(firstRootReal, p0, v0, delta);
  }
  // `(... * 1000.0).toLong()`: дробная часть отбрасывается, NaN даёт 0,
  // бесконечность — максимум.
  final double millis = seconds * 1000.0;
  if (millis.isNaN) return 0;
  if (millis.isInfinite) return millis > 0 ? _maxLongMillis : -_maxLongMillis;
  return millis.truncate();
}

/// `MAX_LONG_MILLIS` из `SpringEstimation.kt`.
const int _maxLongMillis = 9223372036854;

/// Недодемпфированная пружина: огибающая `c·e^(r·t)`.
double _estimateUnderDamped(
  double firstRootReal,
  double firstRootImaginary,
  double p0,
  double v0,
  double delta,
) {
  final double r = firstRootReal;
  final double c1 = p0;
  final double c2 = (v0 - r * c1) / firstRootImaginary;
  final double c = math.sqrt(c1 * c1 + c2 * c2);
  return math.log(delta / c) / r;
}

/// Критическое демпфирование: метод Ньютона для `(c1 + c2·t)·e^(r·t) = delta`.
double _estimateCriticallyDamped(
  double firstRootReal,
  double p0,
  double v0,
  double delta,
) {
  final double r = firstRootReal;
  final double c1 = p0;
  final double c2 = v0 - r * c1;

  final double t1 = math.log((delta / c1).abs()) / r;
  final double t2 =
      () {
        final double guess = math.log((delta / c2).abs());
        double t = guess;
        for (int i = 0; i <= 5; i++) {
          t = guess - math.log((t / r).abs());
        }
        return t;
      }() /
      r;
  double tCurr = !t1.isFinite
      ? t2
      : !t2.isFinite
      ? t1
      : math.max(t1, t2);

  final double tInflection = -(r * c1 + c2) / (r * c2);
  final double xInflection =
      c1 * math.exp(r * tInflection) +
      c2 * tInflection * math.exp(r * tInflection);

  final double signedDelta;
  if (tInflection.isNaN || tInflection <= 0.0) {
    signedDelta = -delta;
  } else if (tInflection > 0.0 && -xInflection < delta) {
    if (c2 < 0 && c1 > 0) tCurr = 0.0;
    signedDelta = -delta;
  } else {
    tCurr = -(2.0 / r) - (c1 / c2);
    signedDelta = delta;
  }

  double tDelta = double.maxFinite;
  int iterations = 0;
  while (tDelta > 0.001 && iterations < 100) {
    iterations++;
    final double tLast = tCurr;
    tCurr = _iterateNewtonsMethod(
      tCurr,
      (t) => (c1 + c2 * t) * math.exp(r * t) + signedDelta,
      (t) => (c2 * (r * t + 1) + c1 * r) * math.exp(r * t),
    );
    tDelta = (tLast - tCurr).abs();
  }
  return tCurr;
}

/// Передемпфированная пружина: метод Ньютона для
/// `c1·e^(r1·t) + c2·e^(r2·t) = delta`.
double _estimateOverDamped(
  double firstRootReal,
  double secondRootReal,
  double p0,
  double v0,
  double delta,
) {
  final double r1 = firstRootReal;
  final double r2 = secondRootReal;
  final double c2 = (r1 * p0 - v0) / (r1 - r2);
  final double c1 = p0 - c2;

  final double t1 = math.log((delta / c1).abs()) / r1;
  final double t2 = math.log((delta / c2).abs()) / r2;
  double tCurr = !t1.isFinite
      ? t2
      : !t2.isFinite
      ? t1
      : math.max(t1, t2);

  final double tInflection = math.log((c1 * r1) / (-c2 * r2)) / (r2 - r1);
  double xInflection() =>
      c1 * math.exp(r1 * tInflection) + c2 * math.exp(r2 * tInflection);

  final double signedDelta;
  if (tInflection.isNaN || tInflection <= 0.0) {
    signedDelta = -delta;
  } else if (tInflection > 0.0 && -xInflection() < delta) {
    if (c2 > 0.0 && c1 < 0.0) tCurr = 0.0;
    signedDelta = -delta;
  } else {
    tCurr = math.log(-(c2 * r2 * r2) / (c1 * r1 * r1)) / (r1 - r2);
    signedDelta = delta;
  }

  if ((c1 * r1 * math.exp(r1 * tCurr) + c2 * r2 * math.exp(r2 * tCurr)).abs() <
      0.0001) {
    return tCurr;
  }
  double tDelta = double.maxFinite;
  int iterations = 0;
  while (tDelta > 0.001 && iterations < 100) {
    iterations++;
    final double tLast = tCurr;
    tCurr = _iterateNewtonsMethod(
      tCurr,
      (t) => c1 * math.exp(r1 * t) + c2 * math.exp(r2 * t) + signedDelta,
      (t) => c1 * r1 * math.exp(r1 * t) + c2 * r2 * math.exp(r2 * t),
    );
    tDelta = (tLast - tCurr).abs();
  }
  return tCurr;
}

double _iterateNewtonsMethod(
  double x,
  double Function(double) fn,
  double Function(double) fnPrime,
) => x - fn(x) / fnPrime(x);
