import 'package:flutter/material.dart';

/// Круглый state layer 40dp у переключателя и чекбокса.
///
/// В Compose у `Switch` и `Checkbox` ripple неограниченный, радиус
/// `StateLayerSize / 2` = 20dp (`Switch.kt` → `ripple(bounded = false, radius =
/// SwitchTokens.StateLayerSize / 2)`, `Checkbox.kt` →
/// `ripple(bounded = false, radius = CheckboxTokens.StateLayerSize / 2)`), а у
/// переключателя он ещё и едет вместе с ручкой.
///
/// `InkResponse` рисует ink в своих границах и сам ловит жесты, поэтому для
/// ручки, которая движется внутри зоны нажатия 48dp, не подходит. Здесь те же
/// ink-эффекты, что у `InkResponse` (`ink_well.dart`: `_createSplash`,
/// `updateHighlight`), создаются вручную на подвижном «якоре» 40×40:
///   * splash — `Theme.splashFactory` (на Android `InkSparkle`, как у всех
///     `InkWell` приложения), обрезан кругом 40dp;
///   * подсветка нажатия, наведения и фокуса — `InkHighlight` кругом радиуса
///     20dp с длительностями `InkResponse.getFadeDurationForType`
///     (200 мс нажатие, 50 мс наведение и фокус).
///
/// Цвета слоя передаёт владелец (токены `*.state-layer.color` компонента +
/// непрозрачность `AppStateLayer`). Ink рисует ближайший [Material] над
/// якорем, поэтому владелец кладёт `Material(type: transparency)` поверх
/// контейнера — так слой, как и в Compose, лежит над треком и ручкой.
class M3RadialInkController {
  _M3RadialInkAnchorState? _anchor;

  /// Нажатие: splash из центра якоря и подсветка [color].
  void press(Color color) => _anchor?._press(color);

  /// Отпускание после нажатия (`InkResponse.handleTapUp` → `confirm`).
  void release() => _anchor?._release(cancelled: false);

  /// Отмена нажатия (`InkResponse.handleTapCancel` → `cancel`).
  void cancel() => _anchor?._release(cancelled: true);

  /// Подсветка наведения.
  void hover({required bool value, required Color color}) =>
      _anchor?._setHighlight(_Highlight.hover, value, color);

  /// Подсветка клавиатурного фокуса.
  void focus({required bool value, required Color color}) =>
      _anchor?._setHighlight(_Highlight.focus, value, color);

  /// Меняет цвет уже показанных подсветок, например после переключения.
  void recolor({
    required Color pressed,
    required Color hovered,
    required Color focused,
  }) => _anchor?._recolor(pressed, hovered, focused);
}

enum _Highlight { pressed, hover, focus }

/// Невидимый якорь 40×40, относительно которого рисуются ink-эффекты.
class M3RadialInkAnchor extends StatefulWidget {
  const M3RadialInkAnchor({super.key, required this.controller});

  final M3RadialInkController controller;

  /// `SwitchTokens.StateLayerSize` = `CheckboxTokens.StateLayerSize` = 40dp.
  static const double size = 40;

  @override
  State<M3RadialInkAnchor> createState() => _M3RadialInkAnchorState();
}

class _M3RadialInkAnchorState extends State<M3RadialInkAnchor> {
  final Map<_Highlight, InkHighlight> _highlights = {};
  final Set<InteractiveInkFeature> _splashes = {};
  InteractiveInkFeature? _currentSplash;

  @override
  void initState() {
    super.initState();
    widget.controller._anchor = this;
  }

  @override
  void didUpdateWidget(M3RadialInkAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._anchor == this) {
        oldWidget.controller._anchor = null;
      }
      widget.controller._anchor = this;
    }
  }

  RenderBox? get _box {
    final RenderObject? box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  void _press(Color color) {
    final RenderBox? box = _box;
    if (box == null) return;
    _currentSplash?.cancel();
    late final InteractiveInkFeature splash;
    splash = Theme.of(context).splashFactory.create(
      controller: Material.of(context),
      referenceBox: box,
      position: box.size.center(Offset.zero),
      color: color,
      containedInkWell: true,
      rectCallback: () => Offset.zero & box.size,
      customBorder: const CircleBorder(),
      onRemoved: () {
        _splashes.remove(splash);
        if (_currentSplash == splash) _currentSplash = null;
      },
      textDirection: Directionality.of(context),
    );
    _splashes.add(splash);
    _currentSplash = splash;
    _setHighlight(_Highlight.pressed, true, color);
  }

  void _release({required bool cancelled}) {
    if (cancelled) {
      _currentSplash?.cancel();
    } else {
      _currentSplash?.confirm();
    }
    _currentSplash = null;
    _setHighlight(_Highlight.pressed, false, null);
  }

  void _setHighlight(_Highlight type, bool value, Color? color) {
    final InkHighlight? highlight = _highlights[type];
    if (value == (highlight != null && highlight.active)) {
      if (highlight != null && color != null) highlight.color = color;
      return;
    }
    if (!value) {
      highlight!.deactivate();
      return;
    }
    if (highlight != null) {
      if (color != null) highlight.color = color;
      highlight.activate();
      return;
    }
    final RenderBox? box = _box;
    if (box == null || color == null) return;
    late final InkHighlight created;
    created = InkHighlight(
      controller: Material.of(context),
      referenceBox: box,
      color: color,
      shape: BoxShape.circle,
      radius: M3RadialInkAnchor.size / 2,
      textDirection: Directionality.of(context),
      fadeDuration: type == _Highlight.pressed
          ? const Duration(milliseconds: 200)
          : const Duration(milliseconds: 50),
      onRemoved: () {
        if (_highlights[type] == created) _highlights.remove(type);
      },
    );
    _highlights[type] = created;
  }

  void _recolor(Color pressed, Color hovered, Color focused) {
    _highlights[_Highlight.pressed]?.color = pressed;
    _highlights[_Highlight.hover]?.color = hovered;
    _highlights[_Highlight.focus]?.color = focused;
  }

  @override
  void deactivate() {
    for (final InteractiveInkFeature splash in _splashes.toList()) {
      splash.dispose();
    }
    _splashes.clear();
    _currentSplash = null;
    for (final InkHighlight highlight in _highlights.values.toList()) {
      highlight.dispose();
    }
    _highlights.clear();
    super.deactivate();
  }

  @override
  void dispose() {
    if (widget.controller._anchor == this) widget.controller._anchor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: M3RadialInkAnchor.size);
}
