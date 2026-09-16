import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Plain tooltip Material 3 Expressive — подпись к иконке-кнопке или FAB.
///
/// Источники:
///   * https://m3.material.io/components/tooltips — токены
///     `md.comp.plain-tooltip.*`, Placement, Behavior
///     (выгрузка `.m3-guidelines/components__tooltips.md`);
///   * Compose `Tooltip.kt` (`TooltipBox`: `scaleSpec` / `alphaSpec`;
///     `PlainTooltip`; `TooltipPositionProviderImpl`;
///     `SpacingBetweenTooltipAndAnchor`, `TooltipMinWidth`, `TooltipMinHeight`,
///     `PlainTooltipContentPadding`, `plainTooltipMaxWidth`),
///     `internal/BasicTooltip.kt` (`handleGestures`, `keyboardBehavior`,
///     `TooltipDuration`), `tokens/PlainTooltipTokens.kt`.
///
/// Построен на `RawTooltip` (жесты, оверлей, семантика `tooltip`, закрытие по
/// касанию в другом месте и «одна подсказка за раз»). Отличия от Material
/// `Tooltip` Flutter:
///   * вид по токенам: `inverseSurface`, `bodySmall` / `onInverseSurface`,
///     углы 4dp, поля 8×4, мин. 40×24, макс. ширина 200;
///   * над элементом с зазором 4dp от его видимой границы, в app bar
///     ([preferBelow]) — под ним; по горизонтали по центру и в пределах экрана
///     (`abovePositioning` / `belowPositioning`);
///   * появление и скрытие — масштаб 0.8 ↔ 1 пружиной `FastSpatial` и
///     прозрачность пружиной `FastEffects`, как `TooltipBox`;
///   * скрытие через 1,5 с после того, как палец отпущен: «disappear 1.5
///     seconds after navigating away from the target region» (Behavior);
///   * с клавиатуры подсказка видна, пока элемент в фокусе, Escape закрывает
///     (`keyboardBehavior`).
class M3PlainTooltip extends StatefulWidget {
  const M3PlainTooltip({
    super.key,
    required this.message,
    required this.child,
    this.preferBelow,
    this.anchorPadding = EdgeInsets.zero,
  });

  final String message;
  final Widget child;

  /// Под элементом — для кнопок в app bar (Guidelines → Placement).
  final bool? preferBelow;

  /// Расстояние от границы [child] до его видимой границы. Зазор 4dp
  /// отсчитывается от видимой границы («If there's a visual boundary, like a
  /// button, the distance is 4dp»). Для `IconButton` —
  /// [iconButtonPadding]: контейнер 40dp внутри зоны касания 48dp.
  final EdgeInsetsGeometry anchorPadding;

  /// `IconButton` M3: контейнер 40dp (`_IconButtonDefaultsM3.minimumSize`) в
  /// зоне касания 48dp (`MaterialTapTargetSize.padded`).
  static const EdgeInsets iconButtonPadding = EdgeInsets.all(4);

  /// `SpacingBetweenTooltipAndAnchor`.
  static const double spacing = 4;

  /// `TooltipMinWidth`, `TooltipMinHeight`, `plainTooltipMaxWidth`.
  static const double minWidth = 40;
  static const double minHeight = 24;
  static const double maxWidth = 200;

  /// `PlainTooltipContentPadding`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );

  /// `BasicTooltipDefaults.TooltipDuration`.
  static const Duration showDuration = Duration(milliseconds: 1500);

  @override
  State<M3PlainTooltip> createState() => _M3PlainTooltipState();
}

class _M3PlainTooltipState extends State<M3PlainTooltip> {
  final GlobalKey<RawTooltipState> _rawKey = GlobalKey<RawTooltipState>();
  bool _shownByFocus = false;

