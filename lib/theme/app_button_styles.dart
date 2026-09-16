import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'app_shapes.dart';

/// Размеры кнопок M3 Expressive.
///
/// https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md
///
/// Значения — из `button/res/values/tokens.xml`. Форма по умолчанию круглая
/// (full) и морфится в скруглённый прямоугольник, пока кнопка нажата.
abstract final class AppButtonStyles {
  /// Small — размер по умолчанию: 40dp, `labelLarge`, отступы 16dp,
  /// при нажатии углы `cornerSmall` (8dp).
  static ButtonStyle small(TextTheme text) => _style(
    height: 40,
    label: text.labelLarge!,
    horizontalPadding: 16,
    iconSize: 20,
    pressedCorner: AppShapes.small,
  );

  /// Medium: 56dp, `titleMedium`, отступы 24dp, при нажатии углы
  /// `cornerMedium` (12dp).
  static ButtonStyle medium(TextTheme text) => _style(
    height: 56,
    label: text.titleMedium!,
    horizontalPadding: 24,
    iconSize: 24,
    pressedCorner: AppShapes.medium,
  );

  /// Icon button Small: 40dp, иконка 24dp, при нажатии углы `cornerSmall`.
  static ButtonStyle iconSmall() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.square(40)),
    iconSize: const WidgetStatePropertyAll(24),
    shape: _morphingShape(AppShapes.small),
    animationDuration: AppMotion.fastSpatial.duration,
  );

  static ButtonStyle _style({
    required double height,
    required TextStyle label,
    required double horizontalPadding,
    required double iconSize,
    required double pressedCorner,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      textStyle: WidgetStatePropertyAll(label),
      iconSize: WidgetStatePropertyAll(iconSize),
      shape: _morphingShape(pressedCorner),
      animationDuration: AppMotion.fastSpatial.duration,
    );
  }

  /// «Shape morphs when pressed»: full в покое, скруглённый прямоугольник
  /// при нажатии.
  static WidgetStateProperty<OutlinedBorder> _morphingShape(double corner) {
    return WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? RoundedRectangleBorder(borderRadius: AppShapes.all(corner))
          : const StadiumBorder(),
    );
  }
}
