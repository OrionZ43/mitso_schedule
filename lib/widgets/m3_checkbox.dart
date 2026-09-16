import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_motion.dart';
import '../theme/app_state_layer.dart';
import 'm3_radial_ink.dart';

/// Чекбокс Material 3 Expressive — порт Compose `Checkbox` / `TriStateCheckbox`.
///
/// Источники:
///   * https://m3.material.io/components/checkbox/specs — токены и размеры
///     (выгрузка `.m3-guidelines/components__checkbox.md`);
///   * Compose `Checkbox.kt` (`CheckboxImpl`, `drawBox`, `drawCheck`,
///     `CheckDrawingCache`, `colorAnimationSpecForState`, `SnapAnimationDelay`)
///     и `tokens/CheckboxTokens.kt`. Геометрия — ветка
///     `ComposeMaterial3Flags.isCheckboxStylingFixEnabled` («Material Design 3
///     styling»): контейнер 18dp без внутренних полей, галочка
///     (0.25, 0.5) → (0.4, 0.65) → (0.75, 0.3).
///
/// Flutter `Checkbox` переключается за 200 мс `easeIn`/`easeOut` без пружин.
/// Здесь, как в Compose:
///   * прорисовка галочки при включении — пружина `DefaultSpatial`;
///   * при выключении галочка пропадает мгновенно через 100 мс
///     (`snap(delayMillis = SnapAnimationDelay)`), пока её цвет гаснет;
///   * галочка ↔ черта неопределённого состояния — `DefaultSpatial`;
///   * цвета — пружина `DefaultEffects` к выбранному состоянию и `FastEffects`
///     к невыбранному, в пространстве Oklab (`Color.VectorConverter`);
///     у недоступного чекбокса фон и обводка меняются без анимации;
///   * ripple неограниченный, радиус 20dp.
///
/// [tristate]: `null` — неопределённое состояние. Нажатие по нему выбирает
/// чекбокс: «Checking an indeterminate checkbox checks all child items»
/// (Guidelines → Behavior). Цикл: `false` → `true`, `null` → `true`,
/// `true` → `false`.
class M3Checkbox extends StatefulWidget {
  const M3Checkbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.isError = false,
    this.focusNode,
    this.autofocus = false,
  }) : assert(tristate || value != null);

  final bool? value;

  /// `null` — чекбокс недоступен (disabled).
  final ValueChanged<bool?>? onChanged;

  final bool tristate;

  /// Error-вариант (`md.comp.checkbox.*.error.*`).
  final bool isError;

  final FocusNode? focusNode;
  final bool autofocus;

  /// `md.comp.checkbox.container.size`.
  static const double containerSize = 18;

  /// `md.comp.checkbox.container.shape` = 2dp.
  static const double cornerRadius = 2;

  /// `CheckboxDefaults.StrokeWidth`.
  static const double strokeWidth = 2;

  /// Зона нажатия (Specs → Measurements → Target size).
  static const double targetSize = 48;

  /// `SnapAnimationDelay`.
  static const Duration snapDelay = Duration(milliseconds: 100);

  @override
  State<M3Checkbox> createState() => M3CheckboxState();
}

enum _Toggle { on, off, indeterminate }

@visibleForTesting
class M3CheckboxState extends State<M3Checkbox> with TickerProviderStateMixin {
  late final AnimationController _checkDraw;
  late final AnimationController _gravitation;
  late final Ticker _colorTicker;
  final M3RadialInkController _ink = M3RadialInkController();

  late _Toggle _target;

  /// `Transition.currentState`: меняется, когда все анимации перехода
  /// закончились. От него зависит, какую спецификацию брать.
  late _Toggle _current;

  Timer? _snapTimer;

  _OklabSpring? _box;
  _OklabSpring? _border;
  _OklabSpring? _check;
  Duration _colorElapsed = Duration.zero;

  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;
  bool _reduceMotion = false;

  bool get _enabled => widget.onChanged != null;

  /// Доля прорисовки галочки (`checkDrawFraction`).
  @visibleForTesting
  double get checkFraction => _checkDraw.value;

  /// Сдвиг галочки к черте (`checkCenterGravitationShiftFraction`).
  @visibleForTesting
  double get gravitationFraction => _gravitation.value;

  /// Текущие цвета: фон, обводка, галочка.
  @visibleForTesting
  (Color box, Color border, Color check) get currentColors =>
      (_box!.value, _border!.value, _check!.value);

  static _Toggle _toggleOf(bool? value) => switch (value) {
    true => _Toggle.on,
    false => _Toggle.off,
    null => _Toggle.indeterminate,
  };

