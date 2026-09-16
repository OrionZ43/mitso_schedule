import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'm3_loading_shapes.dart';

/// Индикатор загрузки Material 3 Expressive.
///
/// https://m3.material.io/components/loading-indicator/overview
///
/// Морфится по официальной последовательности из семи форм и одновременно
/// вращается. Морфинг — линейная интерполяция между наборами из 36 опорных
/// точек (у всех форм их поровну), см.
/// https://m3.material.io/styles/shape/shape-morph
///
/// Flutter 3.44 не поставляет этот компонент, поэтому он реализован здесь на
/// [CustomPainter]. Числовые значения ниже — из реализации
/// `LoadingIndicatorDefaults` в Compose Material3 (страницы `specs` на
/// m3.material.io отдаются только как SPA и машинно не читаются).
class M3LoadingIndicator extends StatefulWidget {
  const M3LoadingIndicator({
    super.key,
    this.contained = true,
    this.size,
    this.color,
    this.containerColor,
    this.scale = 1.0,
    this.semanticsLabel = 'Загрузка',
  });

  /// `true` — активный индикатор внутри круглого контейнера.
  final bool contained;

  /// Размер контейнера (contained) либо активного индикатора (uncontained).
  final double? size;

  /// Цвет активного индикатора. По умолчанию `colorScheme.primary`.
  final Color? color;

  /// Цвет контейнера. По умолчанию `colorScheme.primaryContainer`.
  final Color? containerColor;

  /// Масштаб для pull-to-refresh: индикатор «проявляется» по мере протяжки.
  final double scale;

  final String? semanticsLabel;

  /// Диаметр контейнера contained-варианта.
  static const double containerSize = 48;

  /// Активный индикатор внутри контейнера.
  static const double containedIndicatorSize = 38;

  /// Активный индикатор без контейнера.
  static const double uncontainedIndicatorSize = 48;

  /// Время показа одной формы.
  static const Duration morphInterval = Duration(milliseconds: 650);

  /// Поворот за один шаг морфинга.
  static const double rotationPerMorph = 45;

  /// Полный цикл морфинга: семь форм.
  static Duration get morphDuration =>
      morphInterval * M3LoadingShapes.sequence.length;

  /// Полный оборот на 360 градусов при скорости [rotationPerMorph] за шаг.
  static Duration get rotationDuration =>
      morphInterval * (360 / rotationPerMorph);

  @override
  State<M3LoadingIndicator> createState() => _M3LoadingIndicatorState();
}

class _M3LoadingIndicatorState extends State<M3LoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: M3LoadingIndicator.morphDuration,
  )..repeat();

  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: M3LoadingIndicator.rotationDuration,
  )..repeat();

  @override
  void dispose() {
    _morph.dispose();
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double containerSize =
        widget.size ??
        (widget.contained
            ? M3LoadingIndicator.containerSize
            : M3LoadingIndicator.uncontainedIndicatorSize);

    // Активный индикатор занимает 38/48 контейнера — пропорция сохраняется
    // при любом заданном размере.
    final double indicatorSize = widget.contained
        ? containerSize *
              (M3LoadingIndicator.containedIndicatorSize /
                  M3LoadingIndicator.containerSize)
        : containerSize;

    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: containerSize,
        child: Transform.scale(
          scale: widget.scale,
          child: AnimatedBuilder(
            animation: Listenable.merge([_morph, _rotation]),
            builder: (context, _) {
              return CustomPaint(
                painter: _LoadingIndicatorPainter(
                  morph: _morph.value,
                  rotation: _rotation.value * 2 * math.pi,
                  indicatorSize: indicatorSize,
                  color: widget.color ?? colors.primary,
                  containerColor: widget.contained
                      ? (widget.containerColor ?? colors.primaryContainer)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicatorPainter extends CustomPainter {
  _LoadingIndicatorPainter({
    required this.morph,
    required this.rotation,
    required this.indicatorSize,
    required this.color,
    required this.containerColor,
  });

  /// Положение внутри цикла морфинга, 0..1.
  final double morph;

  /// Текущий поворот в радианах.
  final double rotation;

  final double indicatorSize;
  final Color color;
  final Color? containerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);

    if (containerColor != null) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2,
        Paint()..color = containerColor!,
      );
    }

    final List<Offset> points = _interpolatedPoints();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      // Точки заданы в долях 0..1 от габаритного квадрата формы.
      final Offset p = Offset(
        (points[i].dx - 0.5) * indicatorSize,
        (points[i].dy - 0.5) * indicatorSize,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  /// Форма между двумя соседними ключевыми формами последовательности.
  List<Offset> _interpolatedPoints() {
    final List<List<Offset>> shapes = M3LoadingShapes.sequence;
    final double position = morph * shapes.length;
    final int index = position.floor() % shapes.length;
    final int next = (index + 1) % shapes.length;

    // Внутри шага — стандартное easing M3, чтобы форма не «дёргалась»
    // на стыке ключевых кадров.
    final double t = Easing.standard.transform(
      (position - position.floor()).clamp(0.0, 1.0),
    );

    final List<Offset> from = shapes[index];
    final List<Offset> to = shapes[next];
    return <Offset>[
      for (int i = 0; i < from.length; i++) Offset.lerp(from[i], to[i], t)!,
    ];
  }

  @override
  bool shouldRepaint(_LoadingIndicatorPainter old) {
    return old.morph != morph ||
        old.rotation != rotation ||
        old.indicatorSize != indicatorSize ||
        old.color != color ||
        old.containerColor != containerColor;
  }
}
