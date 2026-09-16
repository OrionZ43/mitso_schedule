import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import 'm3_buttons.dart';

/// Цветовой стиль toggle-кнопки. Text-стиля у toggle нет (Guidelines
/// «Toggle buttons»), `filled` — по умолчанию (`ToggleButtonDefaults.colors`).
enum M3ToggleButtonColor { elevated, filled, tonal, outlined }

/// Формы toggle-кнопки — порт `ToggleButtonShapes`.
@immutable
class M3ToggleButtonShapes {
  const M3ToggleButtonShapes({
    required this.shape,
    required this.pressedShape,
    required this.checkedShape,
  });

  final M3Corners shape;
  final M3Corners pressedShape;
  final M3Corners checkedShape;

  @override
  bool operator ==(Object other) =>
      other is M3ToggleButtonShapes &&
      other.shape == shape &&
      other.pressedShape == pressedShape &&
      other.checkedShape == checkedShape;

  @override
  int get hashCode => Object.hash(shape, pressedShape, checkedShape);
}

/// Значения по умолчанию — порт `ToggleButtonDefaults`.
abstract final class M3ToggleButtonDefaults {
  /// Корзина размера по фактической высоте — как `shapesFor(buttonHeight)`:
  /// граница между соседними размерами — середина их высот
  /// (`(xSmallHeight + smallHeight) / 2` и т. д.): ≤36 → XS, ≤48 → S,
  /// ≤76 → M, ≤116 → L, иначе XL.
  static M3ButtonSize sizeForHeight(double height) {
    double mid(M3ButtonSize a, M3ButtonSize b) => (a.height + b.height) / 2;
    if (height <= mid(M3ButtonSize.extraSmall, M3ButtonSize.small)) {
      return M3ButtonSize.extraSmall;
    }
    if (height <= mid(M3ButtonSize.small, M3ButtonSize.medium)) {
      return M3ButtonSize.small;
    }
    if (height <= mid(M3ButtonSize.medium, M3ButtonSize.large)) {
      return M3ButtonSize.medium;
    }
    if (height <= mid(M3ButtonSize.large, M3ButtonSize.extraLarge)) {
      return M3ButtonSize.large;
    }
    return M3ButtonSize.extraLarge;
  }

  /// Формы для размера: pressed — `md.comp.button.<size>.pressed.container.shape`,
  /// выбранная — `selected.container.shape.round` (= square-радиус размера)
  /// у round и `selected.container.shape.square` (full) у square.
  ///
  /// Отступление от Compose: у S `ToggleButtonDefaults` жёстко задаёт pressed
  /// `RoundedCornerShape(6.dp)`, а токен m3 (и `ButtonDefaults.pressedShape`)
  /// — `corner.small` = 8dp. Взят токен.
  static M3ToggleButtonShapes shapesForSize(
    M3ButtonSize size, {
    M3ButtonShape shape = M3ButtonShape.round,
  }) {
    return M3ToggleButtonShapes(
      shape: shape == M3ButtonShape.round
          ? M3Corners.full
          : M3Corners.circular(size.squareRadius),
      pressedShape: M3Corners.circular(size.pressedRadius),
      checkedShape: shape == M3ButtonShape.round
          ? M3Corners.circular(size.squareRadius)
          : M3Corners.full,
    );
  }

  /// `ToggleButtonDefaults.shapesFor(buttonHeight)`.
  static M3ToggleButtonShapes shapesFor(
    double height, {
    M3ButtonShape shape = M3ButtonShape.round,
  }) => shapesForSize(sizeForHeight(height), shape: shape);

  /// Контейнер и содержимое — `ToggleButtonDefaults.colors()` и соседи:
  /// токены `md.comp.button.<style>.(un)selected.*`.
  static (Color container, Color content) colorsFor(
    M3ToggleButtonColor style,
    ColorScheme colors, {
    required bool enabled,
    required bool checked,
  }) {
    if (!enabled) {
      // `md.comp.button.disabled.*`; у outlined контейнер есть только у
      // выбранной (`outlined.selected.disabled.container.color`).
      final bool hasContainer =
          style != M3ToggleButtonColor.outlined || checked;
      return (
        hasContainer ? M3DisabledColors.container(colors) : Colors.transparent,
        M3DisabledColors.content(colors),
      );
    }
    return switch ((style, checked)) {
      (M3ToggleButtonColor.elevated, false) => (
        colors.surfaceContainerLow,
        colors.primary,
      ),
      (M3ToggleButtonColor.elevated, true) => (
        colors.primary,
        colors.onPrimary,
      ),
      (M3ToggleButtonColor.filled, false) => (
        colors.surfaceContainer,
        colors.onSurfaceVariant,
      ),
      (M3ToggleButtonColor.filled, true) => (colors.primary, colors.onPrimary),
      (M3ToggleButtonColor.tonal, false) => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      (M3ToggleButtonColor.tonal, true) => (
        colors.secondary,
        colors.onSecondary,
      ),
      (M3ToggleButtonColor.outlined, false) => (
        Colors.transparent,
        colors.onSurfaceVariant,
      ),
      (M3ToggleButtonColor.outlined, true) => (
        colors.inverseSurface,
        colors.onInverseSurface,
      ),
    };
  }

