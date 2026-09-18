import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_motion.dart';
import '../theme/app_typography.dart';

/// Пустое состояние с геометрической иллюстрацией.
///
/// Иллюстрация собрана из фигур библиотеки M3, поэтому переезжает между
/// палитрами и темами без отдельных ассетов.
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

/// Слой композиции: цикл форм, период вращения и сдвиг такта.
class _ShapeLayer {
  _ShapeLayer({
    required this.polygons,
    required this.rotation,
    required this.phase,
  }) : morphs = [
         for (int i = 0; i < polygons.length; i++)
           Morph(
             polygons[i].normalized(),
             polygons[(i + 1) % polygons.length].normalized(),
           ),
       ];

  final List<RoundedPolygon> polygons;
  final List<Morph> morphs;

  /// Полный оборот слоя.
  final Duration rotation;

  /// Сдвиг такта морфа, чтобы слои не щёлкали одновременно.
  final Duration phase;
}

/// Движение композиции — по документированным приёмам M3.
abstract final class _IllustrationMotion {
  /// Такт морфа: `md.sys.motion.duration.extra-long4` = 1000 мс —
  /// https://m3.material.io/styles/motion/easing-and-duration, «Extra long
  /// durations… ambient transitions that don't involve user input».
  static const Duration morphInterval = Duration(milliseconds: 1000);

  /// Базовый период вращения — `GlobalRotationDurationMillis` из Compose
  /// `LoadingIndicator.kt`; слои крутятся кратно медленнее, чтобы декор не
  /// читался как индикатор загрузки.
  static const Duration baseRotation = Duration(milliseconds: 4666);

  /// `QuarterRotation` из `LoadingIndicator.kt`: за один морф фигура
  /// доворачивается на 90°.
  static const double quarterRotation = 90;

  /// Перелёт пружины допустим: «values close to (but outside) the range can be
  /// used to get an exaggerated effect (e.g., for a bounce or overshoot
  /// animation)» — kdoc `Morph.asCubics`.
  static const double minProgress = -0.15;
  static const double maxProgress = 1.15;
}

/// Декор пустого состояния из библиотеки форм M3.
///
/// https://m3.material.io/styles/shape — «Emphasize aesthetic moments with
/// shape»: абстрактные формы уместны в декоративных, неинтерактивных местах.
/// Формы морфятся и вращаются: «Progress could just as easily be shown using
/// rotating shapes or shape morph», «Shape can be 2.5D — apply motion and
/// shape differently on each layer to give it the illusion of depth».
/// Сочетание круглых и угловатых форм — приём «tension» из M3 Expressive.
///
/// Морф — пружина `slowSpatial` (схема expressive, «Shape morphing uses the
/// expressive motion scheme by default»; «larger elements may use slow»),
/// поворот на 90° за морф и медленное общее вращение — как у неопределённого
/// `LoadingIndicator` (`LoadingIndicator.kt`), только в несколько раз
/// медленнее. Столкновений фигур в спеке нет — их и нет здесь.
///
/// При системной настройке «Удалить анимации» композиция статична:
/// https://m3.material.io/styles/motion/transitions — «Disable decorative
/// effects like parallax or shape morphing».
class _GeometricIllustration extends StatefulWidget {
  const _GeometricIllustration({
    required this.size,
    required this.withAccentDot,
  });

  final Size size;
  final bool withAccentDot;

  @override
  State<_GeometricIllustration> createState() => _GeometricIllustrationState();
}

