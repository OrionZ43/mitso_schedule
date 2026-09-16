import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/compose_spring.dart';
import 'm3_loading_indicator.dart';

/// Pull-to-refresh Material 3 Expressive с loading indicator — порт Compose
/// Material3 `Modifier.pullToRefresh` (`PullToRefreshModifierNode`) и
/// `PullToRefreshDefaults.LoadingIndicator` (`pulltorefresh/PullToRefresh.kt`).
///
/// Гайдлайн loading indicator (Behavior → Pull-to-refresh, Container) называет
/// индикатором pull-to-refresh именно loading indicator с контейнером.
/// Штатный `RefreshIndicator` Flutter рисует круговую шкалу и не отдаёт долю
/// протяжки, поэтому жест обрабатывается здесь.
///
/// **Жест.** В Compose узел — `NestedScrollConnection`: `onPreScroll`
/// забирает движение пальца вверх, пока индикатор вытянут, `onPostScroll` —
/// остаток движения вниз, который список не смог прокрутить. Во Flutter
/// вложенной прокрутки нет, поэтому то же место занимает
/// `ScrollPhysics.applyPhysicsToUserOffset`: физика подмешивается всем
/// вертикальным спискам внутри [child] через [ScrollConfiguration] и сначала
/// отдаёт смещение пальца протяжке, а затем списку. Протяжка не срабатывает,
/// если физика списка не передаёт `applyPhysicsToUserOffset` родителю
/// (`BouncingScrollPhysics`) или список короче экрана без
/// `AlwaysScrollableScrollPhysics`.
///
/// **Отпускание.** Compose реагирует в `onPreFling`, то есть когда палец
/// отпущен. Здесь то же самое ловит [Listener] по `PointerUp`/`PointerCancel`
/// последнего пальца.
///
/// **Обновление.** Индикатор держится на пороге, пока идёт `Future` из
/// [onRefresh] или пока [isRefreshing] равно `true` (как у
/// `PullToRefreshBox`, например при обновлении кнопкой — гайдлайн требует
/// такую альтернативу жесту).
///
/// Уменьшение движения: пружины положения и кросс-фейд завершаются сразу,
/// как в Compose при `MotionDurationScale` = 0; следование за пальцем — прямое
/// управление, оно остаётся.
class M3PullToRefresh extends StatefulWidget {
  const M3PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.isRefreshing,
    this.edgeOffset = 0,
    this.semanticsLabel = 'Обновление расписания',
  });

  /// Вызывается, когда протяжка отпущена дальше порога.
  final Future<void> Function() onRefresh;

  /// Прокручиваемое содержимое.
  final Widget child;

  /// Внешний признак обновления (`PullToRefreshBox.isRefreshing`). `true` —
  /// индикатор выезжает к порогу и показывает неопределённый морф, `false` —
  /// уходит, если не ждёт [onRefresh].
  final bool? isRefreshing;

  /// Отступ верхней кромки области, из-под которой выезжает индикатор,
  /// например высота закреплённого app bar.
  final double edgeOffset;

  /// Подпись индикатора для TalkBack.
  final String? semanticsLabel;

  /// `PullToRefreshDefaults.PositionalThreshold`.
  static const double positionalThreshold = 80;

  /// `PullToRefreshDefaults.IndicatorMaxDistance` = порог.
  static const double indicatorMaxDistance = positionalThreshold;

  /// `DragMultiplier`: палец проходит 160dp, индикатор — 80dp.
  static const double dragMultiplier = 0.5;

  /// `LoaderIndicatorWidth` / `LoaderIndicatorHeight` =
  /// `LoadingIndicatorDefaults.ContainerWidth` / `ContainerHeight`.
  static const double indicatorSize = M3LoadingIndicator.containerSize;

  /// `animateToThreshold` / `animateToHidden`: `Animatable.animateTo` со
  /// `spring()` по умолчанию — `DampingRatioNoBouncy`, `StiffnessMedium`,
  /// порог `DefaultDisplacementThreshold`.
  static const double positionSpringDampingRatio =
      ComposeSpringSimulation.dampingRatioNoBouncy;
  static const double positionSpringStiffness =
      ComposeSpringSimulation.stiffnessMedium;

  /// `calculateVerticalOffset`: до порога смещение равно скорректированной
  /// протяжке, дальше растёт «упруго» и не превышает двух порогов.
  static double calculateVerticalOffset(
    double adjustedDistancePulled, {
    double threshold = positionalThreshold,
  }) {
    if (adjustedDistancePulled <= threshold) return adjustedDistancePulled;
    final double overshootPercent =
        (adjustedDistancePulled / threshold).abs() - 1;
    final double linearTension = overshootPercent.clamp(0.0, 2.0);
    final double tensionPercent =
        linearTension - linearTension * linearTension / 4;
    return threshold + threshold * tensionPercent;
  }

  @override
  State<M3PullToRefresh> createState() => _M3PullToRefreshState();
}

