import 'package:flutter/material.dart';

/// Шкала радиусов Material 3.
///
/// https://m3.material.io/styles/shape/corner-radius-scale
abstract final class AppShapes {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;

  /// Обычная карточка пары/справки/задачи.
  ///
  /// Осознанное отступление от спеки: M3 задаёт карточкам `medium` (12dp),
  /// здесь 28dp. Согласовано с заказчиком как expressive-решение.
  static const double card = extraLarge;

  /// Выделенная карточка текущей пары — на ступень крупнее обычной.
  static const double cardEmphasized = extraLargeIncreased;

  /// Боттом-шит: скругление только сверху.
  static const double bottomSheet = extraLarge;

  /// Чипы и бейджи.
  static const double chip = small;

  /// FAB — по спеке `large`.
  static const double fab = large;

  /// Невыбранный день в селекторе; выбранный морфится в [extraLarge].
  static const double dayUnselected = large;

  static const Radius fullRadius = Radius.circular(9999);
  static const StadiumBorder stadium = StadiumBorder();

  static BorderRadius all(double radius) => BorderRadius.circular(radius);

  static RoundedRectangleBorder rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static const RoundedRectangleBorder bottomSheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(bottomSheet)),
  );
}
