import 'package:flutter/widgets.dart';

/// Токены отступов M3 — `md.sys.measurement.space*`.
///
/// https://m3.material.io/styles/spacing — шкала на базе 8dp. Значения — из
/// базы токенов m3.material.io (см. `docs/m3/styles/layout.md`). Отступы в
/// приложении берутся только отсюда.
abstract final class AppSpacing {
  static const double space0 = 0;
  static const double space25 = 2;
  static const double space50 = 4;
  static const double space75 = 6;
  static const double space100 = 8;
  static const double space125 = 10;
  static const double space150 = 12;
  static const double space175 = 14;
  static const double space200 = 16;
  static const double space250 = 20;
  static const double space300 = 24;
  static const double space400 = 32;
  static const double space500 = 40;
  static const double space600 = 48;
  static const double space800 = 64;
  static const double space900 = 72;

  /// Поля окна по breakpoint'у
  /// (https://m3.material.io/foundations/layout/breakpoints): compact < 600dp —
  /// 16dp, medium и шире — 24dp.
  static double screenMargin(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? space200 : space300;
}