class _M3PullToRefreshState extends State<M3PullToRefresh>
    with TickerProviderStateMixin {
  /// `PullToRefreshState.distanceFraction` (`Animatable`).
  late final AnimationController _fraction = AnimationController.unbounded(
    vsync: this,
    value: (widget.isRefreshing ?? false) ? 1 : 0,
  );

  /// Кросс-фейд `Crossfade(targetState = isRefreshing)`: 0 — определённый
  /// индикатор, 1 — неопределённый.
  late final AnimationController _crossfade = AnimationController.unbounded(
    vsync: this,
    value: (widget.isRefreshing ?? false) ? 1 : 0,
  );

  double _distancePulled = 0;
  double _verticalOffset = 0;
  bool _awaitingRefresh = false;
  bool _lastRefreshing = false;

  /// Цель текущей анимации [_fraction].
  double? _fractionTarget;

  final Set<int> _pointers = <int>{};

  late final _PullToRefreshScrollPhysics _physics = _PullToRefreshScrollPhysics(
    _handleUserOffset,
  );
  ScrollBehavior? _parentBehavior;
  TargetPlatform? _parentPlatform;
  ScrollBehavior? _behavior;

  bool get _isRefreshing => (widget.isRefreshing ?? false) || _awaitingRefresh;

  double get _adjustedDistancePulled =>
      _distancePulled * M3PullToRefresh.dragMultiplier;

  @override
  void initState() {
    super.initState();
    _lastRefreshing = _isRefreshing;
    // `onAttach`.
    if (_isRefreshing) {
      _verticalOffset = M3PullToRefresh.positionalThreshold;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollBehavior parent = ScrollConfiguration.of(context);
    final TargetPlatform platform = parent.getPlatform(context);
    if (!identical(parent, _parentBehavior) || platform != _parentPlatform) {
      _parentBehavior = parent;
      _parentPlatform = platform;
      _behavior = parent.copyWith(
        physics: _physics.applyTo(parent.getScrollPhysics(context)),
      );
    }
  }

  @override
  void didUpdateWidget(M3PullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRefreshing();
  }

  @override
  void dispose() {
    _fraction.dispose();
    _crossfade.dispose();
    super.dispose();
  }

  /// `PullToRefreshElement.update` → `node.update()`: смена признака
  /// обновления ведёт индикатор к порогу или прячет его.
  void _syncRefreshing() {
    final bool refreshing = _isRefreshing;
    if (refreshing == _lastRefreshing) return;
    _lastRefreshing = refreshing;
    if (refreshing) {
      _animateFraction(1);
    } else {
      _animateFraction(0);
    }
    _animateCrossfade(refreshing ? 1 : 0);
  }

  /// `consumeAvailableOffset`: во время обновления протяжка не принимается.
  double _consumeAvailableOffset(double available) {
    if (_isRefreshing || available == 0) return 0;
    final double newOffset = math.max(0.0, _distancePulled + available);
    final double consumed = newOffset - _distancePulled;
    _distancePulled = newOffset;
    _verticalOffset = M3PullToRefresh.calculateVerticalOffset(
      _adjustedDistancePulled,
    );
    return consumed;
  }

  /// Смещение пальца для вертикального списка. Возвращает часть, которая
  /// достаётся самому списку.
  ///
  /// Знак как в Compose: положительное — палец идёт вниз.
  double _handleUserOffset(ScrollMetrics position, double offset) {
    if (!mounted ||
        offset == 0 ||
        position.axisDirection != AxisDirection.down) {
      return offset;
    }
    // `state.isAnimating -> Offset.Zero` в `onPreScroll` и `onPostScroll`.
    if (_fraction.isAnimating) return offset;

    double consumed = 0;
    // `onPreScroll`: палец идёт вверх — сначала сворачивается протяжка.
    if (offset < 0) consumed += _consumeAvailableOffset(offset);

    // Сколько прокрутит сам список (зажатый у краёв).
    final double afterPreScroll = offset - consumed;
    final double listConsumed = afterPreScroll > 0
        ? math.min(
            afterPreScroll,
            math.max(0.0, position.pixels - position.minScrollExtent),
          )
        : math.max(
            afterPreScroll,
            -math.max(0.0, position.maxScrollExtent - position.pixels),
          );

    // `onPostScroll`: остаток уходит в протяжку, затем
    // `state.snapTo(verticalOffset / threshold)`.
    consumed += _consumeAvailableOffset(afterPreScroll - listConsumed);
    final double fraction =
        _verticalOffset / M3PullToRefresh.positionalThreshold;
    if (_fraction.value != fraction) _fraction.value = fraction;

    return offset - consumed;
  }

  void _handlePointerDown(PointerDownEvent event) =>
      _pointers.add(event.pointer);

  void _handlePointerEnd(PointerEvent event) {
    if (!_pointers.remove(event.pointer) || _pointers.isNotEmpty) return;
    _onRelease();
  }

  /// `onRelease`: обновление, только если протяжка строго больше порога,
  /// затем индикатор уходит.
  void _onRelease() {
    if (_isRefreshing) return;
    final bool pulled = _distancePulled != 0;
    if (_adjustedDistancePulled > M3PullToRefresh.positionalThreshold) {
      _startRefresh();
      if (_isRefreshing) return;
    }
    if (_fraction.isAnimating && _fractionTarget == 0) return;
    if (pulled || _fraction.value != 0) _animateFraction(0);
  }

  void _startRefresh() {
    setState(() => _awaitingRefresh = true);
    _syncRefreshing();
    widget.onRefresh().whenComplete(() {
      if (!mounted) return;
      setState(() => _awaitingRefresh = false);
      _syncRefreshing();
    });
  }

  /// `animateToThreshold` (1) / `animateToHidden` (0) и их `finally`.
  void _animateFraction(double target) {
    _fractionTarget = target;
    void onEnd() {
      if (!mounted) return;
      if (target == 0) {
        _distancePulled = 0;
        _verticalOffset = 0;
      } else {
        _distancePulled = M3PullToRefresh.positionalThreshold;
        _verticalOffset = M3PullToRefresh.positionalThreshold;
      }
    }

    if (reduceMotionOf(context)) {
      _fraction.value = target;
      onEnd();
      return;
    }
    final ComposeSpringSimulation simulation = ComposeSpringSimulation(
      dampingRatio: M3PullToRefresh.positionSpringDampingRatio,
      stiffness: M3PullToRefresh.positionSpringStiffness,
      start: _fraction.value,
      end: target,
      velocity: _fraction.velocity,
    );
    _fraction.animateWith(simulation).whenCompleteOrCancel(onEnd);
  }

  /// `Crossfade(animationSpec = MotionSchemeKeyTokens.DefaultEffects)`.
  void _animateCrossfade(double target) {
    if (reduceMotionOf(context)) {
      _crossfade.value = target;
      return;
    }
    _crossfade.animateWith(
      ComposeSpringSimulation(
        dampingRatio: AppMotion.defaultEffects.dampingRatio,
        stiffness: AppMotion.defaultEffects.stiffness,
        start: _crossfade.value,
        end: target,
        velocity: _crossfade.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: Stack(
        children: [
          ScrollConfiguration(behavior: _behavior!, child: widget.child),
          Positioned(
            top: widget.edgeOffset,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fraction, _crossfade]),
                builder: (context, _) => _buildIndicator(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `PullToRefreshDefaults.LoadingIndicator` в `IndicatorBox`.
  Widget _buildIndicator(BuildContext context) {
    final double fraction = _fraction.value;
    final double crossfade = _crossfade.value.clamp(0.0, 1.0);
    // Спрятанный индикатор целиком над кромкой и обрезан; из дерева его
    // убираем, чтобы не держать тикер и узел семантики.
    if (fraction <= 0 && !_isRefreshing) return const SizedBox.shrink();

    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool refreshing = _isRefreshing;

    // Пока тянут: определённый индикатор; после порога весь компонент ещё
    // поворачивается на `-(progress − 1) × 180°`.
    final Widget determinate = Transform.rotate(
      angle: fraction > 1 ? -(fraction - 1) * math.pi : 0,
      child: M3LoadingIndicator.determinate(
        key: const ValueKey('pulling'),
        progress: fraction,
        contained: true,
        semanticsLabel: widget.semanticsLabel,
      ),
    );
    final Widget indeterminate = M3LoadingIndicator(
      key: const ValueKey('refreshing'),
      contained: true,
      semanticsLabel: widget.semanticsLabel,
    );

    return ClipRect(
      // `clipRect(top = 0)`: индикатор выезжает из-под верхней кромки.
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          // `translationY = distanceFraction × maxDistance − size.height`.
          offset: Offset(
            0,
            fraction * M3PullToRefresh.indicatorMaxDistance -
                M3PullToRefresh.indicatorSize,
          ),
          child: SizedBox.square(
            dimension: M3PullToRefresh.indicatorSize,
            // `shape = indicatorShape`, `clip = true`, фон контейнера;
            // `LoadingIndicatorElevation` = Level0 — без тени.
            child: ClipOval(
              child: ColoredBox(
                color: colors.primaryContainer,
                child: Stack(
                  children: [
                    if (crossfade < 1)
                      Opacity(
                        opacity: 1 - crossfade,
                        child: ExcludeSemantics(
                          excluding: refreshing,
                          child: determinate,
                        ),
                      ),
                    if (crossfade > 0)
                      Opacity(
                        opacity: crossfade,
                        child: ExcludeSemantics(
                          excluding: !refreshing,
                          child: indeterminate,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Физика-посредник: отдаёт смещение пальца протяжке раньше списка.
class _PullToRefreshScrollPhysics extends ScrollPhysics {
  const _PullToRefreshScrollPhysics(this.onUserOffset, {super.parent});

  final double Function(ScrollMetrics position, double offset) onUserOffset;

  @override
  _PullToRefreshScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _PullToRefreshScrollPhysics(onUserOffset, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, onUserOffset(position, offset));
}
