import 'package:flutter/material.dart';

import 'm3_button_group.dart';
import 'm3_buttons.dart';
import 'm3_toggle_button.dart';

/// Connected button group из M3 Expressive — замена segmented button.
///
/// Порт `SingleSelectConnectedButtonGroupSample` из Compose Material3: строка
/// `ToggleButton` с промежутком `ButtonGroupDefaults.ConnectedSpaceBetween`
/// (2dp) и формами `ButtonGroupDefaults.connected{Leading,Middle,Trailing}ButtonShapes()`.
/// Соседи на нажатие не реагируют — это отличие connected group от standard.
///
/// * Размер S: высота 40dp, отступы 16dp, `labelLarge`
///   (`ToggleButtonDefaults`, `ConnectedButtonGroupSmallTokens`).
/// * Формы: внешние углы full; внутренние 8dp (`InnerCornerCornerSize` =
///   `CornerValueSmall`), при нажатии 4dp (`PressedInnerCornerCornerSize`),
///   у выбранной — 50% (`connectedButtonCheckedShape` = `CornerFull`).
///   Приоритет pressed > checked: нажатая выбранная кнопка тоже сжимает углы.
///   Морф — пружина FastSpatial (`ToggleButton`).
/// * Цвета filled toggle без анимации: невыбранная surfaceContainer /
///   onSurfaceVariant, выбранная primary / onPrimary.
/// * Зона нажатия 48dp по всей высоте строки («Extra small and small connected
///   button groups have 48dp target areas»): касание в полях над и под
///   кнопкой перенаправляется в неё, как `_InputPadding` у кнопок Flutter.
/// * Подпись в одну строку, без переноса и многоточия.
/// * Семантика одиночного выбора: `selected` + `inMutuallyExclusiveGroup`.
///
/// Группа растягивается на ширину родителя, кнопки делят её поровну
/// (Guidelines: «The connected button group should span the width of the page
/// or surface it’s placed on, increasing the button widths inside»).
class ConnectedButtonGroup<T> extends StatelessWidget {
  const ConnectedButtonGroup({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  /// `ButtonGroupDefaults.ConnectedSpaceBetween`.
  static const double spacing = M3ButtonGroupDefaults.connectedSpacing;

  /// Размер кнопок — Small.
  static const M3ButtonSize size = M3ButtonSize.small;

  /// Высота кнопки размера Small.
  static double get buttonHeight => size.height;

  /// `ConnectedButtonGroupSmallTokens.InnerCornerCornerSize`.
  static const M3CornerSize innerCorner = M3CornerSize.dp(8);

  /// `ConnectedButtonGroupSmallTokens.PressedInnerCornerCornerSize`.
  static const M3CornerSize pressedInnerCorner = M3CornerSize.dp(4);

  /// Формы кнопки [index] из [count] — `connectedLeadingButtonShapes()`,
  /// `connectedMiddleButtonShapes()` (все углы `ShapeDefaults.Small`),
  /// `connectedTrailingButtonShapes()`. Единственная кнопка — со всеми
  /// внешними углами.
  static M3ToggleButtonShapes shapesFor(int index, int count) {
    final bool leading = index == 0;
    final bool trailing = index == count - 1;
    M3Corners corners(M3CornerSize inner) => M3Corners.only(
      topStart: leading ? M3CornerSize.full : inner,
      bottomStart: leading ? M3CornerSize.full : inner,
      topEnd: trailing ? M3CornerSize.full : inner,
      bottomEnd: trailing ? M3CornerSize.full : inner,
    );
    return M3ToggleButtonShapes(
      shape: corners(innerCorner),
      pressedShape: corners(pressedInnerCorner),
      checkedShape: M3Corners.full,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: spacing),
          Expanded(
            child: M3ToggleButton(
              checked: values[i] == selected,
              onCheckedChange: (_) => onSelected(values[i]),
              size: size,
              shapes: shapesFor(i, values.length),
              semantics: M3ButtonSemantics.radio,
              child: Text(labelOf(values[i])),
            ),
          ),
        ],
      ],
    );
  }
}
