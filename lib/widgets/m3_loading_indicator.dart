import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

/// Индикатор загрузки Material 3 Expressive.
///
/// Порт `LoadingIndicator` из material-components-android:
/// https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md
///
/// Во Flutter 3.44 этого компонента нет. Формы и морфинг берутся из
/// `material_new_shapes` — Dart-порта `androidx.graphics.shapes`, на котором
/// построен и оригинал. Анимация перенесена из
/// `LoadingIndicatorAnimatorDelegate.java`, отрисовка — из
/// `LoadingIndicatorDrawingDelegate.java`; числа ниже взяты оттуда же.
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

  /// `true` — стиль `Widget.Material3.LoadingIndicator.Contained`:
  /// форма на круглом контейнере.
  final bool contained;

  /// Сторона всего индикатора. По умолчанию [containerSize]; всё рисуется
  /// пропорционально, как в MDC с включённым `scaleToFit`.
  final double? size;

  /// Цвет формы. По умолчанию `onPrimaryContainer` для contained и `primary`
  /// для uncontained — как токены
  /// `m3_comp_loading_indicator_contained_active_indicator_color` и
  /// `m3_comp_loading_indicator_active_indicator_color`.
  final Color? color;

  /// Цвет контейнера. По умолчанию `primaryContainer`
  /// (`m3_comp_loading_indicator_contained_container_color`).
  final Color? containerColor;

  /// Дополнительный масштаб: в pull-to-refresh индикатор «проявляется»
  /// по мере протяжки.
  final double scale;

  final String? semanticsLabel;

  /// `m3_comp_loading_indicator_container_width` / `_height`.
  static const double containerSize = 48;

  /// `indicatorSize` из стиля `Widget.Material3.LoadingIndicator`.
  ///
  /// Таблица в документации MDC называет 38dp (это `dimens.xml`), но стиль,
  /// от которого наследуются оба варианта, задаёт 34dp — берём фактическое
  /// значение из кода.
  static const double indicatorSize = 34;

  @override
  State<M3LoadingIndicator> createState() => _M3LoadingIndicatorState();
}

