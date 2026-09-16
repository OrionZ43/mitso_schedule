import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_state_layer.dart';

/// Содержимое листа. [scrollController] нужно отдать прокручиваемому списку
/// внутри: через него лист и список делят жест, как `nestedScroll` в Compose
/// (`ConsumeSwipeWithinBottomSheetBoundsNestedScrollConnection`). Содержимое
/// без прокрутки может его не использовать.
typedef M3BottomSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Положения листа — `SheetValue`.
enum M3SheetValue { hidden, partiallyExpanded, expanded }

/// Токены и константы модального нижнего листа.
abstract final class M3BottomSheetDefaults {
  /// `BottomSheetDefaults.SheetMaxWidth`.
  static const double maxWidth = 640;

  /// `SheetBottomTokens.DockedContainerShape` = `corner.extra-large-top`.
  static const double cornerRadius = 28;

  /// `SheetBottomTokens.DockedModalContainerElevation` = Level1.
  static const double elevation = 1;

  /// `SheetBottomTokens.DockedDragHandleWidth` / `Height`.
  static const Size dragHandleSize = Size(32, 4);

  /// `DragHandleVerticalPadding`.
  static const double dragHandleVerticalPadding = 22;

  /// `ScrimTokens.ContainerOpacity`.
  static const double scrimOpacity = 0.32;

  /// `BottomSheetDefaults.PositionalThreshold` / `VelocityThreshold` /
  /// `BoundaryDampeningZone`.
  static const double positionalThreshold = 56;
  static const double velocityThreshold = 125;
  static const double boundaryDampeningZone = 125;

  /// `PredictiveBackMaxScaleXDistance` / `PredictiveBackMaxScaleYDistance`.
  static const double predictiveBackMaxScaleXDistance = 48;
  static const double predictiveBackMaxScaleYDistance = 24;

  /// `Strings.BottomSheetDragHandleDescription` и `Strings.CloseSheet` (ru).
  static const String dragHandleLabel = 'Маркер перемещения';
  static const String scrimLabel = 'Закрыть лист';
}

