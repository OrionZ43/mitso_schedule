import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  });

  final String title;
  final String? description;

  /// Маленький круг `primary` поверх композиции — вариант вкладки «Заметки».
  final bool withAccentDot;

  final Size illustrationSize;

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
            style: context.text.titleLarge!.emphasized.copyWith(fontSize: 20),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium!.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

    // Пропорции макета: круг 0.58 ширины, квадрат 0.47, треугольник 0.35x0.35.
    final double w = size.width;
    final double h = size.height;
    final double circle = w * 0.58;
    final double square = w * 0.47;

    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned(
              left: w * 0.04,
              top: h * 0.12,
              child: Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: w * 0.02,
              bottom: 0,
              child: Transform.rotate(
                angle: 14 * math.pi / 180,
                child: Container(
                  width: square,
                  height: square,
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(square * 0.34),
                  ),
                ),
              ),
            ),
            Positioned(
              right: w * 0.14,
              top: 0,
              child: ClipPath(
                clipper: _TriangleClipper(),
                child: Container(
                  width: w * 0.33,
                  height: h * 0.34,
                  color: colors.surfaceContainerHigh,
                ),
              ),
            ),
            if (withAccentDot)
              Positioned(
                left: w * 0.3,
                bottom: h * 0.17,
                child: Container(
                  width: w * 0.15,
                  height: w * 0.15,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_TriangleClipper oldClipper) => false;
}