class _GeometricIllustrationState extends State<_GeometricIllustration>
    with SingleTickerProviderStateMixin {
  /// Циклы начинаются с фигур макета: круг, скруглённый квадрат, треугольник.
  static final List<_ShapeLayer> layers = [
    _ShapeLayer(
      polygons: [
        MaterialShapes.circle,
        MaterialShapes.cookie9Sided,
        MaterialShapes.oval,
        MaterialShapes.clover4Leaf,
      ],
      rotation: _IllustrationMotion.baseRotation * 4,
      phase: Duration.zero,
    ),
    _ShapeLayer(
      polygons: [
        MaterialShapes.square,
        MaterialShapes.slanted,
        MaterialShapes.gem,
        MaterialShapes.diamond,
      ],
      rotation: _IllustrationMotion.baseRotation * 3,
      phase: const Duration(milliseconds: 333),
    ),
    _ShapeLayer(
      polygons: [
        MaterialShapes.triangle,
        MaterialShapes.arrow,
        MaterialShapes.pentagon,
        MaterialShapes.pixelTriangle,
      ],
      rotation: _IllustrationMotion.baseRotation * 2,
      phase: const Duration(milliseconds: 666),
    ),
  ];

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _elapsed.value = Duration.zero;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) => _elapsed.value = elapsed;

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final double w = widget.size.width;
    final double h = widget.size.height;

    // Пропорции композиции — из макета.
    final List<Rect> bounds = [
      Rect.fromLTWH(w * 0.04, h * 0.12, w * 0.58, w * 0.58),
      Rect.fromLTWH(w * 0.51, h - w * 0.47, w * 0.47, w * 0.47),
      Rect.fromLTWH(w * 0.53, 0, w * 0.33, w * 0.33),
    ];

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _IllustrationPainter(
              elapsed: _elapsed,
              reduceMotion: _reduceMotion,
              bounds: bounds,
              colors: [
                colors.primaryContainer,
                colors.tertiaryContainer,
                colors.surfaceContainerHigh,
              ],
              accentDot: widget.withAccentDot
                  ? (
                      Rect.fromLTWH(
                        w * 0.3,
                        h * 0.83 - w * 0.15,
                        w * 0.15,
                        w * 0.15,
                      ),
                      colors.primary,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.elapsed,
    required this.reduceMotion,
    required this.bounds,
    required this.colors,
    required this.accentDot,
  }) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final bool reduceMotion;
  final List<Rect> bounds;
  final List<Color> colors;

  /// Акцентная точка: она не морфится и не вращается — мелкий элемент.
  final (Rect, Color)? accentDot;

  /// Пружина морфа: `slowSpatial` = 0.8 / 200 (`ExpressiveMotionTokens`).
  static final SpringSimulation _morphSpring = AppMotion.slowSpatial.simulate();

  /// Буфер пути: путь пересобирается каждый кадр, аллокация не нужна.
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final Duration now = elapsed.value;
    for (int i = 0; i < _GeometricIllustrationState.layers.length; i++) {
      _paintLayer(
        canvas,
        layer: _GeometricIllustrationState.layers[i],
        rect: bounds[i],
        color: colors[i],
        elapsed: now,
      );
    }

    final (Rect, Color)? dot = accentDot;
    if (dot != null) {
      _path.reset();
      final Path path = MaterialShapes.circle.normalized().toPath(path: _path);
      canvas.drawPath(
        path.transform(_fitTo(dot.$1).storage),
        Paint()..color = dot.$2,
      );
    }
  }

  void _paintLayer(
    Canvas canvas, {
    required _ShapeLayer layer,
    required Rect rect,
    required Color color,
    required Duration elapsed,
  }) {
    double progress = 0;
    int step = 0;
    double rotation = 0;

    if (!reduceMotion) {
      final int micros = elapsed.inMicroseconds + layer.phase.inMicroseconds;
      final int interval = _IllustrationMotion.morphInterval.inMicroseconds;
      step = micros ~/ interval % layer.morphs.length;
      // Пружина отрабатывает внутри такта и успевает осесть до следующего.
      progress = _morphSpring
          .x((micros % interval) / Duration.microsecondsPerSecond)
          .clamp(
            _IllustrationMotion.minProgress,
            _IllustrationMotion.maxProgress,
          );
      // `rotate(progress * 90 + morphRotationTargetAngle + globalRotation)`.
      final double turns =
          elapsed.inMicroseconds / layer.rotation.inMicroseconds;
      rotation =
          progress * _IllustrationMotion.quarterRotation +
          step * _IllustrationMotion.quarterRotation +
          turns * 360;
    }

    _path.reset();
    final Path path = layer.morphs[step].toPath(
      progress: progress,
      path: _path,
    );

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawPath(
      path.transform(_fitTo(rect).storage),
      Paint()..color = color,
    );
    canvas.restore();
  }

  /// Нормализованная форма (0..1) — в прямоугольник слоя.
  static Matrix4 _fitTo(Rect rect) =>
      Matrix4.translationValues(rect.left, rect.top, 0)
        ..multiply(Matrix4.diagonal3Values(rect.width, rect.height, 1));

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.reduceMotion != reduceMotion ||
      old.colors != colors ||
      old.bounds != bounds ||
      old.accentDot != accentDot;
}
