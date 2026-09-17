import 'package:flutter/material.dart';

/// Паттерны переходов Material motion.
///
/// https://m3.material.io/styles/motion/transitions/transition-patterns
///
/// Сами паттерны описаны в MDC `docs/theming/Motion.md`: fade through — для
/// пунктов navigation bar, shared axis X — для шагов одного потока,
/// container transform — карточка → подробности. Числа взяты не из этого
/// документа (его таблицы остались от M2), а из исходников классов
/// `com.google.android.material.transition` и M3-темы, где они и применяются:
///
/// | Класс | Длительность | Кривая |
/// |---|---|---|
/// | `MaterialSharedAxis` | `motionDurationLong1` = 450 мс | `motionEasingEmphasizedInterpolator` |
/// | `MaterialFadeThrough` | `motionDurationLong1` = 450 мс | `motionEasingEmphasizedInterpolator` |
/// | `MaterialContainerTransform` | вход `motionDurationLong2` = 500 мс, возврат `motionDurationMedium4` = 400 мс | emphasized |
///
/// Длительности — `m3_sys_motion_duration_*` из `motion/res/values/tokens.xml`.
abstract final class AppTransitions {
  /// `MaterialSharedAxis.DEFAULT_THEMED_DURATION_ATTR`.
  static const Duration sharedAxisDuration = Duration(milliseconds: 450);

  /// `MaterialFadeThrough.DEFAULT_THEMED_DURATION_ATTR`.
  static const Duration fadeThroughDuration = Duration(milliseconds: 450);

  /// `MaterialContainerTransform`, открытие. У `OpenContainer` из
  /// package:animations одна длительность на оба направления.
  static const Duration containerTransformDuration = Duration(
    milliseconds: 500,
  );

  /// `m3_sys_motion_easing_emphasized`:
  /// `M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1` —
  /// во Flutter это ровно [Curves.easeInOutCubicEmphasized].
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// `mtrl_transition_shared_axis_slide_distance`.
  static const double sharedAxisSlideDistance = 30;

  /// `FadeThroughProvider.FADE_THROUGH_THRESHOLD`: уходящий экран гаснет до
  /// этой доли, приходящий проявляется после неё.
  static const double fadeThroughThreshold = 0.35;

  /// `MaterialFadeThrough.DEFAULT_START_SCALE`.
  static const double fadeThroughStartScale = 0.92;
}

/// Прогресс перехода в интерполированном виде, как в MDC: кривая перехода
/// применяется к доле времени, а пороги прозрачности — уже к результату
/// (`TransitionUtils.lerp` в `FadeThroughProvider`).
Animation<double> _emphasized(Animation<double> linear) =>
    linear.drive(CurveTween(curve: AppTransitions.emphasized));

/// Прозрачность приходящего экрана: 0 до порога, затем линейно до 1.
double _fadeIn(double t) =>
    ((t - AppTransitions.fadeThroughThreshold) /
            (1 - AppTransitions.fadeThroughThreshold))
        .clamp(0.0, 1.0);

/// Прозрачность уходящего экрана: от 1 до 0 к порогу.
double _fadeOut(double t) =>
    1 - (t / AppTransitions.fadeThroughThreshold).clamp(0.0, 1.0);

/// Shared axis по оси X — порт `MaterialSharedAxis(X, forward)`.
///
/// Вперёд: приходящий экран въезжает справа на 30dp, уходящий смещается
/// влево; прозрачность — как у fade through. Назад — зеркально.
///
/// Подходит для [PageTransitionSwitcher] из package:animations: вперёд —
/// `reverse: false`, назад — `reverse: true`.
class M3SharedAxisTransition extends StatelessWidget {
  const M3SharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Схема как у SharedAxisTransition в package:animations: основная
    // анимация вперёд — вход, назад — выход; вторичная — наоборот.
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) =>
          _SharedAxisEnter(progress: animation, forward: true, child: child),
      reverseBuilder: (context, animation, child) =>
          _SharedAxisExit(progress: animation, forward: false, child: child),
      child: DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (context, animation, child) =>
            _SharedAxisEnter(progress: animation, forward: false, child: child),
        reverseBuilder: (context, animation, child) =>
            _SharedAxisExit(progress: animation, forward: true, child: child),
        child: child,
      ),
    );
  }
}