class _M3LoadingIndicatorState extends State<M3LoadingIndicator>
    with SingleTickerProviderStateMixin {
  final LoadingIndicatorMotion _motion = LoadingIndicatorMotion();

  // Не ленивое поле: `late final` с инициализатором создал бы тикер только
  // при первом обращении — то есть в dispose, и индикатор бы не анимировался.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _motion.update(elapsed));
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double side = widget.size ?? M3LoadingIndicator.containerSize;

    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: side,
        child: Transform.scale(
          scale: widget.scale,
          child: CustomPaint(
            painter: _LoadingIndicatorPainter(
              morphFactor: _motion.morphFactor,
              rotationDegrees: _motion.rotationDegrees,
              color:
                  widget.color ??
                  (widget.contained
                      ? colors.onPrimaryContainer
                      : colors.primary),
              containerColor: widget.contained
                  ? (widget.containerColor ?? colors.primaryContainer)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Движение индикатора — порт `LoadingIndicatorAnimatorDelegate`.
///
/// В оригинале два аниматора:
/// * линейный `ObjectAnimator` длиной [durationPerShape], повторяющийся
///   бесконечно; он даёт равномерную часть поворота;
/// * пружина `SpringAnimation` на `morphFactor`, которую при каждом повторе
///   линейного аниматора перенацеливают на следующее целое число. Целая
///   часть `morphFactor` — номер морфа, дробная — прогресс внутри него.
///   Пружина недодемпфирована, поэтому форма «пролетает» цель и
///   возвращается.
///
/// Вынесено из виджета, чтобы движение проверялось без отрисовки.
class LoadingIndicatorMotion {
  /// `DURATION_PER_SHAPE_IN_MS`.
  static const Duration durationPerShape = Duration(milliseconds: 650);

  /// `CONSTANT_ROTATION_PER_SHAPE_DEGREES` — равномерный поворот за шаг.
  static const double constantRotationPerShape = 50;

  /// `EXTRA_ROTATION_PER_SHAPE_DEGREES` — поворот, который ведёт пружина.
  static const double extraRotationPerShape = 90;

  /// `SPRING_STIFFNESS` и `SPRING_DAMPING_RATIO`.
  static const double springStiffness = 200;
  static const double springDampingRatio = 0.6;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: springStiffness,
    ratio: springDampingRatio,
  );

  /// `morphFactorTarget`: при старте 1, растёт на каждом повторе.
  int _morphFactorTarget = 1;

  /// Пружина к текущей цели и момент, когда её запустили.
  SpringSimulation _springSimulation = SpringSimulation(_spring, 0, 1, 0);
  double _springStartSeconds = 0;

  double _morphFactor = 0;
  double _rotationDegrees = 0;

  /// Целая часть — индекс морфа, дробная — прогресс внутри него.
  double get morphFactor => _morphFactor;

  /// Поворот формы в градусах, 0..360.
  double get rotationDegrees => _rotationDegrees;

  /// Пересчитывает состояние на момент [elapsed] от старта.
  void update(Duration elapsed) {
    final double seconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final double stepSeconds =
        durationPerShape.inMicroseconds / Duration.microsecondsPerSecond;

    // onAnimationRepeat: на каждом повторе линейного аниматора пружину
    // перенацеливают на следующее целое, сохраняя положение и скорость.
    final int repeats = (seconds / stepSeconds).floor();
    while (_morphFactorTarget - 1 < repeats) {
      final double repeatAt = _morphFactorTarget * stepSeconds;
      final double t = repeatAt - _springStartSeconds;
      final double position = _springSimulation.x(t);
      final double velocity = _springSimulation.dx(t);
      _morphFactorTarget++;
      _springSimulation = SpringSimulation(
        _spring,
        position,
        _morphFactorTarget.toDouble(),
        velocity,
      );
      _springStartSeconds = repeatAt;
    }

    final double springTime = seconds - _springStartSeconds;
    _morphFactor = _springSimulation.isDone(springTime)
        ? _morphFactorTarget.toDouble()
        : _springSimulation.x(springTime);

    // updateIndicatorRotation(playtime).
    final double playtime = seconds - repeats * stepSeconds;
    double timeFactorPerShape = playtime / stepSeconds;
    if (timeFactorPerShape >= 1) timeFactorPerShape = 0;

    final int morphFactorBase = _morphFactorTarget - 1;
    final double morphFactorPerShape = _morphFactor - morphFactorBase;

    _rotationDegrees =
        ((constantRotationPerShape + extraRotationPerShape) * morphFactorBase +
            constantRotationPerShape * timeFactorPerShape +
            extraRotationPerShape * morphFactorPerShape) %
        360;
  }
}

/// Последовательность морфов — `INDETERMINATE_MORPH_SEQUENCE` из
/// `LoadingIndicatorDrawingDelegate`.
abstract final class LoadingIndicatorShapes {
  /// `INDETERMINATE_SHAPES`: формы из `MaterialShapes` в порядке показа.
  static final List<RoundedPolygon> shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ].map(normalizeRadial).toList(growable: false);

  /// Морф каждой формы в следующую, последняя замыкается на первую.
  static final List<Morph> morphs = [
    for (int i = 0; i < shapes.length; i++)
      Morph(shapes[i], shapes[(i + 1) % shapes.length]),
  ];

  /// `MaterialShapes.normalize(shape, true, new RectF(-1, -1, 1, 1))`.
  ///
  /// Масштаб считается по `calculateMaxBounds` — квадрату, в который форма
  /// помещается при любом повороте, — поэтому вращение ничего не обрезает, а
  /// все формы визуально одного размера.
  static RoundedPolygon normalizeRadial(RoundedPolygon shape) {
    final List<double> bounds = shape.calculateMaxBounds();
    final double width = bounds[2] - bounds[0];
    final double height = bounds[3] - bounds[1];
    final double scale = math.min(2 / width, 2 / height);
    final double centerX = (bounds[0] + bounds[2]) / 2;
    final double centerY = (bounds[1] + bounds[3]) / 2;
    return shape.transformed(
      (x, y) => ((x - centerX) * scale, (y - centerY) * scale),
    );
  }
}

class _LoadingIndicatorPainter extends CustomPainter {
  _LoadingIndicatorPainter({
    required this.morphFactor,
    required this.rotationDegrees,
    required this.color,
    required this.containerColor,
  });

  final double morphFactor;
  final double rotationDegrees;
  final Color color;
  final Color? containerColor;

  @override
  void paint(Canvas canvas, Size size) {
    // adjustCanvas: начало координат в центре, масштаб под фактический
    // размер, поворот на -90°, чтобы 0° был сверху.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.shortestSide / M3LoadingIndicator.containerSize);
    canvas.rotate(-math.pi / 2);

    // drawContainer: скругление в половину стороны — это круг.
    if (containerColor != null) {
      canvas.drawCircle(
        Offset.zero,
        M3LoadingIndicator.containerSize / 2,
        Paint()..color = containerColor!,
      );
    }

    // drawIndicator.
    canvas.rotate(rotationDegrees * math.pi / 180);

    final int shapeMorphFraction = morphFactor.floor();
    final List<Morph> morphs = LoadingIndicatorShapes.morphs;
    // floorMod: у Dart остаток с положительным делителем неотрицательный.
    final Morph morph = morphs[shapeMorphFraction % morphs.length];
    final double fractionPerShape = morphFactor - shapeMorphFraction;

    // Формы нормированы в [-1, 1], поэтому путь растягивается на половину
    // размера индикатора.
    final double half = M3LoadingIndicator.indicatorSize / 2;
    final Path path = morph
        .toPath(progress: fractionPerShape)
        .transform(Matrix4.diagonal3Values(half, half, 1).storage);

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LoadingIndicatorPainter old) {
    return old.morphFactor != morphFactor ||
        old.rotationDegrees != rotationDegrees ||
        old.color != color ||
        old.containerColor != containerColor;
  }
}