  /// `ToggleButtonDefaults.elevation()` / `ElevatedToggleButtonDefaults` /
  /// `FilledTonalToggleButtonDefaults`; у outlined тени нет.
  static M3ButtonElevation elevationFor(M3ToggleButtonColor style) =>
      switch (style) {
        M3ToggleButtonColor.elevated => M3ButtonElevation.elevated,
        M3ToggleButtonColor.filled ||
        M3ToggleButtonColor.tonal => M3ButtonElevation.filled,
        M3ToggleButtonColor.outlined => M3ButtonElevation.none,
      };
}

/// Toggle button M3 Expressive — порт `ToggleButton` (`ToggleButton.kt`).
///
/// * Форма по взаимодействию: **pressed > checked > default**
///   (`shapeByInteraction`), морф — пружина `MotionSchemeKeyTokens.FastSpatial`
///   (с перелётом, в отличие от обычной кнопки).
/// * Цвета контейнера и содержимого меняются **без анимации**:
///   `colors.containerColor(enabled, checked)` отдаётся в `Surface` напрямую.
/// * Обводка outlined-стиля есть только у невыбранной; её толщина — пружина
///   FastSpatial, цвет — DefaultEffects (`animateBorderStrokeAsState`).
/// * Размер задаёт высоту (`defaultMinSize(minHeight = buttonSize.height)`),
///   отступы, иконку, промежуток и шрифт (`ButtonDefaults.*For(height)`);
///   формы по умолчанию — [M3ToggleButtonDefaults.shapesForSize].
/// * Семантика по умолчанию — `Role.Checkbox` (`checked`); в группе с
///   одиночным выбором — [M3ButtonSemantics.radio].
class M3ToggleButton extends StatelessWidget {
  const M3ToggleButton({
    super.key,
    required this.checked,
    required this.onCheckedChange,
    required this.child,
    this.icon,
    this.color = M3ToggleButtonColor.filled,
    this.size = M3ButtonSize.small,
    this.shape = M3ButtonShape.round,
    this.shapes,
    this.contentPadding,
    this.minHeight,
    this.semantics = M3ButtonSemantics.checkbox,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
  });

  final bool checked;

  /// Получает новое значение `!checked`; `null` — кнопка выключена.
  final ValueChanged<bool>? onCheckedChange;

  /// Подпись.
  final Widget child;

  /// Ведущая иконка: outlined у невыбранной, filled у выбранной.
  final Widget? icon;

  final M3ToggleButtonColor color;
  final M3ButtonSize size;

  /// Форма по умолчанию, если [shapes] не заданы.
  final M3ButtonShape shape;

  /// Явные формы — например, `connected*ButtonShapes` в connected group.
  final M3ToggleButtonShapes? shapes;

  /// По умолчанию — отступы размера (`ToggleButtonDefaults.contentPaddingFor`).
  final EdgeInsetsGeometry? contentPadding;

  /// По умолчанию — высота размера.
  final double? minHeight;

  final M3ButtonSemantics semantics;
  final WidgetStatesController? statesController;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onCheckedChange != null;
    final (Color container, Color content) = M3ToggleButtonDefaults.colorsFor(
      color,
      theme.colorScheme,
      enabled: enabled,
      checked: checked,
    );
    final M3ToggleButtonShapes resolvedShapes =
        shapes ?? M3ToggleButtonDefaults.shapesForSize(size, shape: shape);

    return M3ButtonContainer(
      onPressed: enabled ? () => onCheckedChange!(!checked) : null,
      shape: resolvedShapes.shape,
      pressedShape: resolvedShapes.pressedShape,
      checkedShape: resolvedShapes.checkedShape,
      checked: checked,
      morphSpring: AppMotion.fastSpatial,
      color: container,
      contentColor: content,
      textStyle: size.textStyle(theme.textTheme),
      iconSize: size.iconSize,
      // `OutlinedToggleButtonDefaults.border(enabled, checked)`: у выбранной
      // обводки нет; цвет — `outlined.(disabled.)outline.color` = outline-variant.
      border: color == M3ToggleButtonColor.outlined && !checked
          ? BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: size.outlineWidth,
            )
          : null,
      animateBorder: true,
      elevation: M3ToggleButtonDefaults.elevationFor(color),
      semantics: semantics,
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight ?? size.height),
        child: Padding(
          padding: contentPadding ?? size.contentPadding,
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
