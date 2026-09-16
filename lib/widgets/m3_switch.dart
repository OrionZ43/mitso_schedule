import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_motion.dart';
import '../theme/app_state_layer.dart';
import 'm3_radial_ink.dart';

/// Какие иконки показывать в ручке (Specs → Configurations).
enum M3SwitchIcons {
  /// Без иконок.
  none,

  /// Галочка только во включённом состоянии — как переключатель M3 в
  /// «Differences from M2» и `SwitchWithThumbIconSample` в Compose.
  selectedOnly,

  /// Галочка во включённом и крестик в выключенном (Guidelines → Icon, DO).
  both,
}

/// Переключатель Material 3 Expressive — порт Compose `Switch`.
///
/// Источники:
///   * https://m3.material.io/components/switch/specs — токены и размеры
///     (выгрузка `.m3-guidelines/components__switch.md`);
///   * Compose `Switch.kt` (`SwitchImpl`, `ThumbNode.measure`,
///     `SwitchDefaults.colors`) и `tokens/SwitchTokens.kt` — движение и цвета.
///
/// Flutter `Switch` анимирует ручку 300 мс `easeOutBack` с промежуточным
/// размером 34×22 (MDC baseline) и плавно меняет цвета; настроить это нельзя.
/// Здесь, как в Compose:
///   * размер и положение ручки ведут две пружины `FastSpatial`, которые при
///     смене цели сохраняют скорость (`Animatable.animateTo`);
///   * при нажатии ручка мгновенно (`SnapSpec`) становится 28dp и сдвигается
///     к краю на толщину обводки, центр остаётся на месте;
///   * цвета берутся по состоянию без интерполяции;
///   * ripple неограниченный, радиус 20dp, центр в ручке.
///
/// Перетаскивание ручки (как у Flutter `Switch`) добавлено сверх Compose, где
/// его нет (`TODO: Add Swipeable modifier b/223797571`): спека требует, чтобы
/// ручка росла «when tapped or dragged» (Accessibility → Interaction & style).
class M3Switch extends StatefulWidget {
  const M3Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.icons = M3SwitchIcons.selectedOnly,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;

  /// `null` — переключатель недоступен (disabled).
  final ValueChanged<bool>? onChanged;

  final M3SwitchIcons icons;
  final FocusNode? focusNode;
  final bool autofocus;

  /// `md.comp.switch.track.width` / `.height` / `.outline.width`.
  static const double trackWidth = 52;
  static const double trackHeight = 32;
  static const double trackOutlineWidth = 2;

  /// `md.comp.switch.unselected.handle.width`.
  static const double unselectedHandleSize = 16;

  /// `md.comp.switch.selected.handle.width` = `with-icon.handle.width`.
  static const double selectedHandleSize = 24;

  /// `md.comp.switch.pressed.handle.width`.
  static const double pressedHandleSize = 28;

  /// `md.comp.switch.selected.icon.size`, `SwitchDefaults.IconSize`.
  static const double iconSize = 16;

  /// Зона нажатия (Specs → Measurements → Target, `minimumInteractiveComponentSize`).
  static const double targetSize = 48;

  /// Ключи для тестов.
  @visibleForTesting
  static const Key handleKey = ValueKey<String>('M3Switch.handle');
  @visibleForTesting
  static const Key trackKey = ValueKey<String>('M3Switch.track');

  @override
  State<M3Switch> createState() => _M3SwitchState();
}

class _M3SwitchState extends State<M3Switch> with TickerProviderStateMixin {
  late final AnimationController _size;
  late final AnimationController _offset;
  final M3RadialInkController _ink = M3RadialInkController();

  double? _sizeTarget;
  double? _offsetTarget;

  bool _pressed = false;
  bool _dragging = false;
  bool _hovered = false;
  bool _focused = false;
  bool _reduceMotion = false;
  bool _retargetScheduled = false;

  /// Значение, отправленное в `onChanged` после перетаскивания, пока родитель
  /// не перестроил виджет (`_needsPositionAnimation` во Flutter `Switch`).
  bool? _pendingValue;

  bool get _enabled => widget.onChanged != null;
  bool get _value => _pendingValue ?? widget.value;
  bool get _isPressed => _pressed || _dragging;

  /// `ThumbNode.measure`: `hasContent` — у ручки есть иконка.
  bool get _hasIcon => switch (widget.icons) {
    M3SwitchIcons.none => false,
    M3SwitchIcons.selectedOnly => _value,
    M3SwitchIcons.both => true,
  };

  /// `ThumbNode.measure` → `size`.
  double get _targetSize {
    if (_isPressed) return M3Switch.pressedHandleSize;
    if (_hasIcon || _value) return M3Switch.selectedHandleSize;
    return M3Switch.unselectedHandleSize;
  }