/// Модальный нижний лист M3 — порт Compose `ModalBottomSheet` + `BottomSheet`.
///
/// https://m3.material.io/components/bottom-sheets/guidelines
///
///   * контейнер `surfaceContainerLow`, верхние углы 28dp, elevation level1,
///     ширина до 640dp (`SheetBottomTokens`, `BottomSheetDefaults`);
///   * ручка 32×4 `onSurfaceVariant`, поля 22dp сверху и снизу; нажатие —
///     как `BottomSheetImpl`: из половины разворачивает, из полного
///     положения закрывает; у ручки роль button и действия
///     expand / collapse / dismiss;
///   * scrim `colorScheme.scrim` × 0.32, прозрачность — пружина `DefaultEffects`
///     (`ModalBottomSheet.kt`), нажатие закрывает лист;
///   * показ — пружина `DefaultSpatial`, скрытие — `FastEffects`, доводка после
///     перетаскивания — `DefaultSpatial` с порогами 56dp и 125dp/с
///     (`BottomSheet.kt` → `showMotionSpec` / `hideMotionSpec` /
///     `anchoredDraggableMotionSpec`, `modalBottomSheetFlingBehavior`);
///   * [halfExpandedFirst]: якорь `PartiallyExpanded` на половине экрана,
///     лист открывается на него и тянется до полного; иначе якоря только
///     `Hidden` и `Expanded` (`skipPartiallyExpanded`);
///   * системный «назад» и predictive back — `settleToDismiss`: из полного
///     положения при наличии половины лист сворачивается до неё, иначе
///     закрывается; во время жеста лист сжимается
///     (`sheetPredictiveBackScaling`).
///
/// Почему не `showModalBottomSheet`: у Flutter-листа анимация — кривая по
/// времени маршрута (пружина через `SpringCurve` теряет скорость пальца и при
/// перелёте отрывает лист от низа экрана), scrim привязан к анимации маршрута,
/// частично раскрытого состояния и predictive back нет. `DraggableScrollableSheet`
/// меняет высоту листа, а не сдвиг, и доводит линейно по времени. Поэтому свой
/// маршрут, а движение — порт якорей Compose.
///
/// `Navigator.pop(context, result)` из содержимого закрывает лист с анимацией
/// скрытия. Управление изнутри — [M3BottomSheetScope].
Future<T?> showM3ModalBottomSheet<T>({
  required BuildContext context,
  required M3BottomSheetBuilder builder,
  bool halfExpandedFirst = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  return navigator.push(
    _M3ModalBottomSheetRoute<T>(
      builder: builder,
      halfExpandedFirst: halfExpandedFirst,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      settings: routeSettings,
    ),
  );
}

/// Управление открытым листом из его содержимого (`SheetState`).
class M3BottomSheetScope extends InheritedWidget {
  const M3BottomSheetScope._({required this._state, required super.child});

  final _M3SheetState _state;

  static M3BottomSheetScope of(BuildContext context) {
    final M3BottomSheetScope? scope = context
        .getInheritedWidgetOfExactType<M3BottomSheetScope>();
    assert(scope != null, 'M3BottomSheetScope есть только внутри листа');
    return scope!;
  }

  /// `SheetState.expand()`: пружина `DefaultSpatial`.
  Future<void> expand() => _state._expand();

  /// `SheetState.partialExpand()`: пружина `FastEffects`. Только с
  /// `halfExpandedFirst`.
  Future<void> partialExpand() => _state._partialExpand();

  /// Закрыть лист с анимацией скрытия.
  void hide() => _state._hide();

  @override
  bool updateShouldNotify(M3BottomSheetScope oldWidget) => false;
}

class _M3ModalBottomSheetRoute<T> extends PopupRoute<T> {
  _M3ModalBottomSheetRoute({
    required this.builder,
    required this.halfExpandedFirst,
    required this.isDismissible,
    required this.enableDrag,
    required this.showDragHandle,
    required this.capturedThemes,
    super.settings,
  });

  final M3BottomSheetBuilder builder;
  final bool halfExpandedFirst;
  final bool isDismissible;
  final bool enableDrag;
  final bool showDragHandle;
  final CapturedThemes capturedThemes;

  // Движение рисуют пружины листа; маршрут только держит оверлей, пока они
  // идут. Скрытие FastEffects успевает за время его затухания.
  @override
  Duration get transitionDuration => AppMotion.defaultSpatial.duration;

  @override
  Duration get reverseTransitionDuration => AppMotion.fastEffects.duration;

  // Scrim рисует сам лист: у него своя пружина прозрачности.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// Закрыть с анимацией скрытия листа.
  void dismiss() {
    final NavigatorState? navigator = this.navigator;
    if (navigator == null || !isActive) return;
    if (isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(this);
    }
  }

  /// Убрать маршрут сразу: лист уже доехал до `Hidden`.
  void popWithoutTransition() {
    controller?.reverseDuration = Duration.zero;
    dismiss();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return capturedThemes.wrap(_M3ModalBottomSheet(route: this));
  }
}

class _M3ModalBottomSheet extends StatefulWidget {
  const _M3ModalBottomSheet({required this.route});

  final _M3ModalBottomSheetRoute<dynamic> route;

  @override
  State<_M3ModalBottomSheet> createState() => _M3SheetState();
}

class _M3SheetState extends State<_M3ModalBottomSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Сдвиг верха листа от верха окна — `anchoredDraggableState.offset`.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  /// Прозрачность scrim 0..1.
  late final AnimationController _scrim = AnimationController(vsync: this);

  /// Прогресс predictive back после `PredictiveBack.transform`.
  late final AnimationController _back = AnimationController.unbounded(
    vsync: this,
  );

  late final _SheetScrollController _scrollController = _SheetScrollController(
    this,
  );

  /// Якоря в порядке Compose: Hidden, PartiallyExpanded, Expanded.
  Map<M3SheetValue, double> _anchors = const {};
  bool _hasLayout = false;
  double _fullHeight = 0;
  double _sheetHeight = 0;
  double _sheetWidth = 0;

  /// `SheetState.currentValue` (settled value).
  M3SheetValue _settled = M3SheetValue.hidden;

  /// Цель идущей анимации — `dragTarget`.
  M3SheetValue? _animationTarget;
  M3Spring? _animationSpring;
  int _animationId = 0;

  /// Сдвиг ведёт [_offset] (анимация или палец). В покое сдвиг — положение
  /// якоря [_settled]: так смена якорей в раскладке не трогает контроллер.
  bool _controlling = false;

  bool _dragging = false;
  bool _dragFromScroll = false;
  bool _dismissing = false;
  bool _reduceMotion = false;
  double _scrimTarget = 0;

  /// Жёсткий допуск в пикселях: пружина должна затухнуть раньше, чем маршрут
  /// с длительностью `AppMotion.*.duration` уберёт оверлей.
  static const Tolerance _tolerance = Tolerance(distance: 0.5, velocity: 10);

  /// `spring()` по умолчанию у `Animatable.animateTo`: StiffnessMedium, без перелёта.
  static final SpringDescription _defaultSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1500, ratio: 1);

  /// `PredictiveBack.transform`: `CubicBezierEasing(0.1, 0.1, 0, 1)`.
  static const Curve _predictiveBackEasing = Cubic(0.1, 0.1, 0, 1);

  _M3ModalBottomSheetRoute<dynamic> get _route => widget.route;

  bool get _gesturesEnabled => _route.enableDrag && !_dismissing && _hasLayout;

  /// Текущий сдвиг верха листа.
  double get _currentOffset => _controlling
      ? _offset.value
      : (_anchors[_settled] ?? _anchors[M3SheetValue.hidden] ?? _fullHeight);

  double get _minAnchor => _anchors.values.reduce(math.min);
  double get _maxAnchor => _anchors.values.reduce(math.max);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _route.animation!.addStatusListener(_handleRouteStatus);
    // Пружина завершается в пределах допуска, а не ровно в цели.
    _scrim.addStatusListener((status) {
      if (status.isCompleted && _scrim.value != _scrimTarget) {
        _scrim.value = _scrimTarget;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _route.animation?.removeStatusListener(_handleRouteStatus);
    _scrollController.dispose();
    _offset.dispose();
    _scrim.dispose();
    _back.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Якоря и раскладка.

  /// Вызывается из раскладки: пересчитать якоря (`draggableAnchors` в
  /// `BottomSheetImpl`) и вернуть текущий сдвиг листа.
  double _layoutSheet(double fullHeight, double sheetHeight, double width) {
    _sheetWidth = width;
    if (_hasLayout &&
        fullHeight == _fullHeight &&
        sheetHeight == _sheetHeight) {
      return _currentOffset;
    }
    _fullHeight = fullHeight;
    _sheetHeight = sheetHeight;

    final Map<M3SheetValue, double> old = _anchors;
    final Map<M3SheetValue, double> anchors = {
      M3SheetValue.hidden: fullHeight,
      // `calculatePartiallyExpandedOffset` (детерминированный вариант):
      // не выше половины окна и не выше самого листа.
      if (_route.halfExpandedFirst)
        M3SheetValue.partiallyExpanded:
            fullHeight - math.min(fullHeight / 2, sheetHeight),
      if (sheetHeight != 0)
        M3SheetValue.expanded: math.max(0.0, fullHeight - sheetHeight),
    };

    if (!_hasLayout) {
      _hasLayout = true;
      _anchors = anchors;
      SchedulerBinding.instance.addPostFrameCallback((_) => _show());
      return _currentOffset;
    }

    // Новая цель при смене якорей — лямбда `draggableAnchors`.
    final M3SheetValue current =
        _animationTarget ?? _closest(_currentOffset, anchors: old);
    _anchors = anchors;
    final M3SheetValue target = switch (current) {
      M3SheetValue.hidden => M3SheetValue.hidden,
      M3SheetValue.partiallyExpanded =>
        _wasConverged(old) && anchors.containsKey(M3SheetValue.expanded)
            ? M3SheetValue.expanded
            : anchors.containsKey(M3SheetValue.partiallyExpanded)
            ? M3SheetValue.partiallyExpanded
            : anchors.containsKey(M3SheetValue.expanded)
            ? M3SheetValue.expanded
            : M3SheetValue.hidden,
      M3SheetValue.expanded =>
        anchors.containsKey(M3SheetValue.expanded)
            ? M3SheetValue.expanded
            : M3SheetValue.hidden,
    };

    // Контроллер во время раскладки менять нельзя — после кадра.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_animationTarget != null && !_dragging) {
        // `dragTarget`: идущая анимация перезапускается к новой цели.
        _animateTo(target, _animationSpring ?? AppMotion.defaultSpatial);
      } else {
        setState(() {
          if (!_controlling) _settled = target;
        });
      }
    });
    if (!_controlling) _settled = target;
    return _currentOffset;
  }

  bool _wasConverged(Map<M3SheetValue, double> anchors) =>
      anchors.containsKey(M3SheetValue.partiallyExpanded) &&
      anchors.containsKey(M3SheetValue.expanded) &&
      anchors[M3SheetValue.partiallyExpanded] == anchors[M3SheetValue.expanded];

  /// `DraggableAnchors.closestAnchor(position)` и
  /// `closestAnchor(position, searchUpwards)`: при равенстве выигрывает
  /// последний якорь.
  M3SheetValue _closest(
    double position, {
    bool? searchUpwards,
    Map<M3SheetValue, double>? anchors,
  }) {
    M3SheetValue? best;
    double min = double.infinity;
    for (final MapEntry<M3SheetValue, double> entry
        in (anchors ?? _anchors).entries) {
      final double distance;
      if (searchUpwards == null) {
        distance = (position - entry.value).abs();
      } else {
        final double delta = searchUpwards
            ? entry.value - position
            : position - entry.value;
        distance = delta < 0 ? double.infinity : delta;
      }
      if (distance <= min) {
        best = entry.key;
        min = distance;
      }
    }
    return best ?? M3SheetValue.hidden;
  }

  /// `DraggableAnchors.computeTarget` из `AnchoredDraggable.kt`.
  M3SheetValue _computeTarget(double offset, double velocity) {
    if (velocity == 0) return _closest(offset);
    final bool forward = velocity > 0;
    if (velocity.abs() >= M3BottomSheetDefaults.velocityThreshold) {
      return _closest(offset, searchUpwards: forward);
    }
    final M3SheetValue left = _closest(offset, searchUpwards: false);
    final M3SheetValue right = _closest(offset, searchUpwards: true);
    final double fromStart = forward ? _anchors[left]! : _anchors[right]!;
    final bool passed =
        (fromStart - offset).abs() >= M3BottomSheetDefaults.positionalThreshold;
    return passed ? (forward ? right : left) : (forward ? left : right);
  }

  /// `anchoredDraggableState.targetValue`: цель анимации или ближайший якорь.
  M3SheetValue get _targetValue =>
      _animationTarget ??
      (_hasLayout ? _closest(_currentOffset) : M3SheetValue.hidden);

  // ---------------------------------------------------------------------------
  // Анимации.

  Future<void> _animateTo(
    M3SheetValue value,
    M3Spring spring, {
    double? velocity,
  }) {
    final double? to = _anchors[value];
    if (to == null) return Future<void>.value();
    final int id = ++_animationId;
    _dragging = false;
    _dragFromScroll = false;
    _animationTarget = value;
    _animationSpring = spring;
    _updateScrim();

    final double from = _currentOffset;
    final double startVelocity = velocity ?? _offset.velocity;
    _controlling = true;
    _offset.value = from;

    final Completer<void> completer = Completer<void>();
    void finish() {
      if (id == _animationId && mounted) {
        _animationTarget = null;
        _controlling = false;
        setState(() => _settled = value);
        // Сдвиг теперь — положение якоря; слушатели перерисуют точно.
        final double? position = _anchors[value];
        if (position != null) _offset.value = position;
        _updateScrim();
      }
      if (!completer.isCompleted) completer.complete();
    }

    if (_reduceMotion || (from == to && startVelocity == 0)) {
      _offset.value = to;
      finish();
    } else {
      _offset
          .animateWith(
            SpringSimulation(
              spring.description,
              from,
              to,
              startVelocity,
              tolerance: _tolerance,
            ),
          )
          .whenCompleteOrCancel(finish);
    }
    return completer.future;
  }

  void _updateScrim() {
    final double target = _targetValue != M3SheetValue.hidden ? 1 : 0;
    if (target == _scrimTarget) return;
    _scrimTarget = target;
    if (_reduceMotion) {
      _scrim.value = target;
      return;
    }
    // `animateFloatAsState(MotionSchemeKeyTokens.DefaultEffects)`.
    _scrim.animateWith(
      SpringSimulation(
        AppMotion.defaultEffects.description,
        _scrim.value,
        target,
        _scrim.velocity,
      ),
    );
  }

  /// `SheetState.show()`.
  void _show() {
    if (!mounted || _dismissing) return;
    _animateTo(
      _anchors.containsKey(M3SheetValue.partiallyExpanded)
          ? M3SheetValue.partiallyExpanded
          : M3SheetValue.expanded,
      AppMotion.defaultSpatial,
    );
  }

  /// `SheetState.expand()` — `showMotionSpec`.
  Future<void> _expand() {
    if (_dismissing) return Future<void>.value();
    return _animateTo(M3SheetValue.expanded, AppMotion.defaultSpatial);
  }

  /// `SheetState.partialExpand()` — `hideMotionSpec`.
  Future<void> _partialExpand() {
    if (_dismissing) return Future<void>.value();
    return _animateTo(M3SheetValue.partiallyExpanded, AppMotion.fastEffects);
  }

  /// `animateToDismiss`: закрытие маршрута запускает скрытие листа.
  void _hide() {
    if (_dismissing) return;
    _route.dismiss();
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || _dismissing) return;
    // `SheetState.hide()` — `hideMotionSpec`.
    _dismissing = true;
    _animateTo(M3SheetValue.hidden, AppMotion.fastEffects);
  }

  /// `settleToDismiss` из `ModalBottomSheet` / `BottomSheet`.
  void _settleToDismiss() {
    if (_dismissing) return;
    if (_settled == M3SheetValue.expanded &&
        _anchors.containsKey(M3SheetValue.partiallyExpanded)) {
      _partialExpand();
      _animateBackProgressToZero();
    } else {
      _hide();
    }
  }

  void _animateBackProgressToZero() {
    if (_reduceMotion) {
      _back.value = 0;
      return;
    }
    _back.animateWith(SpringSimulation(_defaultSpring, _back.value, 0, 0));
  }

  // ---------------------------------------------------------------------------
  // Перетаскивание.

  /// `dispatchRawDelta` / `newOffsetForDelta`: сдвиг в пределах якорей.
  double _dragBy(double delta, {required bool fromScroll}) {
    if (!_gesturesEnabled) return 0;
    final double old = _currentOffset;
    final double next = (old + delta).clamp(_minAnchor, _maxAnchor);
    if (next == old) return 0;
    if (_animationTarget != null || _offset.isAnimating) {
      _animationId++;
      _offset.stop();
      _animationTarget = null;
    }
    _controlling = true;
    _dragging = true;
    _dragFromScroll = fromScroll;
    _offset.value = next;
    _updateScrim();
    return next - old;
  }

  /// Отпускание: `modalBottomSheetFlingBehavior` — гашение скорости у низа,
  /// выбор якоря по порогам и доводка `DefaultSpatial`.
  void _settle(double velocity) {
    if (!_dragging || !_hasLayout) return;
    _dragging = false;
    _dragFromScroll = false;

    double safeVelocity = velocity;
    if (safeVelocity > 0) {
      final double distanceToFloor = math.max(
        0,
        _anchors[M3SheetValue.hidden]! - _currentOffset,
      );
      const double zone = M3BottomSheetDefaults.boundaryDampeningZone;
      if (distanceToFloor < zone) {
        final double factor = distanceToFloor / zone;
        safeVelocity *= factor * factor;
        if (velocity >= M3BottomSheetDefaults.velocityThreshold) {
          safeVelocity = math.max(
            safeVelocity,
            M3BottomSheetDefaults.velocityThreshold,
          );
        }
      }
    }

    final M3SheetValue target = _computeTarget(_currentOffset, safeVelocity);
    _animateTo(target, AppMotion.defaultSpatial, velocity: safeVelocity).then((
      _,
    ) {
      if (mounted && !_dismissing && _settled == M3SheetValue.hidden) {
        _dismissing = true;
        _route.popWithoutTransition();
      }
    });
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_gesturesEnabled) return;
    if (_animationTarget != null || _offset.isAnimating) {
      _animationId++;
      _offset.stop();
      _animationTarget = null;
    }
    if (!_controlling) _offset.value = _currentOffset;
    _controlling = true;
    _dragging = true;
    _dragFromScroll = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) =>
      _dragBy(details.primaryDelta ?? 0, fromScroll: false);

  void _handleDragEnd(DragEndDetails details) =>
      _settle(details.primaryVelocity ?? 0);

  void _handleDragCancel() => _settle(0);

  // ---------------------------------------------------------------------------
  // Predictive back (`PredictiveBackHandler` в `BottomSheet`).

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || _dismissing || !_route.isCurrent) {
      return false;
    }
    _back.value = _predictiveBackEasing.transform(backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_dismissing) return;
    _back.value = _predictiveBackEasing.transform(backEvent.progress);
  }

  @override
  void handleCommitBackGesture() => _settleToDismiss();

  @override
  void handleCancelBackGesture() => _animateBackProgressToZero();

  // ---------------------------------------------------------------------------

  void _handleDragHandleTap() {
    switch (_settled) {
      case M3SheetValue.expanded:
        _hide();
      case M3SheetValue.partiallyExpanded:
        _expand();
      case M3SheetValue.hidden:
        _show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dismissible = _route.isDismissible;
    final bool canDragSurface =
        _route.enableDrag && _settled != M3SheetValue.hidden;
    final bool hasPartial = _anchors.containsKey(
      M3SheetValue.partiallyExpanded,
    );

    final Widget content = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: M3BottomSheetScope._(
          state: this,
          child: Builder(
            builder: (context) => _route.builder(context, _scrollController),
          ),
        ),
      ),
    );

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_route.showDragHandle)
          _DragHandle(
            onTap: _handleDragHandleTap,
            onDismiss: _route.enableDrag ? _hide : null,
            onExpand:
                _route.enableDrag && _settled == M3SheetValue.partiallyExpanded
                ? _expand
                : null,
            onCollapse:
                _route.enableDrag &&
                    _settled != M3SheetValue.partiallyExpanded &&
                    hasPartial
                ? _partialExpand
                : null,
          ),
        Flexible(child: content),
      ],
    );

    final Widget sheet = AnimatedBuilder(
      animation: Listenable.merge([_offset, _back]),
      child: column,
      builder: (context, child) {
        final double offset = _currentOffset;
        final double height = _sheetHeight;
        final double width = _sheetWidth;
        final double progress = _back.value;

        // `verticalScaleUp` / `verticalScaleDown`: при перелёте выше верхнего
        // якоря контейнер растягивается вниз, чтобы у низа не было щели.
        final double overflow = _hasLayout && offset < _minAnchor
            ? _minAnchor - offset
            : 0;
        final double scaleUp = overflow > 0 && height > 0
            ? (height + overflow) / height
            : 1;

        // `calculateSheetPredictiveBackScaleX` / `ScaleY`.
        final double scaleX = width == 0
            ? 1
            : 1 -
                  lerpDouble(
                        0,
                        math.min(
                          M3BottomSheetDefaults.predictiveBackMaxScaleXDistance,
                          width,
                        ),
                        progress,
                      )! /
                      width;
        final double scaleY = height == 0
            ? 1
            : 1 -
                  lerpDouble(
                        0,
                        math.min(
                          M3BottomSheetDefaults.predictiveBackMaxScaleYDistance,
                          height,
                        ),
                        progress,
                      )! /
                      height;

        Widget body = child!;
        if (scaleUp != 1) {
          body = Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.diagonal3Values(1, 1 / scaleUp, 1),
            child: body,
          );
        }
        if (progress != 0 && scaleY != 0) {
          // `contentPredictiveBackScaling`.
          body = Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.diagonal3Values(1, scaleX / scaleY, 1),
            child: body,
          );
        }

        // `modalWindowInsets` = safeDrawing сверху и снизу. Верхний inset
        // съедается сдвигом листа (`SheetWindowInsets`).
        body = Padding(
          padding: EdgeInsets.only(
            top: math.max(0, media.padding.top - offset),
            bottom: math.max(media.viewPadding.bottom, media.viewInsets.bottom),
          ),
          child: body,
        );

        Widget surface = Material(
          color: scheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shadowColor: scheme.shadow,
          elevation: M3BottomSheetDefaults.elevation,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(M3BottomSheetDefaults.cornerRadius),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: body,
        );
        if (scaleUp != 1) {
          surface = Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.diagonal3Values(1, scaleUp, 1),
            child: surface,
          );
        }
        if (progress != 0 && height != 0) {
          // `sheetPredictiveBackScaling`: TransformOrigin(0.5, (offset + h) / h).
          surface = Transform(
            origin: Offset(width / 2, offset + height),
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: surface,
          );
        }
        return surface;
      },
    );

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _settleToDismiss();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            sortKey: const OrdinalSortKey(1),
            label: dismissible ? M3BottomSheetDefaults.scrimLabel : null,
            onTap: dismissible ? _hide : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: dismissible ? _hide : null,
              child: AnimatedBuilder(
                animation: _scrim,
                builder: (context, _) => ColoredBox(
                  color: scheme.scrim.withValues(
                    alpha: M3BottomSheetDefaults.scrimOpacity * _scrim.value,
                  ),
                ),
              ),
            ),
          ),
          _SheetLayout(
            state: this,
            child: Semantics(
              sortKey: const OrdinalSortKey(0),
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: MaterialLocalizations.of(context).bottomSheetLabel,
              child: GestureDetector(
                onVerticalDragStart: canDragSurface ? _handleDragStart : null,
                onVerticalDragUpdate: canDragSurface ? _handleDragUpdate : null,
                onVerticalDragEnd: canDragSurface ? _handleDragEnd : null,
                onVerticalDragCancel: canDragSurface ? _handleDragCancel : null,
                excludeFromSemantics: true,
                child: sheet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `BottomSheetDefaults.DragHandle` в `DragHandleWithTooltip`.
class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.onTap,
    required this.onDismiss,
    required this.onExpand,
    required this.onCollapse,
  });

  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onExpand;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const Size size = M3BottomSheetDefaults.dragHandleSize;
    return Center(
      child: Semantics(
        container: true,
        button: true,
        label: M3BottomSheetDefaults.dragHandleLabel,
        onTap: onTap,
        onDismiss: onDismiss,
        onExpand: onExpand,
        onCollapse: onCollapse,
        excludeSemantics: true,
        child: Tooltip(
          message: M3BottomSheetDefaults.dragHandleLabel,
          excludeFromSemantics: true,
          child: InkWell(
            onTap: onTap,
            // Ripple цветом содержимого листа (`contentColorFor`).
            overlayColor: AppStateLayer.overlay(scheme.onSurface),
            child: Padding(
              // Зона нажатия 48dp (Guidelines → Accessibility), сама ручка —
              // 32×4 с полями 22dp.
              padding: const EdgeInsets.symmetric(
                horizontal: (48 - 32) / 2,
                vertical: M3BottomSheetDefaults.dragHandleVerticalPadding,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(size.height / 2),
                ),
                child: SizedBox.fromSize(size: size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кладёт лист по горизонтали в центр (до 640dp) и по вертикали — на сдвиг
/// из состояния, заодно сообщая ему размеры для якорей.
class _SheetLayout extends SingleChildRenderObjectWidget {
  const _SheetLayout({required this.state, required super.child});

  final _M3SheetState state;

  @override
  _RenderSheetLayout createRenderObject(BuildContext context) =>
      _RenderSheetLayout(state);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetLayout renderObject,
  ) {
    renderObject.state = state;
  }
}

class _RenderSheetLayout extends RenderShiftedBox {
  _RenderSheetLayout(this._state) : super(null);

  _M3SheetState _state;
  set state(_M3SheetState value) {
    if (identical(value, _state)) return;
    if (attached) _state._offset.removeListener(markNeedsLayout);
    _state = value;
    if (attached) _state._offset.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _state._offset.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _state._offset.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final RenderBox? child = this.child;
    if (child == null) return;
    final double width = math.min(M3BottomSheetDefaults.maxWidth, size.width);
    child.layout(
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
      parentUsesSize: true,
    );
    final double top = _state._layoutSheet(
      size.height,
      child.size.height,
      width,
    );
    (child.parentData! as BoxParentData).offset = Offset(
      (size.width - width) / 2,
      top,
    );
  }
}

/// Контроллер прокрутки содержимого: жест делится между списком и листом.
class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);

  final _M3SheetState sheet;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SheetScrollPosition(
      sheet: sheet,
      // Короткий список тоже должен передавать жест листу.
      physics: physics.applyTo(const AlwaysScrollableScrollPhysics()),
      context: context,
      oldPosition: oldPosition,
    );
  }
}

/// Порт `ConsumeSwipeWithinBottomSheetBoundsNestedScrollConnection`.
class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final _M3SheetState sheet;

  @override
  void applyUserOffset(double delta) {
    if (!sheet._gesturesEnabled) {
      super.applyUserOffset(delta);
      return;
    }
    if (delta < 0) {
      // `onPreScroll`: жест вверх сначала раскрывает лист.
      final double consumed = sheet._dragBy(delta, fromScroll: true);
      final double rest = delta - consumed;
      if (rest != 0) super.applyUserOffset(rest);
    } else if (delta > 0) {
      // `onPostScroll`: жест вниз сначала прокручивает список к началу,
      // остаток опускает лист.
      final double listPart = math.min(
        delta,
        math.max(0.0, pixels - minScrollExtent),
      );
      if (listPart > 0) super.applyUserOffset(listPart);
      final double rest = delta - listPart;
      if (rest > 0) sheet._dragBy(rest, fromScroll: true);
    }
  }

  @override
  void goBallistic(double velocity) {
    if (!sheet._dragging || !sheet._dragFromScroll) {
      super.goBallistic(velocity);
      return;
    }
    // Скорость листа: вниз — положительная, как в Compose.
    final double sheetVelocity = -velocity;
    if (sheetVelocity < 0 && sheet._currentOffset > sheet._minAnchor) {
      // `onPreFling`: бросок вверх, лист ещё не раскрыт — весь бросок листу.
      super.goBallistic(0);
      sheet._settle(sheetVelocity);
      return;
    }
    // `onPostFling`.
    super.goBallistic(velocity);
    sheet._settle(sheetVelocity);
  }
}
