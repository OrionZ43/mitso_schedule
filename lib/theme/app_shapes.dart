import 'dart:math' as math;

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

/// Форма индикатора navigation bar в M3 Expressive: таблетка 56×32dp.
///
/// Flutter рисует индикатор в фиксированной рамке 64×32 (`_kIndicatorWidth`
/// в `navigation_bar.dart`) и ширину не настраивает, а MDC Expressive задаёт
/// `m3_comp_nav_bar_item_vertical_active_indicator_width` = 56dp. Фон и ripple
/// индикатора рисуются по его форме, поэтому форма сужает таблетку внутри рамки.
class NavigationIndicatorBorder extends StadiumBorder {
  const NavigationIndicatorBorder({super.side, this.width = 56});

  final double width;

  Rect _inset(Rect rect) => Rect.fromCenter(
    center: rect.center,
    width: math.min(width, rect.width),
    height: rect.height,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      super.getOuterPath(_inset(rect), textDirection: textDirection);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      super.getInnerPath(_inset(rect), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      super.paint(canvas, _inset(rect), textDirection: textDirection);

  @override
  NavigationIndicatorBorder copyWith({BorderSide? side}) =>
      NavigationIndicatorBorder(side: side ?? this.side, width: width);

  @override
  NavigationIndicatorBorder scale(double t) =>
      NavigationIndicatorBorder(side: side.scale(t), width: width * t);
}