  bool get _keyboardMode =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _handleFocusChange(bool focused) {
    if (focused && _keyboardMode) {
      RawTooltip.dismissAllToolTips();
      _rawKey.currentState?.ensureTooltipVisible();
      _shownByFocus = true;
    } else if (!focused && _shownByFocus) {
      _shownByFocus = false;
      RawTooltip.dismissAllToolTips();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _shownByFocus) {
      _shownByFocus = false;
      RawTooltip.dismissAllToolTips();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// `TooltipPositionProviderImpl.abovePositioning` / `belowPositioning`,
  /// якорь — видимая граница элемента.
  Offset _position(TooltipPositionContext context) {
    final Rect bounds = Rect.fromCenter(
      center: context.target,
      width: context.targetSize.width,
      height: context.targetSize.height,
    );
    final Rect anchor = widget.anchorPadding
        .resolve(Directionality.of(this.context))
        .deflateRect(bounds);
    final Size tooltip = context.tooltipSize;
    final Size window = context.overlaySize;
    const double spacing = M3PlainTooltip.spacing;

    final double x = (anchor.left + (anchor.width - tooltip.width) / 2).clamp(
      0.0,
      math.max(0.0, window.width - tooltip.width),
    );

    double y;
    if (widget.preferBelow ?? M3TooltipBelowScope.of(this.context)) {
      y = anchor.bottom + spacing;
      if (y + tooltip.height > window.height) {
        y = anchor.top - tooltip.height - spacing;
      }
    } else {
      y = anchor.top - tooltip.height - spacing;
      if (y < 0) y = anchor.bottom + spacing;
    }
    y = y.clamp(0.0, math.max(0.0, window.height - tooltip.height));
    return Offset(x, y);
  }

  Widget _buildTooltip(BuildContext context, Animation<double> animation) {
    final ColorScheme colors = context.colors;
    final TextStyle style = context.text.bodySmall!.copyWith(
      color: colors.onInverseSurface,
    );
    return _TooltipTransition(
      animation: animation,
      scaleEnabled: !reduceMotionOf(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: M3PlainTooltip.minWidth,
          maxWidth: M3PlainTooltip.maxWidth,
          minHeight: M3PlainTooltip.minHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.inverseSurface,
            borderRadius: AppShapes.all(AppShapes.extraSmall),
          ),
          child: Padding(
            padding: M3PlainTooltip.padding,
            child: DefaultTextStyle(
              style: style,
              child: Text(widget.message, style: style),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `RawTooltip` ставит `Semantics(tooltip)` снаружи [child]. У кнопок свой
    // семантический контейнер, поэтому без слияния подсказка оказалась бы в
    // соседнем узле, а не у кнопки (у Flutter `IconButton` `Tooltip` лежит
    // внутри контейнера). Plain tooltip подписывает один элемент — сливаем.
    return MergeSemantics(child: _buildAnchor());
  }

  Widget _buildAnchor() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKey,
      child: RawTooltip(
        key: _rawKey,
        semanticsTooltip: widget.message,
        tooltipBuilder: _buildTooltip,
        triggerMode: TooltipTriggerMode.longPress,
        touchDelay: M3PlainTooltip.showDuration,
        // Уход курсора — те же 1,5 с (Behavior → Transient by default).
        dismissDelay: M3PlainTooltip.showDuration,
        // `handleGestures` в Compose не даёт тактильного отклика.
        enableFeedback: false,
        // Оверлей держится, пока не закончатся обе пружины скрытия.
        animationStyle: AnimationStyle(
          curve: Curves.linear,
          duration: AppMotion.fastSpatial.duration,
          reverseDuration: AppMotion.fastSpatial.duration,
        ),
        positionDelegate: _position,
        ignorePointer: true,
        child: widget.child,
      ),
    );
  }
}

/// `TooltipBox`: `graphicsLayer { scaleX = scaleY = scale; alpha = alpha }`,
/// масштаб 0.8 ↔ 1 — `FastSpatial`, прозрачность 0 ↔ 1 — `FastEffects`.
///
/// `RawTooltip` отдаёт одну анимацию с кривой; по её направлению здесь
/// запускаются две пружины, которые при смене направления сохраняют скорость.
class _TooltipTransition extends StatefulWidget {
  const _TooltipTransition({
    required this.animation,
    required this.scaleEnabled,
    required this.child,
  });

  final Animation<double> animation;

  /// При уменьшении движения — только прозрачность.
  final bool scaleEnabled;

  final Widget child;

  @override
  State<_TooltipTransition> createState() => _TooltipTransitionState();
}

class _TooltipTransitionState extends State<_TooltipTransition>
    with TickerProviderStateMixin {
  static const double _hiddenScale = 0.8;

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: _hiddenScale,
  );
  late final AnimationController _alpha = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  bool? _visible;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
    _handleStatus(widget.animation.status);
  }

  @override
  void didUpdateWidget(_TooltipTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
      _handleStatus(widget.animation.status);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    _scale.dispose();
    _alpha.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    final bool visible = status.isForwardOrCompleted;
    if (visible == _visible) return;
    _visible = visible;
    _springTo(_scale, visible ? 1 : _hiddenScale, AppMotion.fastSpatial);
    _springTo(_alpha, visible ? 1 : 0, AppMotion.fastEffects);
  }

  void _springTo(AnimationController controller, double target, M3Spring s) {
    controller.animateWith(
      SpringSimulation(
        s.description,
        controller.value,
        target,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scale, _alpha]),
      builder: (context, child) => Opacity(
        opacity: _alpha.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: widget.scaleEnabled ? _scale.value : 1,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Подсказки внутри — под элементом (plain tooltip → Guidelines → Placement:
/// «If the element is in an app bar, place the tooltip below it»). App bars
/// оборачивают свои кнопки в эту область.
class M3TooltipBelowScope extends InheritedWidget {
  const M3TooltipBelowScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<M3TooltipBelowScope>() != null;

  @override
  bool updateShouldNotify(M3TooltipBelowScope oldWidget) => false;
}
