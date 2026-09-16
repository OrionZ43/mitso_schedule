import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Connected button group из M3 Expressive — замена segmented button.
///
/// В MDC segmented button объявлен устаревшим, вместо него
/// `Widget.Material3Expressive.MaterialButtonGroup.Connected`:
/// https://github.com/material-components/material-components-android/blob/master/docs/components/ButtonGroup.md
///
/// Геометрия — из `button_group_tokens.xml` и
/// `m3expressive_connected_buttons_inner_corner_size_state_list.xml`
/// (кнопки размера Small); цвета — токены filled toggle-кнопки.
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

  /// `m3_comp_button_group_connected_small_between_space`.
  static const double spacing = 2;

  /// Высота кнопки размера Small.
  static const double buttonHeight = 40;

  /// Внутренние углы в покое — `shapeCornerSizeSmall`.
  static const double innerCorner = AppShapes.small;

  /// Внутренние углы при нажатии — `shapeCornerSizeExtraSmall`.
  static const double pressedInnerCorner = AppShapes.extraSmall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: spacing),
          Expanded(
            child: _ConnectedButton(
              label: labelOf(values[i]),
              selected: values[i] == selected,
              isFirst: i == 0,
              isLast: i == values.length - 1,
              onPressed: () => onSelected(values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConnectedButton extends StatefulWidget {
  const _ConnectedButton({
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  State<_ConnectedButton> createState() => _ConnectedButtonState();
}

class _ConnectedButtonState extends State<_ConnectedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    const double full = ConnectedButtonGroup.buttonHeight / 2;

    // Внешние углы всегда полностью скруглены. Внутренние: у выбранной кнопки
    // 50% (state_checked), при нажатии — extra small, иначе — small.
    final double inner = widget.selected
        ? full
        : (_pressed
              ? ConnectedButtonGroup.pressedInnerCorner
              : ConnectedButtonGroup.innerCorner);

    final BorderRadius radius = BorderRadius.horizontal(
      left: Radius.circular(widget.isFirst ? full : inner),
      right: Radius.circular(widget.isLast ? full : inner),
    );

    final Color background = widget.selected
        ? colors.primary
        : colors.surfaceContainer;
    final Color foreground = widget.selected
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      // Зона нажатия 48dp при кнопке высотой 40dp.
      child: SizedBox(
        height: 48,
        child: Center(
          child: TweenAnimationBuilder<BorderRadius?>(
            // Форма — spatial-пружина, цвет — effects: как везде в приложении.
            tween: BorderRadiusTween(end: radius),
            duration: AppMotion.fastSpatial.duration,
            curve: AppMotion.fastSpatial.curve,
            builder: (context, animatedRadius, child) {
              return TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: background),
                duration: AppMotion.defaultEffects.duration,
                curve: AppMotion.defaultEffects.curve,
                builder: (context, color, _) {
                  return Material(
                    color: color,
                    borderRadius: animatedRadius,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      onHighlightChanged: (value) =>
                          setState(() => _pressed = value),
                      child: SizedBox(
                        height: ConnectedButtonGroup.buttonHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.defaultEffects.duration,
                              curve: AppMotion.defaultEffects.curve,
                              style: context.text.labelLarge!.copyWith(
                                color: foreground,
                              ),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
