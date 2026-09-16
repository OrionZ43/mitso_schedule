import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_state_layer.dart';
import '../theme/app_typography.dart';

/// Filter chip Material 3 Expressive (flat) — порт Compose `FilterChip`.
///
/// Источники:
///   * https://m3.material.io/components/chips/specs — токены `md.comp.filter-chip.*`
///     (выгрузка `.m3-guidelines/components__chips.md`);
///   * Compose `Chip.kt` (`FilterChip`, `SelectableChip`, `AnimatingChipContent`,
///     `ChipArrangement`, `HorizontalElementsPadding`, `FilterChipDefaults`),
///     `tokens/FilterChipTokens.kt`, примеры `FilterChipSample` и
///     `FilterChipWithLeadingIconSample`.
///
/// Flutter `FilterChip` анимирует галочку 150 мс и выбор 195 мс
/// `fastOutSlowIn`. Здесь, как в `SelectableChip`:
///   * галочка слева появляется, только когда чип выбран: выдвижение
///     `expandHorizontally` — `FastSpatial`, проявление `fadeIn` — `SlowEffects`;
///     скрытие `shrinkHorizontally` — `DefaultEffects`, `fadeOut` — `FastEffects`;
///   * если задан [leading], слот не анимируется: при выборе иконка сразу
///     сменяется галочкой (`FilterChipWithLeadingIconSample`);
///   * цвета контейнера, обводки, подписи и иконки — без анимации;
///   * морфинга формы нет: перегрузка с `shapes` на m3.material.io не описана,
///     `FilterChip` по умолчанию 8dp.
class M3FilterChip extends StatefulWidget {
  const M3FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.leading,
    this.focusNode,
    this.autofocus = false,
  });

  /// Подпись; стиль `labelLarge` и цвет задаёт чип.
  final Widget label;

  final bool selected;

  /// `null` — чип недоступен (disabled).
  final ValueChanged<bool>? onSelected;

  /// Необязательная ведущая иконка невыбранного чипа (18dp, `primary`).
  final Widget? leading;

  final FocusNode? focusNode;
  final bool autofocus;

  /// `md.comp.filter-chip.container.height`.
  static const double height = 32;

  /// `md.comp.filter-chip.container.shape` = `corner.small`.
  static const double cornerRadius = AppShapes.small;

  /// `md.comp.filter-chip.with-icon.icon.size`, `FilterChipDefaults.IconSize`.
  static const double iconSize = 18;

  /// `FilterChipDefaults.ContentPadding` = 8dp по горизонтали.
  static const double contentPadding = 8;

  /// `HorizontalElementsPadding` / `FilterChipDefaults.HorizontalSpacing`.
  static const double elementSpacing = 8;

  /// `md.comp.filter-chip.flat.unselected.outline.width`.
  static const double outlineWidth = 1;

  /// `minimumInteractiveComponentSize` у `Surface(onClick)`.
  static const double targetSize = 48;

  /// Ключи для тестов.
  @visibleForTesting
  static const Key containerKey = ValueKey<String>('M3FilterChip.container');
  @visibleForTesting
  static const Key leadingSlotKey = ValueKey<String>('M3FilterChip.leading');

  @override
  State<M3FilterChip> createState() => _M3FilterChipState();
}