  @override
  void initState() {
    super.initState();
    _target = _toggleOf(widget.value);
    _current = _target;
    _checkDraw = AnimationController.unbounded(
      vsync: this,
      value: _target == _Toggle.off ? 0 : 1,
    )..addStatusListener(_handleTransitionStatus);
    _gravitation = AnimationController.unbounded(
      vsync: this,
      value: _target == _Toggle.indeterminate ? 1 : 0,
    )..addStatusListener(_handleTransitionStatus);
    _colorTicker = createTicker(_tickColors);
  }

  @override
  void didUpdateWidget(M3Checkbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
      _hovered = false;
      _focused = false;
    }
    final _Toggle next = _toggleOf(widget.value);
    if (next != _target) _startTransition(next);
    _ink.recolor(
      pressed: _stateLayer(WidgetState.pressed),
      hovered: _stateLayer(WidgetState.hovered),
      focused: _stateLayer(WidgetState.focused),
    );
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _checkDraw.dispose();
    _gravitation.dispose();
    _colorTicker.dispose();
    super.dispose();
  }

  // ---- Прорисовка галочки (`updateTransition(state)`) ----

  void _startTransition(_Toggle next) {
    final _Toggle initial = _current;
    _target = next;
    _snapTimer?.cancel();
    _snapTimer = null;

    final double drawTarget = next == _Toggle.off ? 0 : 1;
    final double gravitationTarget = next == _Toggle.indeterminate ? 1 : 0;

    if (next == _Toggle.off && initial != _Toggle.off) {
      // `snap(delayMillis = SnapAnimationDelay)` у обеих величин.
      _checkDraw.stop();
      _gravitation.stop();
      _snapTimer = Timer(M3Checkbox.snapDelay, () {
        _snapTimer = null;
        if (!mounted) return;
        _checkDraw.value = drawTarget;
        _gravitation.value = gravitationTarget;
        _handleTransitionStatus(AnimationStatus.completed);
      });
      return;
    }

    // `initialState == Off` → DefaultSpatial для галочки, snap() для сдвига.
    _spring(_checkDraw, drawTarget);
    if (initial == _Toggle.off) {
      _gravitation.value = gravitationTarget;
    } else {
      _spring(_gravitation, gravitationTarget);
    }
    _handleTransitionStatus(AnimationStatus.completed);
  }

  void _spring(AnimationController controller, double target) {
    if (_reduceMotion) {
      controller.value = target;
      return;
    }
    if (controller.value == target && controller.velocity == 0) return;
    controller.animateWith(
      SpringSimulation(
        AppMotion.defaultSpatial.description,
        controller.value,
        target,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  void _handleTransitionStatus(AnimationStatus _) {
    if (_snapTimer == null &&
        !_checkDraw.isAnimating &&
        !_gravitation.isAnimating) {
      _current = _target;
    }
  }

  // ---- Цвета (`animateColorAsState`) ----

  void _updateColors(_CheckboxColors colors) {
    if (_box == null) {
      _box = _OklabSpring(colors.box);
      _border = _OklabSpring(colors.border);
      _check = _OklabSpring(colors.check);
      return;
    }
    // `colorAnimationSpecForState`: к Off — FastEffects, иначе DefaultEffects.
    final M3Spring spring = _target == _Toggle.off
        ? AppMotion.fastEffects
        : AppMotion.defaultEffects;
    if (!_colorTicker.isActive) _colorElapsed = Duration.zero;
    final Duration now = _colorElapsed;
    bool changed = _check!.animateTo(colors.check, spring, now);
    if (_enabled) {
      changed = _box!.animateTo(colors.box, spring, now) | changed;
      changed = _border!.animateTo(colors.border, spring, now) | changed;
    } else {
      // «If not enabled 'snap' to the disabled state».
      _box!.snapTo(colors.box);
      _border!.snapTo(colors.border);
    }
    if (changed && !_colorTicker.isActive) _colorTicker.start();
  }

  void _tickColors(Duration elapsed) {
    _colorElapsed = elapsed;
    final bool done =
        _box!.tick(elapsed) & _border!.tick(elapsed) & _check!.tick(elapsed);
    if (done) _colorTicker.stop();
    setState(() {});
  }

  // ---- Жесты ----

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
    _ink.press(_stateLayer(WidgetState.pressed));
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _pressed = false);
    _ink.release();
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
    _ink.cancel();
  }

  void _toggle() {
    final ValueChanged<bool?>? onChanged = widget.onChanged;
    if (onChanged == null) return;
    switch (widget.value) {
      case false:
      case null:
        onChanged(true);
      case true:
        onChanged(false);
    }
  }

  void _handleHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    _ink.hover(value: value, color: _stateLayer(WidgetState.hovered));
  }

  void _handleFocus(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
    _ink.focus(value: value, color: _stateLayer(WidgetState.focused));
  }

  /// `md.comp.checkbox.*.state-layer.color`: нажатие невыбранного — primary,
  /// выбранного — on-surface; наведение и фокус наоборот; ошибка — error.
  Color _stateLayer(WidgetState state) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final bool selected = widget.value != false;
    final Color content;
    if (widget.isError) {
      content = c.error;
    } else if (state == WidgetState.pressed) {
      content = selected ? c.onSurface : c.primary;
    } else {
      content = selected ? c.primary : c.onSurface;
    }
    return AppStateLayer.overlay(content).resolve({state}) ??
        Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = reduceMotionOf(context);
    _updateColors(
      _CheckboxColors.resolve(
        Theme.of(context).colorScheme,
        state: _target,
        enabled: _enabled,
        isError: widget.isError,
        interacted: _pressed || _hovered || _focused,
      ),
    );
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;

    final Widget body = SizedBox.square(
      dimension: M3Checkbox.targetSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_checkDraw, _gravitation]),
            builder: (context, _) => CustomPaint(
              size: const Size.square(M3Checkbox.containerSize),
              painter: _CheckboxPainter(
                boxColor: _box!.value,
                borderColor: _border!.value,
                checkColor: _check!.value,
                checkFraction: _checkDraw.value,
                gravitation: _gravitation.value,
                // `floor(CheckboxDefaults.StrokeWidth.toPx())`.
                strokeWidth:
                    (M3Checkbox.strokeWidth * dpr).floorToDouble() / dpr,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Center(child: M3RadialInkAnchor(controller: _ink)),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      checked: widget.value == true,
      mixed: widget.tristate ? widget.value == null : null,
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        onShowHoverHighlight: _handleHover,
        onShowFocusHighlight: _handleFocus,
        child: GestureDetector(
          excludeFromSemantics: !_enabled,
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? _handleTapDown : null,
          onTapUp: _enabled ? _handleTapUp : null,
          onTapCancel: _enabled ? _handleTapCancel : null,
          onTap: _enabled ? _toggle : null,
          child: body,
        ),
      ),
    );
  }
}

