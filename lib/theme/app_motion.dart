import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Токены движения Material 3 Expressive.
///
/// M3 Expressive описывает движение пружинами, а не кривыми Безье:
/// https://m3.material.io/styles/motion/overview/specs
///
/// Правило применения:
///   * позиция / размер / форма  -> *spatial* (есть перелёт, damping ratio < 1);
///   * цвет / прозрачность       -> *effects* (без перелёта, damping ratio = 1).
///
/// Flutter 3.44 ещё не поставляет `MotionScheme`/`MotionTheme` из коробки
/// (проверено: `packages/flutter/lib/src/material/motion.dart` содержит только
/// `Durations` и `Easing`), поэтому пружины заданы здесь вручную.
abstract final class AppMotion {
  /// Быстрые деформации: переключение чипов и дней.
  static final M3Spring fastSpatial = M3Spring._(
    stiffness: 800,
    dampingRatio: 0.6,
  );

  /// Стандартные перемещения: боттом-шит, морфинг карточки.
  static final M3Spring defaultSpatial = M3Spring._(
    stiffness: 380,
    dampingRatio: 0.8,
  );

  /// Крупные перестроения.
  static final M3Spring slowSpatial = M3Spring._(
    stiffness: 200,
    dampingRatio: 0.8,
  );

  /// Быстрые изменения цвета и прозрачности.
  static final M3Spring fastEffects = M3Spring._(
    stiffness: 3800,
    dampingRatio: 1.0,
  );

  /// Цвет, прозрачность, ripple.
  static final M3Spring defaultEffects = M3Spring._(
    stiffness: 1600,
    dampingRatio: 1.0,
  );

  /// Медленные затухания.
  static final M3Spring slowEffects = M3Spring._(
    stiffness: 800,
    dampingRatio: 1.0,
  );
}

/// Пружинный токен: описание пружины + производные от неё [duration] и [curve].
///
/// [curve] позволяет использовать пружинное движение в неявных анимациях
/// (`AnimatedContainer`, `AnimatedAlign`, ...), которые принимают только пару
/// «кривая + длительность». Кривая — это сама симуляция пружины,
/// нормированная на её же время затухания, то есть перелёт сохраняется.
class M3Spring {
  M3Spring._({required this.stiffness, required this.dampingRatio})
    : description = SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: stiffness,
        ratio: dampingRatio,
      );

  final double stiffness;
  final double dampingRatio;
  final SpringDescription description;

  /// Время, за которое пружина фактически успокаивается.
  late final Duration duration = Duration(
    microseconds: (_settlingTime * Duration.microsecondsPerSecond).round(),
  );

  /// Пружина в виде [Curve] для неявных анимаций.
  late final Curve curve = SpringCurve(
    description,
    settlingTime: _settlingTime,
  );

  /// Симуляция для явного управления через `AnimationController.animateWith`.
  SpringSimulation simulate({
    double from = 0,
    double to = 1,
    double velocity = 0,
  }) => SpringSimulation(description, from, to, velocity);

  late final double _settlingTime = _computeSettlingTime(description);

  /// Численно находит момент, когда пружина 0 -> 1 считается завершённой.
  static double _computeSettlingTime(SpringDescription spring) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    const double step = 1 / 1000;
    const double maxTime = 3.0;
    for (double t = step; t < maxTime; t += step) {
      if (simulation.isDone(t)) return t;
    }
    return maxTime;
  }
}

/// [Curve], воспроизводящая заданную пружину.
///
/// Аналог CSS-функции `linear(...)` из макета, но вместо предпосчитанных
/// 35 точек здесь считается сама симуляция, поэтому перелёт точный.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {required this.settlingTime})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final double settlingTime;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    if (t >= 1.0) return 1.0;
    return _simulation.x(t * settlingTime);
  }

  @override
  String toString() => 'SpringCurve(stiffness: ${spring.stiffness})';
}
