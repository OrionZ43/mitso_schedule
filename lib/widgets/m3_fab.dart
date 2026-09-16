import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_motion.dart';
import 'm3_buttons.dart';

/// Цветовой стиль FAB и extended FAB (Expressive): primary container — по
/// умолчанию; surface-стиль не рекомендуется и не портирован.
///
/// Токены `md.comp.fab.<style>.*` / `md.comp.extended-fab.<style>.*`:
/// контейнер, иконка и подпись — пара «роль / on-роль»; state layer — цветом
/// иконки («make sure the state layer color is the same as the icon color»).
enum M3FabColor {
  primaryContainer,
  secondaryContainer,
  tertiaryContainer,
  primary,
  secondary,
  tertiary;

  (Color container, Color content) resolve(
    ColorScheme colors,
  ) => switch (this) {
    primaryContainer => (colors.primaryContainer, colors.onPrimaryContainer),
    secondaryContainer => (
      colors.secondaryContainer,
      colors.onSecondaryContainer,
    ),
    tertiaryContainer => (colors.tertiaryContainer, colors.onTertiaryContainer),
    primary => (colors.primary, colors.onPrimary),
    secondary => (colors.secondary, colors.onSecondary),
    tertiary => (colors.tertiary, colors.onTertiary),
  };
}

/// Размер FAB. Small FAB больше не рекомендуется и не портирован.
enum M3FabSize {
  /// FAB: 56dp, `corner.large` 16dp, иконка 24dp (`FabBaselineTokens`).
  standard(containerSize: 56, cornerRadius: 16, iconSize: 24),

  /// Medium FAB — «most recommended»: 80dp, `corner.large-increased` 20dp,
  /// иконка 28dp (`FabMediumTokens`, `FloatingActionButtonDefaults.mediumShape`).
  medium(containerSize: 80, cornerRadius: 20, iconSize: 28),

  /// Large FAB: 96dp, `corner.extra-large` 28dp, иконка 36dp —
  /// `md.comp.fab.large.icon.size` и `FloatingActionButtonDefaults.LargeIconSize`
  /// (в `FabLargeTokens.IconSize` 32dp с TODO «is incorrect»).
  large(containerSize: 96, cornerRadius: 28, iconSize: 36);

  const M3FabSize({
    required this.containerSize,
    required this.cornerRadius,
    required this.iconSize,
  });

  final double containerSize;
  final double cornerRadius;
  final double iconSize;
}

/// FAB M3 Expressive — `FloatingActionButton`, `MediumFloatingActionButton`,
/// `LargeFloatingActionButton` (`FloatingActionButton.kt`).
///
/// * Форма статичная — при нажатии не морфится.
/// * Тень: level3 (6dp) в покое, при нажатии и фокусе, level4 (8dp) при
///   наведении (`FloatingActionButtonDefaults.elevation`), анимация —
///   `animateElevation`.
/// * Размер — минимальный (`sizeIn(minWidth, minHeight)`), содержимое по центру.
/// * FAB не бывает disabled: если действие недоступно, FAB не показывают.
/// * Иконка — filled; метка действия — [tooltip].
class M3Fab extends StatelessWidget {
  const M3Fab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = M3FabSize.standard,
    this.color = M3FabColor.primaryContainer,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final M3FabSize size;
  final M3FabColor color;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color container, Color content) = color.resolve(theme.colorScheme);
    final M3Corners shape = M3Corners.circular(size.cornerRadius);
    return M3ButtonContainer(
      onPressed: onPressed,
      shape: shape,
      pressedShape: shape,
      morphSpring: AppMotion.defaultEffects,
      color: container,
      contentColor: content,
      // `ExtendedFabPrimaryTokens.LabelTextFont`.
      textStyle: theme.textTheme.labelLarge!,
      iconSize: size.iconSize,
      elevation: M3ButtonElevation.fab,
      tooltip: tooltip,
      focusNode: focusNode,
      autofocus: autofocus,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: size.containerSize,
          minHeight: size.containerSize,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: icon),
      ),
    );
  }
}

/// Размер extended FAB. Baseline extended FAB не рекомендуется и не портирован.
enum M3ExtendedFabSize {
  /// `md.comp.extended-fab.small.*`, `ExtendedFabSmallTokens`.
  small(
    height: 56,
    cornerRadius: 16,
    iconSize: 24,
    padding: 16,
    iconSpacing: 8,
  ),

  /// `md.comp.extended-fab.medium.*`: промежуток `space150` = 12dp (как
  /// `MediumExtendedFabIconPadding`; в `ExtendedFabMediumTokens` 16dp с TODO).
  medium(
    height: 80,
    cornerRadius: 20,
    iconSize: 28,
    padding: 26,
    iconSpacing: 12,
  ),

