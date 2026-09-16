import 'package:flutter/material.dart';

/// State layer — полупрозрачный слой цветом контента поверх контейнера.
///
/// https://m3.material.io/foundations/interaction/states (State layers);
/// Compose `tokens/StateTokens.kt`, `RippleDefaults.RippleAlpha`:
/// hover 8%, focus 10%, pressed 10%, dragged 16%.
abstract final class AppStateLayer {
  static const double hoverOpacity = 0.08;
  static const double focusOpacity = 0.10;
  static const double pressedOpacity = 0.10;
  static const double draggedOpacity = 0.16;

  /// `overlayColor` для `InkWell` / `ButtonStyle`: [content] — цвет содержимого
  /// (обычно on-роль контейнера).
  static WidgetStateProperty<Color?> overlay(Color content) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return content.withValues(alpha: draggedOpacity);
        }
        if (states.contains(WidgetState.pressed)) {
          return content.withValues(alpha: pressedOpacity);
        }
        if (states.contains(WidgetState.focused)) {
          return content.withValues(alpha: focusOpacity);
        }
        if (states.contains(WidgetState.hovered)) {
          return content.withValues(alpha: hoverOpacity);
        }
        return null;
      });
}
