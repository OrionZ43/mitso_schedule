import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_motion.dart';
import '../theme/app_state_layer.dart';
import 'm3_tooltip.dart';

// Кнопки Material 3 Expressive: общие кнопки (`Button`), icon buttons и общее
// ядро (форма с пружинным морфом, тень, state layer, зона нажатия 48dp), на
// котором построены toggle-кнопки, группы и FAB.
//
// Эталон — Compose Material3: `Button.kt` (`Button(onClick, shapes, …)`,
// `ButtonDefaults`, `shapeByInteraction`), `IconButton.kt`,
// `IconButtonDefaults.kt`, `internal/AnimatedShape.kt`, `internal/Elevation.kt`;
// токены `Button{XSmall,Small,Medium,Large,XLarge}Tokens.kt`,
// `*IconButtonTokens.kt`. Цвета и размеры сверены с m3.material.io
// (`.m3-guidelines/components__buttons.md`, `components__icon-buttons.md`).
//
// Почему не `FilledButton`/`IconButton` Flutter: `ButtonStyleButton` анимирует
// форму внутри `Material` кривой `Curves.fastOutSlowIn` за `animationDuration`,
// а у Compose форма — пружина (`rememberAnimatedShape`). Здесь радиусы ведёт
// свой `AnimationController`, а `Material` получает `animationDuration: zero`.

/// Пружина к [target] с текущей скоростью — как `Animatable.animateTo` в Compose.
///
/// То же, что `springTo` из `app_motion.dart`, но со `snapToEnd`: `Animatable`
/// по окончании пружины ставит точное целевое значение, а от этого зависят
/// проверки вида `value == 0f` (`ButtonGroupMeasurePolicy`, `FabVisibleNode`).
TickerFuture m3SpringTo(
  AnimationController controller,
  M3Spring spring,
  double target, {
  double? from,
  double? velocity,
}) {
  return controller.animateWith(
    SpringSimulation(
      spring.description,
      from ?? controller.value,
      target,
      velocity ?? controller.velocity,
      snapToEnd: true,
    ),
  );
}

// ---------------------------------------------------------------------------
// Форма
// ---------------------------------------------------------------------------

/// Размер угла — порт `CornerSize` из Compose.
///
/// `DpCornerSize` — [fixed], `PercentCornerSize` — [fraction] от меньшей
/// стороны (`shapeSize.minDimension * percent / 100`). Интерполяция двух
/// размеров разных видов в Compose считает пиксели на месте
/// (`lerp(start.toPx(), stop.toPx(), fraction)`); сумма
/// `fixed + fraction × minDimension` — то же самое в замкнутом виде, без
/// вложенных интерполяций.
@immutable
class M3CornerSize {
  const M3CornerSize._(this.fixed, this.fraction);

  /// Абсолютный радиус в dp.
  const M3CornerSize.dp(double value) : fixed = value, fraction = 0;

  /// Радиус в процентах от меньшей стороны.
  const M3CornerSize.percent(double percent)
    : fixed = 0,
      fraction = percent / 100;

  /// `ShapeTokens.CornerFull` = `CircleShape` = 50%.
  static const M3CornerSize full = M3CornerSize.percent(50);

  static const M3CornerSize zero = M3CornerSize.dp(0);

  final double fixed;
  final double fraction;

  /// Радиус в логических пикселях для контейнера размера [size].
  ///
  /// Как `CornerBasedShape.createOutline`: не больше половины меньшей стороны.
  double toPx(Size size) {
    final double shortest = size.shortestSide;
    return clampDouble(fixed + fraction * shortest, 0, shortest / 2);
  }