  /// `md.comp.extended-fab.large.*`: иконка 36dp (m3), промежуток `space200`
  /// = 16dp (`LargeExtendedFabIconPadding`).
  large(
    height: 96,
    cornerRadius: 28,
    iconSize: 36,
    padding: 28,
    iconSpacing: 16,
  );

  const M3ExtendedFabSize({
    required this.height,
    required this.cornerRadius,
    required this.iconSize,
    required this.padding,
    required this.iconSpacing,
  });

  final double height;
  final double cornerRadius;
  final double iconSize;

  /// `leading-space` = `trailing-space`.
  final double padding;

  /// `icon-label-space`.
  final double iconSpacing;

  /// `label-text`: titleMedium / titleLarge / headlineSmall.
  TextStyle textStyle(TextTheme text) => switch (this) {
    small => text.titleMedium!,
    medium => text.titleLarge!,
    large => text.headlineSmall!,
  };
}

/// Extended FAB M3 Expressive — `SmallExtendedFloatingActionButton`,
/// `MediumExtendedFloatingActionButton`, `LargeExtendedFloatingActionButton`.
///
/// Минимальная ширина равна высоте (`SmallExtendedFabMinimumWidth` =
/// `ContainerHeight`). Сворачивание [expanded] (только с иконкой) — как
/// приватный `ExtendedFloatingActionButton(text, icon, …, expanded)`: ширина
/// от минимальной до полной — пружина FastSpatial, прозрачность подписи —
/// FastEffects; когда свёрнута полностью, подписи нет в раскладке.
///
/// Отступление: в Compose подпись исключена из семантики
/// (`clearAndSetSemantics {}`), метку даёт иконка. Здесь метка — [label]
/// всегда, в том числе у свёрнутой кнопки («Метка доступности начинается с
/// того же слова, что видимая подпись»).
class M3ExtendedFab extends StatefulWidget {
  const M3ExtendedFab({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.expanded = true,
    this.size = M3ExtendedFabSize.small,
    this.color = M3FabColor.primaryContainer,
    this.focusNode,
    this.autofocus = false,
  }) : assert(icon != null || expanded, 'Свернуть можно только до иконки');

  final VoidCallback onPressed;

  /// Подпись: 1–2 слова, одна строка.
  final String label;

  /// Необязательная filled-иконка.
  final Widget? icon;
  final bool expanded;
  final M3ExtendedFabSize size;
  final M3FabColor color;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<M3ExtendedFab> createState() => _M3ExtendedFabState();
}