class _SharedAxisEnter extends StatelessWidget {
  const _SharedAxisEnter({
    required this.progress,
    required this.forward,
    required this.child,
  });

  /// 0 → 1 по времени перехода.
  final Animation<double> progress;
  final bool forward;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> t = _emphasized(progress);
    // SlideDistanceProvider: Gravity.END при forward, START — назад.
    final double sign =
        (forward ? 1 : -1) *
        (Directionality.of(context) == TextDirection.rtl ? -1 : 1);

    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: _fadeIn(t.value),
        child: Transform.translate(
          offset: Offset(
            sign * AppTransitions.sharedAxisSlideDistance * (1 - t.value),
            0,
          ),
          child: child,
        ),
      ),
      child: RepaintBoundary(child: child),
    );
  }
}

class _SharedAxisExit extends StatelessWidget {
  const _SharedAxisExit({
    required this.progress,
    required this.forward,
    required this.child,
  });

  final Animation<double> progress;
  final bool forward;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> t = _emphasized(progress);
    final double sign =
        (forward ? -1 : 1) *
        (Directionality.of(context) == TextDirection.rtl ? -1 : 1);

    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => IgnorePointer(
        ignoring: t.value > 0,
        child: Opacity(
          opacity: _fadeOut(t.value),
          child: Transform.translate(
            offset: Offset(
              sign * AppTransitions.sharedAxisSlideDistance * t.value,
              0,
            ),
            child: child,
          ),
        ),
      ),
      child: RepaintBoundary(child: child),
    );
  }
}

/// Fade through — порт `MaterialFadeThrough`.
///
/// Уходящий экран гаснет за первые 35% интерполированного прогресса,
/// приходящий проявляется в оставшиеся и одновременно растёт с 92% до 100%
/// (`ScaleProvider`, `scaleOnDisappear = false` — уходящий не масштабируется).
class M3FadeThroughTransition extends StatelessWidget {
  const M3FadeThroughTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) =>
          M3FadeThroughEnter(progress: animation, child: child),
      reverseBuilder: (context, animation, child) =>
          M3FadeThroughExit(progress: animation, child: child),
      child: DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (context, animation, child) =>
            M3FadeThroughEnter(progress: animation, child: child),
        reverseBuilder: (context, animation, child) =>
            M3FadeThroughExit(progress: animation, child: child),
        child: child,
      ),
    );
  }
}

/// Появление в fade through; [progress] идёт 0 → 1 по времени.
class M3FadeThroughEnter extends StatelessWidget {
  const M3FadeThroughEnter({
    super.key,
    required this.progress,
    required this.child,
  });

  final Animation<double> progress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> t = _emphasized(progress);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: _fadeIn(t.value),
        child: Transform.scale(
          scale:
              AppTransitions.fadeThroughStartScale +
              (1 - AppTransitions.fadeThroughStartScale) * t.value,
          child: child,
        ),
      ),
      // Масштаб меняется каждый кадр: экран рисуется один раз в свой слой.
      child: RepaintBoundary(child: child),
    );
  }
}

/// Исчезновение в fade through; [progress] идёт 0 → 1 по времени.
class M3FadeThroughExit extends StatelessWidget {
  const M3FadeThroughExit({
    super.key,
    required this.progress,
    required this.child,
  });

  final Animation<double> progress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> t = _emphasized(progress);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => IgnorePointer(
        ignoring: t.value > 0,
        child: Opacity(opacity: _fadeOut(t.value), child: child),
      ),
      child: child,
    );
  }
}