  static M3CornerSize lerp(M3CornerSize a, M3CornerSize b, double t) =>
      M3CornerSize._(
        lerpDouble(a.fixed, b.fixed, t)!,
        lerpDouble(a.fraction, b.fraction, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is M3CornerSize &&
      other.fixed == fixed &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(fixed, fraction);

  @override
  String toString() => 'M3CornerSize(${fixed}dp + ${fraction * 100}%)';
}

/// Четыре угла с учётом направления текста — порт `RoundedCornerShape`.
@immutable
class M3Corners {
  const M3Corners.only({
    this.topStart = M3CornerSize.zero,
    this.topEnd = M3CornerSize.zero,
    this.bottomEnd = M3CornerSize.zero,
    this.bottomStart = M3CornerSize.zero,
  });

  const M3Corners.all(M3CornerSize size)
    : topStart = size,
      topEnd = size,
      bottomEnd = size,
      bottomStart = size;

  /// Одинаковый радиус в dp на всех углах.
  factory M3Corners.circular(double radius) =>
      M3Corners.all(M3CornerSize.dp(radius));

  /// `ShapeTokens.CornerFull`.
  static const M3Corners full = M3Corners.all(M3CornerSize.full);

  final M3CornerSize topStart;
  final M3CornerSize topEnd;
  final M3CornerSize bottomEnd;
  final M3CornerSize bottomStart;

  static M3Corners lerp(M3Corners a, M3Corners b, double t) => M3Corners.only(
    topStart: M3CornerSize.lerp(a.topStart, b.topStart, t),
    topEnd: M3CornerSize.lerp(a.topEnd, b.topEnd, t),
    bottomEnd: M3CornerSize.lerp(a.bottomEnd, b.bottomEnd, t),
    bottomStart: M3CornerSize.lerp(a.bottomStart, b.bottomStart, t),
  );

  BorderRadius resolve(Size size, TextDirection textDirection) {
    Radius r(M3CornerSize corner) => Radius.circular(corner.toPx(size));
    return switch (textDirection) {
      TextDirection.ltr => BorderRadius.only(
        topLeft: r(topStart),
        topRight: r(topEnd),
        bottomRight: r(bottomEnd),
        bottomLeft: r(bottomStart),
      ),
      TextDirection.rtl => BorderRadius.only(
        topLeft: r(topEnd),
        topRight: r(topStart),
        bottomRight: r(bottomStart),
        bottomLeft: r(bottomEnd),
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is M3Corners &&
      other.topStart == topStart &&
      other.topEnd == topEnd &&
      other.bottomEnd == bottomEnd &&
      other.bottomStart == bottomStart;

  @override
  int get hashCode => Object.hash(topStart, topEnd, bottomEnd, bottomStart);

  @override
  String toString() =>
      'M3Corners($topStart, $topEnd, $bottomEnd, $bottomStart)';
}

/// [OutlinedBorder] с углами [M3Corners]: проценты считаются от фактического
/// размера при отрисовке, как `CornerBasedShape.createOutline` в Compose.
class M3CornerShape extends OutlinedBorder {
  const M3CornerShape({required this.corners, super.side});

  final M3Corners corners;

  RoundedRectangleBorder _resolve(Rect rect, TextDirection? textDirection) =>
      RoundedRectangleBorder(
        side: side,
        borderRadius: corners.resolve(
          rect.size,
          textDirection ?? TextDirection.ltr,
        ),
      );

  /// Радиусы для контейнера размера [size] — удобно проверять в тестах.
  BorderRadius radiiFor(Size size, [TextDirection dir = TextDirection.ltr]) =>
      corners.resolve(size, dir);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _resolve(rect, textDirection).getInnerPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _resolve(rect, textDirection).getOuterPath(rect);

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => _resolve(rect, textDirection).paintInterior(canvas, rect, paint);

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _resolve(rect, textDirection).paint(canvas, rect);

  @override
  M3CornerShape copyWith({BorderSide? side, M3Corners? corners}) =>
      M3CornerShape(corners: corners ?? this.corners, side: side ?? this.side);

  @override
  ShapeBorder scale(double t) => M3CornerShape(
    corners: M3Corners.only(
      topStart: M3CornerSize._(
        corners.topStart.fixed * t,
        corners.topStart.fraction,
      ),
      topEnd: M3CornerSize._(corners.topEnd.fixed * t, corners.topEnd.fraction),
      bottomEnd: M3CornerSize._(
        corners.bottomEnd.fixed * t,
        corners.bottomEnd.fraction,
      ),
      bottomStart: M3CornerSize._(
        corners.bottomStart.fixed * t,
        corners.bottomStart.fraction,
      ),
    ),
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (t == 1) return this;
    if (a is M3CornerShape) {
      return M3CornerShape(
        corners: M3Corners.lerp(a.corners, corners, t),
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (t == 0) return this;
    if (b is M3CornerShape) {
      return M3CornerShape(
        corners: M3Corners.lerp(corners, b.corners, t),
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is M3CornerShape && other.corners == corners && other.side == side;

  @override
  int get hashCode => Object.hash(corners, side);
}

/// Морф формы пружиной — порт `AnimatedShapeState` (`internal/AnimatedShape.kt`).
///
/// Прогресс идёт от 0 к 1 между [start] и [target]. Если новая цель совпадает
/// с началом (пользователь передумал посреди анимации), прогресс
/// переворачивается `1 - p` и скорость меняет знак — движение не рвётся.
/// Иначе началом становится текущая видимая форма, прогресс с нуля.
class M3ShapeMorph {
  M3ShapeMorph({required TickerProvider vsync, required M3Corners initial})
    : _start = initial,
      _target = initial,
      progress = AnimationController.unbounded(vsync: vsync, value: 1);

  /// `AnimatedShapeState.progress` (`Animatable(1f)`).
  final AnimationController progress;

  M3Corners _start;
  M3Corners _target;

  M3Corners get start => _start;
  M3Corners get target => _target;

  /// Видимая сейчас форма (`getMorphedShape`).
  M3Corners get value {
    final double p = progress.value;
    if (p == 1) return _target;
    if (p == 0) return _start;
    return M3Corners.lerp(_start, _target, p);
  }

  /// `animateToShape(newTarget)`.
  void animateTo(M3Corners newTarget, M3Spring spring) {
    if (_target == newTarget) return;
    if (newTarget == _start) {
      final double p = progress.value;
      final double v = progress.velocity;
      _start = _target;
      _target = newTarget;
      m3SpringTo(progress, spring, 1, from: 1 - p, velocity: -v);
    } else {
      final double p = progress.value;
      _start = switch (p) {
        1 => _target,
        0 => _start,
        _ => M3Corners.lerp(_start, _target, p),
      };
      _target = newTarget;
      m3SpringTo(progress, spring, 1, from: 0, velocity: 0);
    }
  }

  /// Мгновенная смена формы: `key(shapes)` в Compose пересоздаёт состояние,
  /// а при уменьшении движения морф не нужен.
  void snapTo(M3Corners shape) {
    progress.stop();
    _start = shape;
    _target = shape;
    progress.value = 1;
  }

  void dispose() => progress.dispose();
}

// ---------------------------------------------------------------------------
// Размеры и цвета
// ---------------------------------------------------------------------------

/// Размер кнопки: XS, S (по умолчанию), M, L, XL.
///
/// Высоты, иконки, отступы, формы — `md.comp.button.<size>.*` и
/// `Button<Size>Tokens.kt`. Где Compose и токены m3 расходятся, взято m3
/// (главный источник), а Compose отмечен:
///  * XS: отступ 12dp и промежуток иконка↔текст 4dp — m3 и
///    `ButtonDefaults.ExtraSmallContentPadding`/`ExtraSmallIconSpacing`
///    (в `ButtonXSmallTokens` 16/8dp с TODO «once it's been corrected»);
///  * вертикальные отступы — `ButtonDefaults.contentPaddingFor`
///    (6 / 10 / 16 / 32 / 48dp; у S 10dp — не precision pointer).
enum M3ButtonSize {
  extraSmall(
    height: 32,
    horizontalPadding: 12,
    verticalPadding: 6,
    iconSize: 20,
    iconSpacing: 4,
    squareRadius: 12,
    pressedRadius: 8,
    outlineWidth: 1,
  ),
  small(
    height: 40,
    horizontalPadding: 16,
    verticalPadding: 10,
    iconSize: 20,
    iconSpacing: 8,
    squareRadius: 12,
    pressedRadius: 8,
    outlineWidth: 1,
  ),
  medium(
    height: 56,
    horizontalPadding: 24,
    verticalPadding: 16,
    iconSize: 24,
    iconSpacing: 8,
    squareRadius: 16,
    pressedRadius: 12,
    outlineWidth: 1,
  ),
  large(
    height: 96,
    horizontalPadding: 48,
    verticalPadding: 32,
    iconSize: 32,
    iconSpacing: 12,
    squareRadius: 28,
    pressedRadius: 16,
    outlineWidth: 2,
  ),
  extraLarge(
    height: 136,
    horizontalPadding: 64,
    verticalPadding: 48,
    iconSize: 40,
    iconSpacing: 16,
    squareRadius: 28,
    pressedRadius: 16,
    outlineWidth: 3,
  );

  const M3ButtonSize({
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.iconSpacing,
    required this.squareRadius,
    required this.pressedRadius,
    required this.outlineWidth,
  });

  /// `md.comp.button.<size>.container.height`.
  final double height;

  /// `leading-space` = `trailing-space`.
  final double horizontalPadding;
  final double verticalPadding;

  /// `md.comp.button.<size>.icon.size`.
  final double iconSize;

  /// `md.comp.button.<size>.icon-label-space`.
  final double iconSpacing;

  /// `container.shape.square` (= `selected.container.shape.round`).
  final double squareRadius;

  /// `pressed.container.shape`.
  final double pressedRadius;

  /// `outlined.outline.width`.
  final double outlineWidth;

  /// `md.comp.button.<size>.label-text`; для L/XL — `ButtonDefaults.textStyleFor`.
  TextStyle textStyle(TextTheme text) => switch (this) {
    extraSmall || small => text.labelLarge!,
    medium => text.titleMedium!,
    large => text.headlineSmall!,
    extraLarge => text.headlineLarge!,
  };

  EdgeInsets get contentPadding => EdgeInsets.symmetric(
    horizontal: horizontalPadding,
    vertical: verticalPadding,
  );
}

/// Форма по умолчанию: `container.shape.round` (full) или `.square`.
enum M3ButtonShape { round, square }

/// Цветовой стиль кнопки. `filled` — по умолчанию.
enum M3ButtonColor { elevated, filled, tonal, outlined, text }

/// Тень по взаимодействиям — `ButtonElevation` / `FloatingActionButtonElevation`.
@immutable
class M3ButtonElevation {
  const M3ButtonElevation({
    this.defaultElevation = 0,
    this.pressed = 0,
    this.focused = 0,
    this.hovered = 0,
    this.disabled = 0,
  });

  final double defaultElevation;
  final double pressed;
  final double focused;
  final double hovered;
  final double disabled;

  /// Outlined/text — без тени.
  static const M3ButtonElevation none = M3ButtonElevation();

  /// `FilledButtonTokens` / `TonalButtonTokens`: level0, hover level1.
  static const M3ButtonElevation filled = M3ButtonElevation(hovered: 1);

  /// `ElevatedButtonTokens`: level1, pressed/focus level1, hover level2.
  static const M3ButtonElevation elevated = M3ButtonElevation(
    defaultElevation: 1,
    pressed: 1,
    focused: 1,
    hovered: 3,
  );

  /// `FabPrimaryContainerTokens`: level3, hover level4.
  static const M3ButtonElevation fab = M3ButtonElevation(
    defaultElevation: 6,
    pressed: 6,
    focused: 6,
    hovered: 8,
    disabled: 6,
  );
}

/// Цвета disabled-кнопок: `md.comp.button.disabled.*` —
/// контейнер onSurface × 0.1, текст и иконка onSurface × 0.38.
abstract final class M3DisabledColors {
  static const double containerOpacity = 0.1;
  static const double contentOpacity = 0.38;

  static Color container(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: containerOpacity);

  static Color content(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: contentOpacity);
}

// ---------------------------------------------------------------------------
// Зона нажатия
// ---------------------------------------------------------------------------

/// Минимальная зона нажатия 48×48dp вокруг визуально меньшего контрола.
///
/// Порт `_InputPadding` из `button_style_button.dart` (Flutter) — аналог
/// `Modifier.minimumInteractiveComponentSize()` в Compose: размер не меньше
/// [minSize], ребёнок по центру, касание в полях перенаправляется в центр
/// ребёнка. Если родитель ограничивает размер жёстче, берётся ограничение.
class M3TouchTarget extends SingleChildRenderObjectWidget {
  const M3TouchTarget({
    super.key,
    this.minSize = const Size.square(kMinInteractiveDimension),
    super.child,
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderM3TouchTarget(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderM3TouchTarget renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class RenderM3TouchTarget extends RenderShiftedBox {
  RenderM3TouchTarget(this._minSize) : super(null);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(child?.getMinIntrinsicWidth(height) ?? 0, minSize.width);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(child?.getMinIntrinsicHeight(width) ?? 0, minSize.height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(child?.getMaxIntrinsicWidth(height) ?? 0, minSize.width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(child?.getMaxIntrinsicHeight(width) ?? 0, minSize.height);

  Size _computeSize(BoxConstraints constraints, ChildLayouter layoutChild) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size childSize = layoutChild(child, constraints);
    return constraints.constrain(
      Size(
        math.max(childSize.width, minSize.width),
        math.max(childSize.height, minSize.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeSize(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _computeSize(constraints, ChildLayoutHelper.layoutChild);
    final RenderBox? child = this.child;
    if (child != null) {
      final BoxParentData parentData = child.parentData! as BoxParentData;
      parentData.offset = Alignment.center.alongOffset(
        size - child.size as Offset,
      );
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    final RenderBox? child = this.child;
    if (child == null || !size.contains(position)) return false;
    final Offset center = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (BoxHitTestResult result, Offset position) =>
          child.hitTest(result, position: center),
    );
  }
}

// ---------------------------------------------------------------------------
// Ядро: контейнер кнопки
// ---------------------------------------------------------------------------

/// Роль кнопки для доступности.
enum M3ButtonSemantics {
  /// `Role.Button`.
  button,

  /// `Role.Checkbox` — у `ToggleButton` и toggle icon buttons.
  checkbox,

  /// Один вариант из нескольких: `Role.RadioButton` в сэмплах Compose
  /// (`SingleSelectConnectedButtonGroupSample`); во Flutter —
  /// `selected` + `inMutuallyExclusiveGroup`, как у `SegmentedButton`.
  radio,
}

/// Контейнер кнопки M3 Expressive — общее ядро `Button`, `ToggleButton`,
/// icon buttons и FAB.
///
/// Что повторяет из Compose (`Surface(onClick | checked, …)`):
///  * форма по взаимодействию: pressed > checked > shape (`shapeByInteraction`)
///    с пружинным морфом [morphSpring] (`rememberAnimatedShape`);
///  * цвета контейнера и содержимого меняются без анимации
///    (`colors.containerColor(enabled, checked)` отдаётся в `Surface` напрямую);
///  * тень — `animateElevation`: к новому взаимодействию 120 мс
///    `FastOutSlowInEasing`, обратно 150 мс (hover — 120 мс)
///    `CubicBezierEasing(0.4, 0, 0.6, 1)` (`internal/Elevation.kt`);
///  * обводка toggle-кнопки ([animateBorder]): толщина — пружина FastSpatial,
///    цвет — DefaultEffects (`animateBorderStrokeAsState` в `ToggleButton.kt`);
///  * содержимое обрезается по форме (`Modifier.clip(shape)` у `Surface`);
///  * зона нажатия не меньше 48dp (`minimumInteractiveComponentSize`).
///
/// State layer — [AppStateLayer.overlay] цветом содержимого.
class M3ButtonContainer extends StatefulWidget {
  const M3ButtonContainer({
    super.key,
    required this.onPressed,
    required this.shape,
    required this.pressedShape,
    this.checkedShape,
    this.checked = false,
    required this.morphSpring,
    required this.color,
    required this.contentColor,
    required this.textStyle,
    this.iconSize,
    this.border,
    this.animateBorder = false,
    this.elevation = M3ButtonElevation.none,
    this.semantics = M3ButtonSemantics.button,
    this.tooltip,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    this.minTouchTargetSize = const Size.square(kMinInteractiveDimension),
    required this.child,
  });

  /// `null` — кнопка выключена.
  final VoidCallback? onPressed;

  final M3Corners shape;
  final M3Corners pressedShape;

  /// Форма выбранной toggle-кнопки; `null` — не toggle.
  final M3Corners? checkedShape;
  final bool checked;

  /// Пружина морфа: `DefaultEffects` у `Button`/`IconButton`, `FastSpatial`
  /// у `ToggleButton`.
  final M3Spring morphSpring;

  /// Уже с учётом enabled/checked.
  final Color color;
  final Color contentColor;
  final TextStyle textStyle;
  final double? iconSize;
  final BorderSide? border;
  final bool animateBorder;
  final M3ButtonElevation elevation;
  final M3ButtonSemantics semantics;

  /// Plain tooltip M3 ([M3PlainTooltip]) над видимой границей кнопки.
  final String? tooltip;

  /// Состояния нажатия/наведения/фокуса — аналог `interactionSource`.
  /// Нужен группе кнопок, чтобы расширять нажатую.
  final WidgetStatesController? statesController;
  final FocusNode? focusNode;
  final bool autofocus;
  final Size minTouchTargetSize;
  final Widget child;

  @override
  State<M3ButtonContainer> createState() => _M3ButtonContainerState();
}

class _M3ButtonContainerState extends State<M3ButtonContainer>
    with TickerProviderStateMixin {
  WidgetStatesController? _internalStates;
  WidgetStatesController get _states =>
      widget.statesController ?? _internalStates!;

  late final M3ShapeMorph _morph;
  late final _ElevationAnimator _elevation;
  _BorderAnimator? _border;

  /// Активные взаимодействия в порядке появления (`interactions` в Compose).
  final List<WidgetState> _interactions = [];
  WidgetState? _lastElevationInteraction;

  bool get _enabled => widget.onPressed != null;

  static const List<WidgetState> _trackedStates = [
    WidgetState.hovered,
    WidgetState.focused,
    WidgetState.pressed,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.statesController == null) {
      _internalStates = WidgetStatesController();
    }
    _states.update(WidgetState.disabled, !_enabled);
    _syncInteractions();
    _states.addListener(_handleStatesChanged);
    _morph = M3ShapeMorph(vsync: this, initial: _targetShape);
    _elevation = _ElevationAnimator(
      vsync: this,
      initial: _elevationFor(_lastInteraction),
    );
    _lastElevationInteraction = _lastInteraction;
    if (widget.animateBorder) {
      _border = _BorderAnimator(vsync: this, initial: widget.border);
    }
  }

  @override
  void didUpdateWidget(M3ButtonContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      (oldWidget.statesController ?? _internalStates)?.removeListener(
        _handleStatesChanged,
      );
      if (widget.statesController != null) {
        _internalStates?.dispose();
        _internalStates = null;
      } else {
        _internalStates ??= WidgetStatesController();
      }
      _states.addListener(_handleStatesChanged);
      _syncInteractions();
    }
    if (_enabled != (oldWidget.onPressed != null)) {
      _states.update(WidgetState.disabled, !_enabled);
      if (!_enabled) _states.update(WidgetState.pressed, false);
    }

    final bool shapesChanged =
        widget.shape != oldWidget.shape ||
        widget.pressedShape != oldWidget.pressedShape ||
        widget.checkedShape != oldWidget.checkedShape;
    if (shapesChanged) {
      // `key(shapes) { rememberAnimatedShape(...) }`: новый набор форм —
      // новое состояние без анимации.
      _morph.snapTo(_targetShape);
    } else {
      _updateShape();
    }
    _updateElevation();

    if (widget.animateBorder) {
      _border ??= _BorderAnimator(vsync: this, initial: oldWidget.border);
      _border!.animateTo(widget.border, reduceMotion: _reduceMotion);
    } else {
      _border?.dispose();
      _border = null;
    }
  }

  @override
  void dispose() {
    _states.removeListener(_handleStatesChanged);
    _internalStates?.dispose();
    _morph.dispose();
    _elevation.dispose();
    _border?.dispose();
    super.dispose();
  }

  bool get _reduceMotion => mounted && reduceMotionOf(context);

  bool get _pressed => _states.value.contains(WidgetState.pressed);

  M3Corners get _targetShape {
    if (_pressed) return widget.pressedShape;
    if (widget.checked && widget.checkedShape != null) {
      return widget.checkedShape!;
    }
    return widget.shape;
  }

  WidgetState? get _lastInteraction =>
      _interactions.isEmpty ? null : _interactions.last;

  void _syncInteractions() {
    final Set<WidgetState> now = _states.value;
    for (final WidgetState state in _trackedStates) {
      final bool had = _interactions.contains(state);
      final bool has = now.contains(state);
      if (has && !had) _interactions.add(state);
      if (!has && had) _interactions.remove(state);
    }
  }

  void _handleStatesChanged() {
    if (!mounted) return;
    _syncInteractions();
    _updateShape();
    _updateElevation();
  }

  void _updateShape() {
    final M3Corners target = _targetShape;
    if (_reduceMotion) {
      if (_morph.target != target || _morph.progress.value != 1) {
        _morph.snapTo(target);
      }
      return;
    }
    _morph.animateTo(target, widget.morphSpring);
  }

  double _elevationFor(WidgetState? interaction) {
    final M3ButtonElevation e = widget.elevation;
    if (!_enabled) return e.disabled;
    return switch (interaction) {
      WidgetState.pressed => e.pressed,
      WidgetState.hovered => e.hovered,
      WidgetState.focused => e.focused,
      _ => e.defaultElevation,
    };
  }

  void _updateElevation() {
    final WidgetState? to = _lastInteraction;
    final double target = _elevationFor(to);
    if (target != _elevation.target) {
      if (!_enabled || _reduceMotion) {
        // «No transition when moving to a disabled state».
        _elevation.snapTo(target);
      } else if (to != null) {
        // `ElevationDefaults.incomingAnimationSpecForInteraction`.
        _elevation.animateTo(
          target,
          const Duration(milliseconds: 120),
          Curves.fastOutSlowIn,
        );
      } else if (_lastElevationInteraction != null) {
        // `outgoingAnimationSpecForInteraction`.
        _elevation.animateTo(
          target,
          _lastElevationInteraction == WidgetState.hovered
              ? const Duration(milliseconds: 120)
              : const Duration(milliseconds: 150),
          const Cubic(0.40, 0.00, 0.60, 1.00),
        );
      } else {
        _elevation.snapTo(target);
      }
    }
    _lastElevationInteraction = to;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final M3ButtonSemantics role = widget.semantics;

    final Widget content = DefaultTextStyle.merge(
      // «Don't truncate or wrap label text»: одна строка без многоточия,
      // как `Text(maxLines = 1, softWrap = false, overflow = Visible)` в
      // элементах `ButtonGroup`.
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.visible,
      child: IconTheme.merge(
        data: IconThemeData(color: widget.contentColor, size: widget.iconSize),
        child: widget.child,
      ),
    );

    return Semantics(
      container: true,
      button: role == M3ButtonSemantics.checkbox ? null : true,
      checked: role == M3ButtonSemantics.checkbox ? widget.checked : null,
      selected: role == M3ButtonSemantics.radio ? widget.checked : null,
      inMutuallyExclusiveGroup: role == M3ButtonSemantics.radio ? true : null,
      enabled: _enabled,
      child: M3TouchTarget(
        minSize: widget.minTouchTargetSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _morph.progress,
            _elevation.listenable,
            ?_border?.listenable,
          ]),
          child: content,
          builder: (context, child) {
            final BorderSide side = widget.animateBorder
                ? (_border?.side ?? BorderSide.none)
                : (widget.border ?? BorderSide.none);
            Widget inkWell = InkWell(
              onTap: widget.onPressed,
              statesController: _states,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              canRequestFocus: _enabled,
              overlayColor: AppStateLayer.overlay(widget.contentColor),
              highlightColor: Colors.transparent,
              child: child,
            );
            if (widget.tooltip != null) {
              inkWell = M3PlainTooltip(
                message: widget.tooltip!,
                child: inkWell,
              );
            }
            return Material(
              type: MaterialType.button,
              color: widget.color,
              shadowColor: colors.shadow,
              surfaceTintColor: Colors.transparent,
              elevation: _elevation.value,
              shape: M3CornerShape(corners: _morph.value, side: side),
              clipBehavior: Clip.antiAlias,
              borderOnForeground: false,
              animationDuration: Duration.zero,
              textStyle: widget.textStyle.copyWith(color: widget.contentColor),
              child: inkWell,
            );
          },
        ),
      ),
    );
  }
}

/// Тень, анимированная твином (`Animatable<Dp>.animateElevation`).
class _ElevationAnimator {
  _ElevationAnimator({required TickerProvider vsync, required double initial})
    : _controller = AnimationController(vsync: vsync, value: 1),
      _begin = initial,
      _end = initial;

  final AnimationController _controller;
  double _begin;
  double _end;
  Curve _curve = Curves.linear;

  Listenable get listenable => _controller;

  double get target => _end;

  double get value =>
      lerpDouble(_begin, _end, _curve.transform(_controller.value))!;

  void snapTo(double elevation) {
    _controller.stop();
    _begin = elevation;
    _end = elevation;
    _controller.value = 1;
  }

  void animateTo(double elevation, Duration duration, Curve curve) {
    _begin = value;
    _end = elevation;
    _curve = curve;
    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  void dispose() => _controller.dispose();
}

/// Обводка toggle-кнопки: толщина — FastSpatial, цвет — DefaultEffects.
class _BorderAnimator {
  _BorderAnimator({required TickerProvider vsync, required BorderSide? initial})
    : _width = AnimationController.unbounded(
        vsync: vsync,
        value: initial?.width ?? 0,
      ),
      _color = AnimationController(vsync: vsync, value: 1),
      _from = initial?.color ?? Colors.transparent,
      _to = initial?.color ?? Colors.transparent,
      _targetWidth = initial?.width ?? 0;

  final AnimationController _width;
  final AnimationController _color;
  Color _from;
  Color _to;
  double _targetWidth;

  Listenable get listenable => Listenable.merge([_width, _color]);

  /// `if (animatedWidth <= 0.dp) return null`.
  BorderSide? get side {
    final double width = _width.value;
    if (width <= 0) return null;
    return BorderSide(
      width: width,
      color: Color.lerp(_from, _to, _color.value)!,
    );
  }

  void animateTo(BorderSide? target, {required bool reduceMotion}) {
    final double width = target?.width ?? 0;
    final Color color = target?.color ?? Colors.transparent;
    if (reduceMotion) {
      _width.value = width;
      _targetWidth = width;
      _from = color;
      _to = color;
      _color.value = 1;
      return;
    }
    if (width != _targetWidth) {
      _targetWidth = width;
      m3SpringTo(_width, AppMotion.fastSpatial, width);
    }
    if (color != _to) {
      _from = Color.lerp(_from, _to, _color.value)!;
      _to = color;
      _color.value = 0;
      m3SpringTo(_color, AppMotion.defaultEffects, 1, from: 0, velocity: 0);
    }
  }

  void dispose() {
    _width.dispose();
    _color.dispose();
  }
}

/// Содержимое кнопки: необязательная ведущая иконка и подпись в строку по
/// центру (`Row(horizontalArrangement = Center, verticalAlignment =
/// CenterVertically)` в `Button`/`ToggleButton`).
class M3ButtonContent extends StatelessWidget {
  const M3ButtonContent({
    super.key,
    this.icon,
    required this.iconSize,
    required this.iconSpacing,
    required this.label,
  });

  final Widget? icon;
  final double iconSize;
  final double iconSpacing;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          SizedBox.square(
            dimension: iconSize,
            child: Center(child: icon),
          ),
          SizedBox(width: iconSpacing),
        ],
        Flexible(child: label),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

/// Общая кнопка M3 Expressive — `Button(onClick, shapes, …)` и варианты
/// `ElevatedButton`/`FilledTonalButton`/`OutlinedButton`/`TextButton` с `shapes`.
///
/// * Форма: round (full) или square (`container.shape.square`), при нажатии —
///   `pressed.container.shape`. Морф — пружина `DefaultEffects`: в `Button.kt`
///   «MotionSchemeKeyTokens.DefaultEffects is intentional here to prevent any
///   bounce in this component» (токен m3 — `fast.spatial`, Compose отступает
///   от него сознательно).
/// * Цвета — `md.comp.button.<style>.*`: у outlined подпись **onSurfaceVariant**,
///   обводка outlineVariant; disabled — контейнер onSurface 10%, содержимое
///   onSurface 38% (outlined и text без контейнера).
/// * Минимальная ширина 58dp — `ButtonDefaults.MinWidth`.
class M3Button extends StatelessWidget {
  const M3Button({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.color = M3ButtonColor.filled,
    this.size = M3ButtonSize.small,
    this.shape = M3ButtonShape.round,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onPressed;

  /// Подпись: 1–3 слова, одна строка.
  final Widget child;

  /// Необязательная ведущая иконка.
  final Widget? icon;

  final M3ButtonColor color;
  final M3ButtonSize size;
  final M3ButtonShape shape;
  final WidgetStatesController? statesController;
  final FocusNode? focusNode;
  final bool autofocus;

  /// `ButtonDefaults.MinWidth`.
  static const double minWidth = 58;

  /// Контейнер и содержимое для стиля — `md.comp.button.<style>.*`.
  static (Color container, Color content) colorsFor(
    M3ButtonColor style,
    ColorScheme colors, {
    required bool enabled,
  }) {
    if (!enabled) {
      final bool hasContainer =
          style != M3ButtonColor.outlined && style != M3ButtonColor.text;
      return (
        hasContainer ? M3DisabledColors.container(colors) : Colors.transparent,
        M3DisabledColors.content(colors),
      );
    }
    return switch (style) {
      M3ButtonColor.elevated => (colors.surfaceContainerLow, colors.primary),
      M3ButtonColor.filled => (colors.primary, colors.onPrimary),
      M3ButtonColor.tonal => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      M3ButtonColor.outlined => (Colors.transparent, colors.onSurfaceVariant),
      M3ButtonColor.text => (Colors.transparent, colors.primary),
    };
  }

  static M3ButtonElevation elevationFor(M3ButtonColor style) => switch (style) {
    M3ButtonColor.elevated => M3ButtonElevation.elevated,
    M3ButtonColor.filled || M3ButtonColor.tonal => M3ButtonElevation.filled,
    M3ButtonColor.outlined || M3ButtonColor.text => M3ButtonElevation.none,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final (Color container, Color content) = colorsFor(
      color,
      theme.colorScheme,
      enabled: enabled,
    );

    return M3ButtonContainer(
      onPressed: onPressed,
      shape: shape == M3ButtonShape.round
          ? M3Corners.full
          : M3Corners.circular(size.squareRadius),
      pressedShape: M3Corners.circular(size.pressedRadius),
      morphSpring: AppMotion.defaultEffects,
      color: container,
      contentColor: content,
      textStyle: size.textStyle(theme.textTheme),
      iconSize: size.iconSize,
      // `md.comp.button.outlined.outline.color` = outline-variant, в том числе
      // `outlined.disabled.outline.color`.
      border: color == M3ButtonColor.outlined
          ? BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: size.outlineWidth,
            )
          : null,
      elevation: elevationFor(color),
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: size.height),
        child: Padding(
          padding: size.contentPadding,
          child: M3ButtonContent(
            icon: icon,
            iconSize: size.iconSize,
            iconSpacing: size.iconSpacing,
            label: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon button
// ---------------------------------------------------------------------------

/// Цветовой стиль icon button. `filled` — по умолчанию (m3 «Configurations»).
enum M3IconButtonColor { filled, tonal, outlined, standard }

/// Ширина icon button: `IconButtonDefaults.IconButtonWidthOption`.
enum M3IconButtonWidth { narrow, uniform, wide }

/// Icon button M3 Expressive — `IconButton(onClick, shapes)`, `FilledIconButton`,
/// `FilledTonalIconButton`, `OutlinedIconButton` и toggle-варианты
/// (`IconToggleButton(checked, shapes)` и т. д.).
///
/// * Размер контейнера — `IconButtonDefaults.<size>ContainerSize(widthOption)`:
///   высота по размеру, ширина = иконка + отступы narrow/uniform/wide.
/// * Форма: round/square, pressed — `pressed.container.shape`; у toggle
///   выбранная round → `selected.container.shape.round` (= square-радиус),
///   square → full (`IconButtonDefaults.toggleableShapes`).
/// * Морф и у default, и у toggle — пружина `DefaultEffects`
///   (`shapeForInteraction` в `IconButton.kt`).
/// * Цвета — `md.comp.icon-button.<style>.*`: standard — onSurfaceVariant
///   (выбранная primary); outlined — обводка outlineVariant, выбранная —
///   inverseSurface/inverseOnSurface без обводки; disabled — onSurface 38%,
///   контейнер onSurface 10%.
/// * Default icon button должен получать filled-иконку (Guidelines «Icon»);
///   toggle — outlined в [icon] и filled в [selectedIcon].
class M3IconButton extends StatelessWidget {
  const M3IconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.selectedIcon,
    this.isSelected,
    this.color = M3IconButtonColor.filled,
    this.size = M3ButtonSize.small,
    this.width = M3IconButtonWidth.uniform,
    this.shape = M3ButtonShape.round,
    this.tooltip,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;

  /// Иконка выбранной toggle-кнопки.
  final Widget? selectedIcon;

  /// `null` — обычная кнопка, иначе toggle.
  final bool? isSelected;

  final M3IconButtonColor color;
  final M3ButtonSize size;
  final M3IconButtonWidth width;
  final M3ButtonShape shape;

  /// Метка действия; показывается [M3PlainTooltip].
  final String? tooltip;
  final WidgetStatesController? statesController;
  final FocusNode? focusNode;
  final bool autofocus;

  /// `<Size>IconButtonTokens.IconSize`.
  static double iconSizeFor(M3ButtonSize size) => switch (size) {
    M3ButtonSize.extraSmall => 20,
    M3ButtonSize.small || M3ButtonSize.medium => 24,
    M3ButtonSize.large => 32,
    M3ButtonSize.extraLarge => 40,
  };

  /// Отступ с каждой стороны иконки: `Narrow/Default(Uniform)/WideLeadingSpace`.
  static double horizontalSpaceFor(
    M3ButtonSize size,
    M3IconButtonWidth width,
  ) => switch ((size, width)) {
    (M3ButtonSize.extraSmall, M3IconButtonWidth.narrow) => 4,
    (M3ButtonSize.extraSmall, M3IconButtonWidth.uniform) => 6,
    (M3ButtonSize.extraSmall, M3IconButtonWidth.wide) => 10,
    (M3ButtonSize.small, M3IconButtonWidth.narrow) => 4,
    (M3ButtonSize.small, M3IconButtonWidth.uniform) => 8,
    (M3ButtonSize.small, M3IconButtonWidth.wide) => 14,
    (M3ButtonSize.medium, M3IconButtonWidth.narrow) => 12,
    (M3ButtonSize.medium, M3IconButtonWidth.uniform) => 16,
    (M3ButtonSize.medium, M3IconButtonWidth.wide) => 24,
    (M3ButtonSize.large, M3IconButtonWidth.narrow) => 16,
    (M3ButtonSize.large, M3IconButtonWidth.uniform) => 32,
    (M3ButtonSize.large, M3IconButtonWidth.wide) => 48,
    (M3ButtonSize.extraLarge, M3IconButtonWidth.narrow) => 32,
    (M3ButtonSize.extraLarge, M3IconButtonWidth.uniform) => 48,
    (M3ButtonSize.extraLarge, M3IconButtonWidth.wide) => 72,
  };

  /// `IconButtonDefaults.<size>ContainerSize(widthOption)`.
  static Size containerSizeFor(M3ButtonSize size, M3IconButtonWidth width) =>
      Size(
        iconSizeFor(size) + 2 * horizontalSpaceFor(size, width),
        size.height,
      );

  /// Контейнер и иконка — `md.comp.icon-button.<style>.*`.
  static (Color container, Color content) colorsFor(
    M3IconButtonColor style,
    ColorScheme colors, {
    required bool enabled,
    bool? selected,
  }) {
    if (!enabled) {
      final bool hasContainer = switch (style) {
        M3IconButtonColor.filled || M3IconButtonColor.tonal => true,
        // `outlined.selected.disabled.container.color` = on-surface, 0.1.
        M3IconButtonColor.outlined => selected ?? false,
        M3IconButtonColor.standard => false,
      };
      return (
        hasContainer ? M3DisabledColors.container(colors) : Colors.transparent,
        M3DisabledColors.content(colors),
      );
    }
    return switch ((style, selected)) {
      (M3IconButtonColor.filled, null) => (colors.primary, colors.onPrimary),
      (M3IconButtonColor.filled, false) => (
        colors.surfaceContainer,
        colors.onSurfaceVariant,
      ),
      (M3IconButtonColor.filled, true) => (colors.primary, colors.onPrimary),
      (M3IconButtonColor.tonal, null || false) => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      (M3IconButtonColor.tonal, true) => (colors.secondary, colors.onSecondary),
      (M3IconButtonColor.outlined, null || false) => (
        Colors.transparent,
        colors.onSurfaceVariant,
      ),
      (M3IconButtonColor.outlined, true) => (
        colors.inverseSurface,
        colors.onInverseSurface,
      ),
      (M3IconButtonColor.standard, null || false) => (
        Colors.transparent,
        colors.onSurfaceVariant,
      ),
      (M3IconButtonColor.standard, true) => (
        Colors.transparent,
        colors.primary,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final bool toggle = isSelected != null;
    final bool selected = isSelected ?? false;
    final (Color container, Color content) = colorsFor(
      color,
      theme.colorScheme,
      enabled: enabled,
      selected: isSelected,
    );
    final Size containerSize = containerSizeFor(size, width);

    return M3ButtonContainer(
      onPressed: onPressed,
      shape: shape == M3ButtonShape.round
          ? M3Corners.full
          : M3Corners.circular(size.squareRadius),
      pressedShape: M3Corners.circular(size.pressedRadius),
      checkedShape: toggle
          ? (shape == M3ButtonShape.round
                ? M3Corners.circular(size.squareRadius)
                : M3Corners.full)
          : null,
      checked: selected,
      morphSpring: AppMotion.defaultEffects,
      color: container,
      contentColor: content,
      textStyle: theme.textTheme.labelLarge!,
      iconSize: iconSizeFor(size),
      border: color == M3IconButtonColor.outlined && !selected
          ? BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: size.outlineWidth,
            )
          : null,
      semantics: toggle ? M3ButtonSemantics.checkbox : M3ButtonSemantics.button,
      tooltip: tooltip,
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      child: SizedBox.fromSize(
        size: containerSize,
        child: Center(
          child: selected && selectedIcon != null ? selectedIcon : icon,
        ),
      ),
    );
  }
}