  /// Край трека, к которому прижата ручка 24dp: `ThumbPadding` = 4dp.
  static const double _thumbPadding =
      (M3Switch.trackHeight - M3Switch.selectedHandleSize) / 2;

  /// `maxBound` = `(SwitchWidth - ThumbDiameter) - ThumbPadding`.
  static const double _maxBound =
      (M3Switch.trackWidth - M3Switch.selectedHandleSize) - _thumbPadding;

  /// Смещения нажатой ручки, между ними ходит перетаскивание.
  static const double _pressedMin = M3Switch.trackOutlineWidth;
  static const double _pressedMax = _maxBound - M3Switch.trackOutlineWidth;

  /// `ThumbNode.measure` → `offset` (левый край ручки внутри трека, LTR).
  double _targetOffset(double size) {
    if (_isPressed) return _value ? _pressedMax : _pressedMin;
    return _value ? _maxBound : (M3Switch.trackHeight - size) / 2;
  }

  @override
  void initState() {
    super.initState();
    final double size = _targetSize;
    final double offset = _targetOffset(size);
    _sizeTarget = size;
    _offsetTarget = offset;
    _size = AnimationController.unbounded(vsync: this, value: size);
    _offset = AnimationController.unbounded(vsync: this, value: offset);
  }

  @override
  void didUpdateWidget(M3Switch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pendingValue = null;
    if (!_enabled) {
      _pressed = false;
      _dragging = false;
      _hovered = false;
      _focused = false;
    }
    _retarget();
    _ink.recolor(
      pressed: _stateLayer(WidgetState.pressed),
      hovered: _stateLayer(WidgetState.hovered),
      focused: _stateLayer(WidgetState.focused),
    );
  }

  @override
  void dispose() {
    _size.dispose();
    _offset.dispose();
    super.dispose();
  }

  /// Compose пересчитывает цели в `measure`, то есть раз в кадр: нажатие и
  /// отпускание в одном кадре не дают вспышки 28dp. Так же и здесь — цели
  /// жестов применяются в начале следующего кадра.
  void _scheduleRetarget() {
    if (_retargetScheduled) return;
    _retargetScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _retargetScheduled = false;
      if (mounted) _retarget();
    });
  }

  void _retarget() {
    final double size = _targetSize;
    if (_sizeTarget != size) {
      _sizeTarget = size;
      _animate(_size, size, snap: _isPressed);
    }
    if (_dragging) {
      _offsetTarget = null;
      return;
    }
    final double offset = _targetOffset(size);
    if (_offsetTarget != offset) {
      _offsetTarget = offset;
      _animate(_offset, offset, snap: _isPressed);
    }
  }

  void _animate(
    AnimationController controller,
    double target, {
    required bool snap,
  }) {
    // Уменьшение движения: смена состояния без перемещения ручки.
    if (snap || _reduceMotion) {
      controller.value = target;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        AppMotion.fastSpatial.description,
        controller.value,
        target,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  // ---- Жесты ----

  void _handleTapDown(TapDownDetails details) {
    if (!_enabled) return;
    setState(() => _pressed = true);
    _ink.press(_stateLayer(WidgetState.pressed));
    _scheduleRetarget();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _ink.release();
    _scheduleRetarget();
  }

  void _handleTapCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _ink.cancel();
    _scheduleRetarget();
  }

  void _toggle() => widget.onChanged?.call(!widget.value);

  void _handleDragStart(DragStartDetails details) {
    if (!_enabled) return;
    if (!_pressed) _ink.press(_stateLayer(WidgetState.pressed));
    setState(() {
      _pressed = false;
      _dragging = true;
    });
    // Перетаскивание начинается от положения нажатой ручки.
    _sizeTarget = M3Switch.pressedHandleSize;
    _size.value = M3Switch.pressedHandleSize;
    _offset.value = _value ? _pressedMax : _pressedMin;
    _offsetTarget = null;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final double delta = details.primaryDelta ?? 0;
    final double ltrDelta = Directionality.of(context) == TextDirection.rtl
        ? -delta
        : delta;
    _offset.value = (_offset.value + ltrDelta).clamp(_pressedMin, _pressedMax);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    // Как `_handleDragEnd` во Flutter `Switch`: решает половина хода.
    final bool newValue = _offset.value >= (_pressedMin + _pressedMax) / 2;
    _ink.release();
    setState(() => _dragging = false);
    if (newValue != widget.value) {
      _pendingValue = newValue;
      widget.onChanged?.call(newValue);
      // Если родитель не принял значение, ручка вернётся на место.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingValue == null) return;
        setState(() => _pendingValue = null);
        _retarget();
      });
    }
    _retarget();
  }

  void _handleDragCancel() {
    if (!_dragging) return;
    _ink.cancel();
    setState(() => _dragging = false);
    _retarget();
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

  // ---- Цвета ----

  /// `md.comp.switch.{selected|unselected}.{pressed|hover|focus}.state-layer.color`
  /// = primary / on-surface; непрозрачность — `AppStateLayer`.
  Color _stateLayer(WidgetState state) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AppStateLayer.overlay(
          _value ? colors.primary : colors.onSurface,
        ).resolve({state}) ??
        Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = reduceMotionOf(context);
    final _SwitchColors colors = _SwitchColors.resolve(
      Theme.of(context).colorScheme,
      enabled: _enabled,
      selected: _value,
      interacted: _isPressed || _hovered || _focused,
    );
    final TextDirection direction = Directionality.of(context);

    final IconData? icon = switch (widget.icons) {
      M3SwitchIcons.none => null,
      M3SwitchIcons.selectedOnly => _value ? Symbols.check : null,
      M3SwitchIcons.both => _value ? Symbols.check : Symbols.close,
    };

    final Widget body = SizedBox(
      width: M3Switch.trackWidth,
      height: M3Switch.targetSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_size, _offset]),
        builder: (context, _) {
          final double size = math.max(_size.value, 0);
          final double left = direction == TextDirection.rtl
              ? M3Switch.trackWidth - _offset.value - size
              : _offset.value;
          final double centerX = left + size / 2;
          const double centerY = M3Switch.targetSize / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: (M3Switch.targetSize - M3Switch.trackHeight) / 2,
                width: M3Switch.trackWidth,
                height: M3Switch.trackHeight,
                child: DecoratedBox(
                  key: M3Switch.trackKey,
                  decoration: ShapeDecoration(
                    color: colors.track,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: colors.border,
                        width: M3Switch.trackOutlineWidth,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: centerY - size / 2,
                width: size,
                height: size,
                child: DecoratedBox(
                  key: M3Switch.handleKey,
                  decoration: BoxDecoration(
                    color: colors.handle,
                    shape: BoxShape.circle,
                  ),
                  child: icon == null
                      ? null
                      : Center(
                          child: Icon(
                            icon,
                            // Иконка 16dp внутри ручки, но не больше самой ручки.
                            size: math.min(M3Switch.iconSize, size),
                            opticalSize: 20,
                            color: colors.icon,
                          ),
                        ),
                ),
              ),
              // State layer поверх трека и ручки, как `indication` на ручке.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: centerX - M3RadialInkAnchor.size / 2,
                        top: centerY - M3RadialInkAnchor.size / 2,
                        child: M3RadialInkAnchor(controller: _ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        // Space и Enter → ActivateIntent (Accessibility → Keyboard navigation).
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
          onHorizontalDragStart: _enabled ? _handleDragStart : null,
          onHorizontalDragUpdate: _enabled ? _handleDragUpdate : null,
          onHorizontalDragEnd: _enabled ? _handleDragEnd : null,
          onHorizontalDragCancel: _enabled ? _handleDragCancel : null,
          child: body,
        ),
      ),
    );
  }
}