/// Цвета по `CheckboxDefaults.colors()` и токенам `md.comp.checkbox.*`.
///
/// Обводка невыбранного при нажатии, наведении и фокусе — `on-surface`
/// (`unselected.{pressed|hover|focus}.outline.color`); в `CheckboxColors`
/// Compose этих состояний нет.
class _CheckboxColors {
  const _CheckboxColors(this.box, this.border, this.check);

  final Color box;
  final Color border;
  final Color check;

  static _CheckboxColors resolve(
    ColorScheme c, {
    required _Toggle state,
    required bool enabled,
    required bool isError,
    required bool interacted,
  }) {
    final bool selected = state != _Toggle.off;
    if (!enabled) {
      final Color disabled = c.onSurface.withValues(alpha: 0.38);
      return selected
          ? _CheckboxColors(disabled, disabled, c.surface)
          : _CheckboxColors(Colors.transparent, disabled, c.surface);
    }
    if (selected) {
      final Color container = isError ? c.error : c.primary;
      return _CheckboxColors(
        container,
        container,
        isError ? c.onError : c.onPrimary,
      );
    }
    final Color outline = isError
        ? c.error
        : (interacted ? c.onSurface : c.onSurfaceVariant);
    return _CheckboxColors(Colors.transparent, outline, Colors.transparent);
  }
}

/// `drawBox` + `drawCheck` из `Checkbox.kt`.
class _CheckboxPainter extends CustomPainter {
  _CheckboxPainter({
    required this.boxColor,
    required this.borderColor,
    required this.checkColor,
    required this.checkFraction,
    required this.gravitation,
    required this.strokeWidth,
  });

  final Color boxColor;
  final Color borderColor;
  final Color checkColor;
  final double checkFraction;
  final double gravitation;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.width;
    const double radius = M3Checkbox.cornerRadius;