class _M3ExtendedFabState extends State<M3ExtendedFab>
    with TickerProviderStateMixin {
  late final AnimationController _width = AnimationController.unbounded(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final AnimationController _alpha = AnimationController.unbounded(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(M3ExtendedFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      final double target = widget.expanded ? 1 : 0;
      if (reduceMotionOf(context)) {
        _width.value = target;
        _alpha.value = target;
      } else {
        m3SpringTo(_width, AppMotion.fastSpatial, target);
        m3SpringTo(_alpha, AppMotion.fastEffects, target);
      }
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _alpha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final M3ExtendedFabSize size = widget.size;
    final (Color container, Color content) = widget.color.resolve(
      theme.colorScheme,
    );
    final M3Corners shape = M3Corners.circular(size.cornerRadius);

    return Semantics(
      label: widget.label,
      child: M3ButtonContainer(
        onPressed: widget.onPressed,
        shape: shape,
        pressedShape: shape,
        morphSpring: AppMotion.defaultEffects,
        color: container,
        contentColor: content,
        textStyle: size.textStyle(theme.textTheme),
        iconSize: size.iconSize,
        elevation: M3ButtonElevation.fab,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: AnimatedBuilder(
          animation: Listenable.merge([_width, _alpha]),
          builder: (context, _) {
            // `fullyCollapsed = currentState == 0f && !isRunning`.
            final bool fullyCollapsed =
                !widget.expanded && !_width.isAnimating && !_alpha.isAnimating;
            return _ExpandableWidth(
              progress: widget.icon == null ? 1 : _width.value,
              minWidth: size.height,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: size.height,
                  minHeight: size.height,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.padding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: widget.icon == null
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      ?widget.icon,
                      if (!fullyCollapsed)
                        ExcludeSemantics(
                          child: Opacity(
                            opacity: clampDouble(_alpha.value, 0, 1),
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: widget.icon == null
                                    ? 0
                                    : size.iconSpacing,
                              ),
                              child: Text(widget.label),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ширина от [minWidth] до полной ширины содержимого по [progress] —
/// `Modifier.layout { lerp(minWidth, maxIntrinsicWidth, progress) }`.
class _ExpandableWidth extends SingleChildRenderObjectWidget {
  const _ExpandableWidth({
    required this.progress,
    required this.minWidth,
    super.child,
  });

  final double progress;
  final double minWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExpandableWidth(progress, minWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderExpandableWidth renderObject,
  ) {
    renderObject
      ..progress = progress
      ..minWidth = minWidth;
  }
}

class _RenderExpandableWidth extends RenderShiftedBox {
  _RenderExpandableWidth(this._progress, this._minWidth) : super(null);

  double _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsLayout();
  }

  double _minWidth;
  set minWidth(double value) {
    if (_minWidth == value) return;
    _minWidth = value;
    markNeedsLayout();
  }

  double _widthFor(double expandedWidth) =>
      lerpDouble(_minWidth, expandedWidth, _progress)!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widthFor(child?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widthFor(child?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size childSize = child.getDryLayout(
      constraints.copyWith(minWidth: 0),
    );
    final double expanded = child.getMaxIntrinsicWidth(constraints.maxHeight);
    return constraints.constrain(Size(_widthFor(expanded), childSize.height));
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final double expandedWidth = child.getMaxIntrinsicWidth(
      constraints.maxHeight,
    );
    child.layout(constraints.copyWith(minWidth: 0), parentUsesSize: true);
    size = constraints.constrain(
      Size(math.max(0, _widthFor(expandedWidth)), child.size.height),
    );
    (child.parentData! as BoxParentData).offset = Offset.zero;
  }
}

/// Показ и скрытие FAB — порт `Modifier.animateFloatingActionButton`
/// (`FabVisibleNode` в `FloatingActionButton.kt`).
///
/// * Масштаб: от [targetScale] (`ShowHideTargetScale` = 0.2) до 1 с опорной
///   точкой [alignment], пружина `motionScheme.fastSpatialSpec()`.
/// * Прозрачность: 0 ↔ 1, `fastEffectsSpec()`.
/// * Пока прозрачность ровно 0, узел занимает 0×0 (`layout(0, 0)`), не
///   рисуется и не принимает касаний.
/// * При первом показе без анимации (`Animatable(if (visible) 1f else 0f)`).
class M3AnimatedFabVisibility extends StatefulWidget {
  const M3AnimatedFabVisibility({
    super.key,
    required this.visible,
    required this.alignment,
    this.targetScale = 0.2,
    required this.child,
  });

  final bool visible;

  /// Куда сжимается FAB: для FAB в правом нижнем углу —
  /// `Alignment.bottomRight` (`AlignmentDirectional.bottomEnd`).
  final AlignmentGeometry alignment;
  final double targetScale;
  final Widget child;

  @override
  State<M3AnimatedFabVisibility> createState() =>
      _M3AnimatedFabVisibilityState();
}

class _M3AnimatedFabVisibilityState extends State<M3AnimatedFabVisibility>
    with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final AnimationController _alpha = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(M3AnimatedFabVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      final double target = widget.visible ? 1 : 0;
      if (reduceMotionOf(context)) {
        _scale.value = target;
        _alpha.value = target;
      } else {
        m3SpringTo(_scale, AppMotion.fastSpatial, target);
        m3SpringTo(_alpha, AppMotion.fastEffects, target);
      }
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _alpha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Alignment alignment = widget.alignment.resolve(
      Directionality.of(context),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_scale, _alpha]),
      child: widget.child,
      builder: (context, child) {
        final double scale = lerpDouble(widget.targetScale, 1, _scale.value)!;
        return _FabVisibleBox(
          hidden: _alpha.value == 0,
          child: Opacity(
            opacity: clampDouble(_alpha.value, 0, 1),
            child: Transform.scale(
              scale: scale,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Скрытый FAB: размер 0×0, без отрисовки, касаний и семантики.
class _FabVisibleBox extends SingleChildRenderObjectWidget {
  const _FabVisibleBox({required this.hidden, super.child});

  final bool hidden;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFabVisibleBox(hidden);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFabVisibleBox renderObject,
  ) {
    renderObject.hidden = hidden;
  }
}

class _RenderFabVisibleBox extends RenderProxyBox {
  _RenderFabVisibleBox(this._hidden);

  bool _hidden;
  set hidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _hidden ? 0 : super.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _hidden ? 0 : super.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _hidden ? 0 : super.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _hidden ? 0 : super.computeMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _hidden
      ? constraints.constrain(Size.zero)
      : super.computeDryLayout(constraints);

  @override
  void performLayout() {
    if (_hidden) {
      child?.layout(constraints.loosen());
      size = constraints.constrain(Size.zero);
      return;
    }
    super.performLayout();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !_hidden && super.hitTest(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_hidden) super.visitChildrenForSemantics(visitor);
  }
}