class _M3FilterChipState extends State<M3FilterChip>
    with TickerProviderStateMixin {
  /// Доля ширины слота иконки (`expandHorizontally` / `shrinkHorizontally`).
  late final AnimationController _width;

  /// Прозрачность слота (`fadeIn` / `fadeOut`).
  late final AnimationController _alpha;

  /// `rememberRetainedState`: пока слот уезжает, в нём остаётся последняя иконка.
  bool _retainedCheck = false;

  bool get _enabled => widget.onSelected != null;
  bool get _slotVisible => widget.selected || widget.leading != null;

  @override
  void initState() {
    super.initState();
    final double visible = _slotVisible ? 1 : 0;
    _width = AnimationController.unbounded(vsync: this, value: visible);
    _alpha = AnimationController.unbounded(vsync: this, value: visible);
    _retainedCheck = widget.selected;
  }

  @override
  void didUpdateWidget(M3FilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected || widget.leading != null) {
      _retainedCheck = widget.selected;
    }
    final bool wasVisible = oldWidget.selected || oldWidget.leading != null;
    if (wasVisible == _slotVisible) return;
    final bool reduceMotion = reduceMotionOf(context);
    if (_slotVisible) {
      _spring(_width, 1, AppMotion.fastSpatial, snap: reduceMotion);
      _spring(_alpha, 1, AppMotion.slowEffects);
    } else {
      _spring(_width, 0, AppMotion.defaultEffects, snap: reduceMotion);
      _spring(_alpha, 0, AppMotion.fastEffects);
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _alpha.dispose();
    super.dispose();
  }

  void _spring(
    AnimationController controller,
    double target,
    M3Spring spring, {
    bool snap = false,
  }) {
    if (snap) {
      controller.value = target;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        spring.description,
        controller.value,
        target,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = context.colors;
    final _ChipColors colors = _ChipColors.resolve(
      c,
      enabled: _enabled,
      selected: widget.selected,
    );
    const double radius = M3FilterChip.cornerRadius;

    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(radius)),
      side: colors.outline == null
          ? BorderSide.none
          : BorderSide(
              color: colors.outline!,
              width: M3FilterChip.outlineWidth,
            ),
    );

    final Widget leadingSlot = AnimatedBuilder(
      animation: Listenable.merge([_width, _alpha]),
      builder: (context, _) {
        final double factor = math.max(_width.value, 0);
        if (factor == 0) return const SizedBox.shrink();
        final bool showCheck = widget.leading == null
            ? _retainedCheck || widget.selected
            : widget.selected;
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: factor,
            child: Opacity(
              opacity: _alpha.value.clamp(0.0, 1.0),
              child: IconTheme.merge(
                data: IconThemeData(
                  // Уезжающая галочка сохраняет цвет выбранного чипа: в Compose
                  // удерживается лямбда вместе с `leadingIconColor`.
                  color: showCheck || widget.selected
                      ? colors.selectedIcon
                      : colors.icon,
                  size: M3FilterChip.iconSize,
                  opticalSize: 20,
                ),
                child: SizedBox.square(
                  dimension: M3FilterChip.iconSize,
                  child: Center(
                    child: showCheck
                        ? const Icon(Symbols.check)
                        : widget.leading,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: M3FilterChip.height),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: M3FilterChip.contentPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: M3FilterChip.leadingSlotKey, child: leadingSlot),
            // `ChipArrangement`: подпись всегда на 8dp правее слота иконки,
            // замыкающий слот (пустой) — ещё через 8dp.
            const SizedBox(width: M3FilterChip.elementSpacing),
            Flexible(
              child: DefaultTextStyle.merge(
                style: context.text.labelLarge!.copyWith(color: colors.label),
                child: widget.label,
              ),
            ),
            const SizedBox(width: M3FilterChip.elementSpacing),
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        checked: widget.selected,
        enabled: _enabled,
        child: _TapTargetPadding(
          minSize: const Size.square(M3FilterChip.targetSize),
          child: Material(
            key: M3FilterChip.containerKey,
            type: MaterialType.button,
            color: colors.container,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            // Цвета в `SelectableChip` не анимируются.
            animationDuration: Duration.zero,
            child: InkWell(
              onTap: _enabled
                  ? () => widget.onSelected!(!widget.selected)
                  : null,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              customBorder: shape,
              overlayColor: _overlay(c),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  /// `md.comp.filter-chip.{selected|unselected}.*.state-layer.color`:
  /// нажатие невыбранного — on-secondary-container, выбранного —
  /// on-surface-variant; наведение, фокус и перетаскивание — цвет подписи.
  WidgetStateProperty<Color?> _overlay(ColorScheme c) {
    final bool selected = widget.selected;
    final WidgetStateProperty<Color?> pressed = AppStateLayer.overlay(
      selected ? c.onSurfaceVariant : c.onSecondaryContainer,
    );
    final WidgetStateProperty<Color?> other = AppStateLayer.overlay(
      selected ? c.onSecondaryContainer : c.onSurfaceVariant,
    );
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed) &&
          !states.contains(WidgetState.dragged)) {
        return pressed.resolve(states);
      }
      return other.resolve(states);
    });
  }
}

/// Цвета по `FilterChipDefaults.filterChipColors()` / `filterChipBorder()`.
class _ChipColors {
  const _ChipColors({
    required this.container,
    required this.outline,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final Color container;
  final Color? outline;
  final Color label;

  /// Ведущая иконка невыбранного чипа.
  final Color icon;

  /// Галочка / иконка выбранного чипа.
  final Color selectedIcon;

  static _ChipColors resolve(
    ColorScheme c, {
    required bool enabled,
    required bool selected,
  }) {
    if (!enabled) {
      final Color disabledContent = c.onSurface.withValues(alpha: 0.38);
      return _ChipColors(
        container: selected
            ? c.onSurface.withValues(alpha: 0.12)
            : Colors.transparent,
        outline: selected ? null : c.onSurface.withValues(alpha: 0.12),
        label: disabledContent,
        icon: disabledContent,
        selectedIcon: disabledContent,
      );
    }
    return selected
        ? _ChipColors(
            container: c.secondaryContainer,
            outline: null,
            label: c.onSecondaryContainer,
            icon: c.primary,
            selectedIcon: c.onSecondaryContainer,
          )
        : _ChipColors(
            container: Colors.transparent,
            outline: c.outlineVariant,
            label: c.onSurfaceVariant,
            icon: c.primary,
            selectedIcon: c.onSecondaryContainer,
          );
  }
}

/// Зона нажатия 48dp вокруг контейнера 32dp: как `minimumInteractiveComponentSize`
/// в Compose и `_InputPadding` во Flutter-чипах. Касание рядом с контейнером
/// передаётся в его центр, а ripple остаётся в границах контейнера.
class _TapTargetPadding extends SingleChildRenderObjectWidget {
  const _TapTargetPadding({required this.minSize, required super.child});

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapTargetPadding(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTapTargetPadding renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class _RenderTapTargetPadding extends RenderShiftedBox {
  _RenderTapTargetPadding(this._minSize) : super(null);

  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(child?.getMinIntrinsicWidth(height) ?? 0, _minSize.width);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(child?.getMaxIntrinsicWidth(height) ?? 0, _minSize.width);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(child?.getMinIntrinsicHeight(width) ?? 0, _minSize.height);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(child?.getMaxIntrinsicHeight(width) ?? 0, _minSize.height);

  Size _sizeFor(Size childSize) => constraints.constrain(
    Size(
      math.max(childSize.width, _minSize.width),
      math.max(childSize.height, _minSize.height),
    ),
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.constrain(_minSize);
    final Size childSize = child.getDryLayout(constraints);
    return constraints.constrain(
      Size(
        math.max(childSize.width, _minSize.width),
        math.max(childSize.height, _minSize.height),
      ),
    );
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.constrain(_minSize);
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _sizeFor(child.size);
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
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
      hitTest: (result, position) => child.hitTest(result, position: center),
    );
  }
}
