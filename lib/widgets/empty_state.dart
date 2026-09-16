import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_typography.dart';

/// Пустое состояние с геометрической иллюстрацией.
///
/// Иллюстрация собрана из фигур темы (круг, скруглённый квадрат, треугольник),
/// поэтому переезжает между палитрами и темами без отдельных ассетов.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.withAccentDot = false,
    this.illustrationSize = const Size(120, 110),
    this.action,
  });

  final String title;
  final String? description;

  /// Маленький круг `primary` поверх композиции — вариант вкладки «Заметки».
  final bool withAccentDot;

  final Size illustrationSize;

  /// Кнопка под текстом: «Выбрать группу», «Повторить».
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GeometricIllustration(
            size: illustrationSize,
            withAccentDot: withAccentDot,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleLarge!.emphasized,
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Декор пустого состояния из библиотеки форм M3.
///
/// https://m3.material.io/styles/shape — абстрактные формы для декоративных
/// элементов («Use abstract shapes on imagery and decorative UI»), без смысла,
/// закреплённого за формой. Формы — `MaterialShapes` (Dart-порт
/// `androidx.graphics.shapes`): круг, квадрат и треугольник, как в макете;
/// сочетание круглых и угловатых форм — приём «tension» из M3 Expressive.
class _GeometricIllustration extends StatelessWidget {
  const _GeometricIllustration({
    required this.size,
    required this.withAccentDot,
  });

  final Size size;
  final bool withAccentDot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    // Пропорции композиции — из макета.
    final double w = size.width;
    final double h = size.height;

    Widget shape(RoundedPolygon polygon, Color color, double side) => SizedBox(
      width: side,
      height: side,
      child: CustomPaint(painter: _PolygonPainter(polygon, color)),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned(
              left: w * 0.04,
              top: h * 0.12,
              child: shape(
                MaterialShapes.circle,
                colors.primaryContainer,
                w * 0.58,
              ),
            ),
            Positioned(
              right: w * 0.02,
              bottom: 0,
              child: shape(
                MaterialShapes.square,
                colors.tertiaryContainer,
                w * 0.47,
              ),
            ),
            Positioned(
              right: w * 0.14,
              top: 0,
              child: shape(
                MaterialShapes.triangle,
                colors.surfaceContainerHigh,
                w * 0.33,
              ),
            ),
            if (withAccentDot)
              Positioned(
                left: w * 0.3,
                bottom: h * 0.17,
                child: shape(MaterialShapes.circle, colors.primary, w * 0.15),
              ),
          ],
        ),
      ),
    );
  }
}

/// Рисует нормализованную форму на всю площадь.
class _PolygonPainter extends CustomPainter {
  _PolygonPainter(this.polygon, this.color);

  final RoundedPolygon polygon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path unit = polygon.normalized().toPath();
    final Matrix4 scale = Matrix4.diagonal3Values(size.width, size.height, 1);
    canvas.drawPath(unit.transform(scale.storage), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PolygonPainter oldDelegate) =>
      oldDelegate.polygon != polygon || oldDelegate.color != color;
}