    // drawBox
    if (boxColor == borderColor) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(radius),
        ),
        Paint()..color = boxColor,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth,
            strokeWidth,
            side - strokeWidth * 2,
            side - strokeWidth * 2,
          ),
          Radius.circular(math.max(0, radius - strokeWidth)),
        ),
        Paint()..color = boxColor,
      );
      final double half = strokeWidth / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(half, half, side - strokeWidth, side - strokeWidth),
          Radius.circular(radius - half),
        ),
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    // drawCheck (isCheckboxStylingFixEnabled = true)
    if (checkFraction <= 0) return;
    const double checkCrossX = 0.4;
    const double checkCrossY = 0.65;
    const double leftX = 0.25;
    const double leftY = 0.5;
    const double rightX = 0.75;
    const double rightY = 0.3;

    final double crossX = lerpDouble(checkCrossX, 0.5, gravitation)!;
    final double crossY = lerpDouble(checkCrossY, 0.5, gravitation)!;
    final double gravitatedLeftY = lerpDouble(leftY, 0.5, gravitation)!;
    final double gravitatedRightY = lerpDouble(rightY, 0.5, gravitation)!;

    final Path checkPath = Path()
      ..moveTo(side * leftX, side * gravitatedLeftY)
      ..lineTo(side * crossX, side * crossY)
      ..lineTo(side * rightX, side * gravitatedRightY);

    final Path toDraw = Path();
    for (final metric in checkPath.computeMetrics()) {
      toDraw.addPath(
        metric.extractPath(0, metric.length * checkFraction),
        Offset.zero,
      );
    }
    canvas.drawPath(
      toDraw,
      Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) =>
      old.boxColor != boxColor ||
      old.borderColor != borderColor ||
      old.checkColor != checkColor ||
      old.checkFraction != checkFraction ||
      old.gravitation != gravitation ||
      old.strokeWidth != strokeWidth;
}

/// Пружинная анимация цвета в Oklab — как `animateColorAsState` с
/// `Color.VectorConverter` в Compose: четыре канала (alpha, L, a, b) идут
/// каждый своей пружиной и при смене цели сохраняют скорость.
class _OklabSpring {
  _OklabSpring(Color initial)
    : _value = initial,
      _goalColor = initial,
      _goal = _Oklab.fromColor(initial);

  Color _value;
  Color _goalColor;
  List<double> _goal;
  List<SpringSimulation>? _simulations;
  Duration _start = Duration.zero;

  Color get value => _value;

  /// Запускает пружину к [target] из текущего положения и скорости;
  /// `false`, если цель не изменилась. [now] — время тикера.
  bool animateTo(Color target, M3Spring spring, Duration now) {
    if (target == _goalColor) return false;
    final List<SpringSimulation>? running = _simulations;
    final double t = _seconds(now);
    final List<double> position = running == null
        ? _Oklab.fromColor(_value)
        : [for (final s in running) s.x(t)];
    final List<double> velocity = running == null
        ? const [0, 0, 0, 0]
        : [for (final s in running) s.dx(t)];
    _goalColor = target;
    _goal = _Oklab.fromColor(target);
    _start = now;
    _simulations = [
      for (int i = 0; i < 4; i++)
        SpringSimulation(
          spring.description,
          position[i],
          _goal[i],
          velocity[i],
          snapToEnd: true,
        ),
    ];
    return true;
  }

  void snapTo(Color target) {
    _simulations = null;
    _goalColor = target;
    _goal = _Oklab.fromColor(target);
    _value = target;
  }

  /// Кадр анимации; `true`, когда пружина остановилась.
  bool tick(Duration now) {
    final List<SpringSimulation>? running = _simulations;
    if (running == null) return true;
    final double t = _seconds(now);
    if (running.every((s) => s.isDone(t))) {
      _simulations = null;
      _value = _goalColor;
      return true;
    }
    _value = _Oklab.toColor([for (final s in running) s.x(t)]);
    return false;
  }

  double _seconds(Duration now) =>
      math.max(0, (now - _start).inMicroseconds) /
      Duration.microsecondsPerSecond;
}

/// sRGB ↔ Oklab (https://bottosson.github.io/posts/oklab/), каналы
/// `[alpha, L, a, b]` и ограничения из `ColorVectorConverter` Compose.
abstract final class _Oklab {
  static List<double> fromColor(Color color) {
    final double r = _toLinear(color.r);
    final double g = _toLinear(color.g);
    final double b = _toLinear(color.b);
    final double l = _cbrt(
      0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    );
    final double m = _cbrt(
      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    );
    final double s = _cbrt(
      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    );
    return [
      color.a,
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  static Color toColor(List<double> v) {
    final double alpha = v[0].clamp(0.0, 1.0);
    final double lightness = v[1].clamp(0.0, 1.0);
    final double a = v[2].clamp(-0.5, 0.5);
    final double b = v[3].clamp(-0.5, 0.5);
    final double l = math
        .pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        .toDouble();
    final double m = math
        .pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        .toDouble();
    final double s = math
        .pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        .toDouble();
    return Color.from(
      alpha: alpha,
      red: _toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
      green: _toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
      blue: _toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
    );
  }

  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

  static double _toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _toSrgb(double c) {
    final double v = c <= 0.0031308
        ? 12.92 * c
        : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
    return v.clamp(0.0, 1.0);
  }
}
