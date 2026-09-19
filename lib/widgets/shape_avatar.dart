import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_typography.dart';

/// Аватар формой из библиотеки M3.
///
/// https://m3.material.io/styles/shape — библиотека из 35 фигур предназначена
/// как раз для такого: «image crops and avatars», «personalized avatar
/// masking, and other non-interactive elements». Фигура — только маска,
/// смысла за ней нет («shape is versatile, not semantic»).
class ShapeAvatar extends StatelessWidget {
  const ShapeAvatar({
    super.key,
    required this.polygon,
    required this.size,
    required this.color,
    required this.onColor,
    this.initials,
    this.icon,
  }) : assert(initials != null || icon != null);

  /// Фигура-маска, например `MaterialShapes.cookie9Sided`.
  final RoundedPolygon polygon;

  /// Сторона квадрата, в который вписана фигура.
  final double size;

  /// Заливка фигуры и цвет содержимого.
  final Color color;
  final Color onColor;

  /// Инициалы; если их нет — [icon].
  final String? initials;
  final IconData? icon;

  /// Доля стороны под иконку: у фигур библиотеки края неровные, содержимому
  /// нужен запас.
  static const double _iconRatio = 0.42;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: _PolygonClipper(polygon),
        child: ColoredBox(
          color: color,
          child: Center(
            child: initials != null
                ? Text(
                    initials!,
                    style: context.text.headlineMedium!.emphasized.copyWith(
                      color: onColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: size * _iconRatio,
                    opticalSize: size * _iconRatio,
                    color: onColor,
                    fill: 1,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PolygonClipper extends CustomClipper<Path> {
  const _PolygonClipper(this.polygon);

  final RoundedPolygon polygon;

  /// Нормализованная фигура (0..1) растягивается в квадрат аватара.
  @override
  Path getClip(Size size) => polygon.normalized().toPath().transform(
    Matrix4.diagonal3Values(size.width, size.height, 1).storage,
  );

  @override
  bool shouldReclip(_PolygonClipper oldClipper) =>
      oldClipper.polygon != polygon;
}