/// Цвета по токенам `md.comp.switch.*` (`SwitchTokens.kt`).
///
/// Цвет ручки при нажатии, наведении и фокусе берётся из токенов
/// `*.pressed/hover/focus.handle.color` (как в MDC и Flutter); `SwitchColors`
/// в Compose этих состояний не различает.
class _SwitchColors {
  const _SwitchColors({
    required this.track,
    required this.border,
    required this.handle,
    required this.icon,
  });

  final Color track;
  final Color border;
  final Color handle;
  final Color icon;

  static _SwitchColors resolve(
    ColorScheme c, {
    required bool enabled,
    required bool selected,
    required bool interacted,
  }) {
    if (!enabled) {
      // `SwitchDefaults.colors`: disabled-цвета сведены на `surface`.
      Color over(Color color, double opacity) =>
          Color.alphaBlend(color.withValues(alpha: opacity), c.surface);
      return selected
          ? _SwitchColors(
              track: over(c.onSurface, 0.12),
              border: Colors.transparent,
              handle: c.surface,
              icon: over(c.onSurface, 0.38),
            )
          : _SwitchColors(
              track: over(c.surfaceContainerHighest, 0.12),
              border: over(c.onSurface, 0.12),
              handle: over(c.onSurface, 0.38),
              icon: over(c.surfaceContainerHighest, 0.38),
            );
    }
    return selected
        ? _SwitchColors(
            track: c.primary,
            border: Colors.transparent,
            handle: interacted ? c.primaryContainer : c.onPrimary,
            icon: c.onPrimaryContainer,
          )
        : _SwitchColors(
            track: c.surfaceContainerHighest,
            border: c.outline,
            handle: interacted ? c.onSurfaceVariant : c.outline,
            icon: c.surfaceContainerHighest,
          );
  }
}
