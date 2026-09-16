import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_motion.dart';
import '../theme/compose_spring.dart';

/// Индикатор загрузки Material 3 Expressive — порт Compose Material3
/// `LoadingIndicator` / `ContainedLoadingIndicator` (`LoadingIndicator.kt`).
///
/// Во Flutter 3.44 компонента нет. Формы и морфинг — пакет
/// `material_new_shapes`, Dart-порт `androidx.graphics.shapes`, на котором
/// построен и оригинал.
///
/// * [M3LoadingIndicator.new] — неопределённый вариант
///   (`LoadingIndicatorImpl` без `progress`): бесконечный морф
///   [LoadingIndicatorShapes.indeterminatePolygons].
/// * [M3LoadingIndicator.determinate] — определённый вариант
///   (`LoadingIndicatorImpl(progress)`): морф
///   [LoadingIndicatorShapes.determinatePolygons] по значению [progress].
///
/// [contained] выбирает между `LoadingIndicator` (по умолчанию, без
/// контейнера) и `ContainedLoadingIndicator`. Гайдлайн (Guidelines →
/// Container): контейнер нужен, когда индикатор лежит поверх контента, и в
/// pull-to-refresh; на поверхности он не нужен.
///
/// Уменьшение движения (`MediaQuery.disableAnimations`, «Удалить анимации»):
/// индикатор ведёт себя как Compose при `MotionDurationScale` = 0
/// (`SuspendAnimation.kt`, `doAnimationFrameWithScale`): каждая анимация
/// завершается в первом же кадре, а пауза `delay(MorphIntervalMillis)` —
/// нет. Поэтому раз в 650 мс форма сменяется на следующую без морфа и
/// поворачивается на 90°, общего вращения нет. Это же требует
/// https://m3.material.io/styles/motion/transitions («Follows accessibility
/// settings»: без shape morphing).
class M3LoadingIndicator extends StatefulWidget {
  /// Неопределённый индикатор: `LoadingIndicator(modifier, color, polygons)`
  /// или, при [contained], `ContainedLoadingIndicator(...)`.
  const M3LoadingIndicator({
    super.key,
    this.contained = false,
    this.size,
    this.color,
    this.containerColor,
    this.polygons,
    this.semanticsLabel = 'Загрузка',
  }) : progress = null;

  /// Определённый индикатор: `LoadingIndicator(progress, modifier, color,
  /// polygons)` или `ContainedLoadingIndicator(progress, ...)`.
  ///
  /// Своей анимации у варианта нет — [progress] анимирует вызывающий код
  /// (в `DeterminateLoadingIndicatorSample` — пружиной).
  const M3LoadingIndicator.determinate({
    super.key,
    required double this.progress,
    this.contained = false,
    this.size,
    this.color,
    this.containerColor,
    this.polygons,
    this.semanticsLabel = 'Загрузка',
  });

  /// `null` — неопределённый вариант. Иначе 0..1, значения вне диапазона
  /// приводятся к нему, как `coercedProgress` в Compose.
  final double? progress;

  /// `true` — `ContainedLoadingIndicator`: форма на круглом контейнере.
  final bool contained;

  /// Сторона индикатора вместе с контейнером, по умолчанию [containerSize].
  /// Гайдлайн (Guidelines → Responsive layout) разрешает 24–240dp;
  /// соотношение формы и контейнера при этом не меняется.
  final double? size;

  /// Цвет формы. По умолчанию `primary`
  /// (`LoadingIndicatorTokens.ActiveIndicatorColor`), для [contained] —
  /// `onPrimaryContainer` (`ContainedActiveColor`).
  final Color? color;

  /// Цвет контейнера, только для [contained]. По умолчанию
  /// `primaryContainer` (`ContainedContainerColor`).
  final Color? containerColor;

  /// Последовательность форм, минимум две (`require(size > 1)` в Compose).
  /// По умолчанию [LoadingIndicatorShapes.indeterminatePolygons] или
  /// [LoadingIndicatorShapes.determinatePolygons].
  final List<RoundedPolygon>? polygons;

  /// Подпись для TalkBack. Гайдлайн (Accessibility → Labeling elements):
  /// назначение индикатора, например «обновление страницы».
  final String? semanticsLabel;

  /// `LoadingIndicatorTokens.ContainerWidth` / `ContainerHeight`.
  static const double containerSize = 48;

  /// `LoadingIndicatorTokens.ActiveSize`.
  static const double indicatorSize = 38;

  /// `LoadingIndicatorDefaults.ActiveIndicatorScale` = 38 / 48.
  static const double activeIndicatorScale = indicatorSize / containerSize;

  /// Границы размера из Guidelines → Responsive layout.
  static const double minSize = 24;
  static const double maxSize = 240;

  @override
  State<M3LoadingIndicator> createState() => _M3LoadingIndicatorState();
}

class _M3LoadingIndicatorState extends State<M3LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<LoadingIndicatorFrame> _frame = ValueNotifier(
    LoadingIndicatorMotion.frameAt(Duration.zero, shapeCount: 2),
  );

  late LoadingIndicatorShapeSequence _sequence;
  bool _reduceMotion = false;

  bool get _indeterminate => widget.progress == null;

  @override
  void initState() {
    super.initState();
    _sequence = _sequenceFor(widget);
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
    _syncTicker(restart: false);
  }

  @override
  void didUpdateWidget(M3LoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool polygonsChanged =
        (oldWidget.progress == null) != _indeterminate ||
        !_samePolygons(oldWidget.polygons, widget.polygons);
    if (polygonsChanged) _sequence = _sequenceFor(widget);
    // `LaunchedEffect(indicatorPolygons)`: новый набор форм — новый цикл.
    _syncTicker(restart: polygonsChanged);
  }

  static bool _samePolygons(List<RoundedPolygon>? a, List<RoundedPolygon>? b) =>
      identical(a, b) || listEquals(a, b);

  static LoadingIndicatorShapeSequence _sequenceFor(M3LoadingIndicator w) {
    if (w.polygons != null) {
      return LoadingIndicatorShapeSequence(
        w.polygons!,
        circular: w.progress == null,
      );
    }
    return w.progress == null
        ? LoadingIndicatorShapes.indeterminate
        : LoadingIndicatorShapes.determinate;
  }

  void _syncTicker({required bool restart}) {
    if (!_indeterminate) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (restart && _ticker.isActive) _ticker.stop();
    if (!_ticker.isActive) {
      _tick(Duration.zero);
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    // Кадр меняется только когда меняется картинка: при уменьшении движения
    // это раз в 650 мс, и перерисовки между шагами не нужны.
    final LoadingIndicatorFrame next = LoadingIndicatorMotion.frameAt(
      elapsed,
      shapeCount: _sequence.morphs.length,
      reduceMotion: _reduceMotion,
    );
    if (next != _frame.value) _frame.value = next;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      (widget.polygons?.length ?? 2) > 1,
      'polygons should have, at least, two RoundedPolygons',
    );
    assert(
      widget.size == null ||
          (widget.size! >= M3LoadingIndicator.minSize &&
              widget.size! <= M3LoadingIndicator.maxSize),
      'Размер индикатора по гайдлайну — от 24 до 240dp',
    );

    final ColorScheme colors = Theme.of(context).colorScheme;
    final double side = widget.size ?? M3LoadingIndicator.containerSize;
    final double? progress = widget.progress;

    final LoadingIndicatorPainter painter = LoadingIndicatorPainter(
      sequence: _sequence,
      color:
          widget.color ??
          (widget.contained ? colors.onPrimaryContainer : colors.primary),
      containerColor: widget.contained
          ? (widget.containerColor ?? colors.primaryContainer)
          : null,
      progress: progress,
      frame: progress == null ? _frame : null,
    );

    final Widget indicator = SizedBox.square(
      dimension: side,
      child: CustomPaint(painter: painter),
    );

    // Как `ProgressIndicator._buildSemanticsWrapper` во Flutter: у Compose
    // определённый вариант отдаёт `progressBarRangeInfo`, неопределённый —
    // `progressSemantics()` (Indeterminate). Live region у Compose нет.
    if (progress == null) {
      return Semantics(
        label: widget.semanticsLabel,
        role: SemanticsRole.loadingSpinner,
        child: indicator,
      );
    }
    final double coerced = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    return Semantics(
      label: widget.semanticsLabel,
      role: SemanticsRole.progressBar,
      minValue: '0',
      maxValue: '100',
      value: '${(coerced * 100).round()}',
      child: indicator,
    );
  }
}

/// Состояние отрисовки индикатора в конкретный момент.
@immutable
class LoadingIndicatorFrame {
  const LoadingIndicatorFrame({
    required this.morphIndex,
    required this.morphProgress,
    required this.rotationDegrees,
  });

  /// Номер морфа в последовательности (`currentMorphIndex` /
  /// `activeMorphIndex`).
  final int morphIndex;

  /// Прогресс внутри морфа, передаётся в `Morph.toPath` как есть: у пружины
  /// он выходит за 1.
  final double morphProgress;

  /// Поворот формы в градусах; положительный — по часовой стрелке.
  final double rotationDegrees;

  @override
  bool operator ==(Object other) =>
      other is LoadingIndicatorFrame &&
      other.morphIndex == morphIndex &&
      other.morphProgress == morphProgress &&
      other.rotationDegrees == rotationDegrees;

  @override
  int get hashCode => Object.hash(morphIndex, morphProgress, rotationDegrees);

  @override
  String toString() =>
      'LoadingIndicatorFrame($morphIndex, $morphProgress, $rotationDegrees°)';
}

/// Движение индикатора из `LoadingIndicator.kt`. Чистые функции от времени и
/// прогресса, чтобы проверяться без отрисовки.
abstract final class LoadingIndicatorMotion {
  /// `MorphIntervalMillis`.
  static const Duration morphInterval = Duration(milliseconds: 650);

  /// `GlobalRotationDurationMillis`.
  static const Duration globalRotationDuration = Duration(milliseconds: 4666);

  /// `QuarterRotation` — начальный угол и прибавка за каждый морф.
  static const double quarterRotation = 90;

  /// `FullRotation`.
  static const double fullRotation = 360;

  /// `spring(dampingRatio = 0.6f, stiffness = 200f, visibilityThreshold =
  /// 0.1f)` — пружина морфа.
  static const double morphSpringDampingRatio = 0.6;
  static const double morphSpringStiffness = 200;
  static const double morphSpringVisibilityThreshold = 0.1;

  /// Длительность пружины морфа 0 → 1 по оценке Compose (`FloatSpringSpec.
  /// getDurationNanos`). Порог 0.1 выбран в Compose, чтобы пружина
  /// укладывалась в [morphInterval].
  static final Duration morphSpringDuration =
      ComposeSpringSimulation.estimateDuration(
        dampingRatio: morphSpringDampingRatio,
        stiffness: morphSpringStiffness,
        visibilityThreshold: morphSpringVisibilityThreshold,
        start: 0,
        end: 1,
      );

  static final ComposeSpringSimulation _morphSpring = ComposeSpringSimulation(
    dampingRatio: morphSpringDampingRatio,
    stiffness: morphSpringStiffness,
    visibilityThreshold: morphSpringVisibilityThreshold,
    start: 0,
    end: 1,
  );

  /// Неопределённый вариант на момент [elapsed] от запуска.
  ///
  /// Цикл `LaunchedEffect` в `LoadingIndicatorImpl`: в начале каждого
  /// интервала 650 мс `morphProgress.animateTo(1f, spring)`; когда пружина
  /// завершилась — `currentMorphIndex + 1`, `snapTo(0f)`,
  /// `morphRotationTargetAngle + 90°` (по модулю 360). Параллельно
  /// `globalRotation` 0 → 360° за 4666 мс линейно. Угол отрисовки —
  /// `progress × 90 + morphRotationTargetAngle + globalRotation`.
  ///
  /// [reduceMotion] — `MotionDurationScale` = 0: пружина завершается в первом
  /// кадре, `globalRotation` сразу стоит в конце (360°).
  static LoadingIndicatorFrame frameAt(
    Duration elapsed, {
    required int shapeCount,
    bool reduceMotion = false,
  }) {
    final int intervalUs = morphInterval.inMicroseconds;
    final int elapsedUs = math.max(0, elapsed.inMicroseconds);
    final int step = elapsedUs ~/ intervalUs;
    final int localUs = elapsedUs - step * intervalUs;

    final bool springRunning =
        !reduceMotion && localUs < morphSpringDuration.inMicroseconds;
    // Сколько морфов уже завершилось к этому моменту.
    final int completed = springRunning ? step : step + 1;
    final double progress = springRunning
        ? _morphSpring.x(localUs / Duration.microsecondsPerSecond)
        : 0;
    final double target =
        (quarterRotation + quarterRotation * completed) % fullRotation;

    final double global;
    if (reduceMotion) {
      global = fullRotation;
    } else {
      final int rotationUs = globalRotationDuration.inMicroseconds;
      global = (elapsedUs % rotationUs) / rotationUs * fullRotation;
    }

    return LoadingIndicatorFrame(
      morphIndex: completed % shapeCount,
      morphProgress: progress,
      rotationDegrees: progress * quarterRotation + target + global,
    );
  }

  /// Определённый вариант: `LoadingIndicatorImpl(progress)`.
  ///
  /// [morphCount] — число морфов (`morphSequence.size`).
  static LoadingIndicatorFrame determinateFrame(
    double progress, {
    required int morphCount,
  }) {
    // `coercedProgress`; NaN в Compose даёт `toInt()` = 0.
    final double value = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    final int activeMorphIndex = math.min(
      (morphCount * value).toInt(),
      morphCount - 1,
    );
    final double adjustedProgress =
        value == 1 && activeMorphIndex == morphCount - 1
        ? 1
        : (value * morphCount) % 1;
    return LoadingIndicatorFrame(
      morphIndex: activeMorphIndex,
      morphProgress: adjustedProgress,
      // Против часовой стрелки.
      rotationDegrees: -value * 180,
    );
  }
}

/// Последовательность морфов с общим коэффициентом масштаба.
class LoadingIndicatorShapeSequence {
  LoadingIndicatorShapeSequence(
    List<RoundedPolygon> polygons, {
    required bool circular,
  }) : assert(
         polygons.length > 1,
         'indicatorPolygons should have, at least, two RoundedPolygons',
       ),
       morphs = morphSequence(polygons, circular: circular),
       scaleFactor =
           calculateScaleFactor(polygons) *
           M3LoadingIndicator.activeIndicatorScale;

  /// Морфы между соседними формами; формы нормализованы.
  final List<Morph> morphs;

  /// `calculateScaleFactor(polygons) × ActiveIndicatorScale`.
  final double scaleFactor;

  /// `morphSequence(polygons, circularSequence)`: морф каждой формы в
  /// следующую (обе `normalized()`), при [circular] — и последней в первую.
  static List<Morph> morphSequence(
    List<RoundedPolygon> polygons, {
    required bool circular,
  }) {
    return [
      for (int i = 0; i < polygons.length; i++)
        if (i + 1 < polygons.length)
          Morph(polygons[i].normalized(), polygons[i + 1].normalized())
        else if (circular)
          Morph(polygons[i].normalized(), polygons[0].normalized()),
    ];
  }

  /// `calculateScaleFactor`: один коэффициент на всю последовательность —
  /// минимум по формам от `max(bounds.w / maxBounds.w, bounds.h /
  /// maxBounds.h)`. Так ни одна форма не обрезается при вращении, а все
  /// рисуются в одном масштабе.
  static double calculateScaleFactor(List<RoundedPolygon> polygons) {
    double scaleFactor = 1;
    for (final RoundedPolygon polygon in polygons) {
      final List<double> bounds = polygon.calculateBounds();
      final List<double> maxBounds = polygon.calculateMaxBounds();
      final double scaleX =
          (bounds[2] - bounds[0]) / (maxBounds[2] - maxBounds[0]);
      final double scaleY =
          (bounds[3] - bounds[1]) / (maxBounds[3] - maxBounds[1]);
      scaleFactor = math.min(scaleFactor, math.max(scaleX, scaleY));
    }
    return scaleFactor;
  }
}

/// Наборы форм из `LoadingIndicatorDefaults`.
abstract final class LoadingIndicatorShapes {
  /// `IndeterminateIndicatorPolygons`.
  static final List<RoundedPolygon> indeterminatePolygons = List.unmodifiable([
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ]);

  /// Поворот круга в `DeterminateIndicatorPolygons`: 360 / 20 = 18°.
  static const double determinateCircleRotationDegrees = 360 / 20;

  /// `DeterminateIndicatorPolygons`: круг, повёрнутый на 18° («so the morph
  /// to the soft-burst is smoother»), и `SoftBurst`.
  static final List<RoundedPolygon> determinatePolygons = List.unmodifiable([
    MaterialShapes.circle.transformed((x, y) {
      // `Matrix().rotateZ(18f)` вокруг начала координат.
      const double r = determinateCircleRotationDegrees * math.pi / 180;
      return (
        x * math.cos(r) - y * math.sin(r),
        x * math.sin(r) + y * math.cos(r),
      );
    }),
    MaterialShapes.softBurst,
  ]);

  static final LoadingIndicatorShapeSequence indeterminate =
      LoadingIndicatorShapeSequence(indeterminatePolygons, circular: true);

  static final LoadingIndicatorShapeSequence determinate =
      LoadingIndicatorShapeSequence(determinatePolygons, circular: false);
}

/// Отрисовка `LoadingIndicatorImpl`: контейнер, затем путь морфа через
/// `processPath` с поворотом вокруг центра.
@visibleForTesting
class LoadingIndicatorPainter extends CustomPainter {
  LoadingIndicatorPainter({
    required this.sequence,
    required this.color,
    required this.containerColor,
    this.progress,
    this.frame,
  }) : assert((progress == null) != (frame == null)),
       super(repaint: frame);

  final LoadingIndicatorShapeSequence sequence;
  final Color color;

  /// `null` — без контейнера (`Color.Unspecified` в Compose).
  final Color? containerColor;

  /// Прогресс определённого варианта.
  final double? progress;

  /// Кадры неопределённого варианта.
  final ValueListenable<LoadingIndicatorFrame>? frame;

  /// Кадр, который будет нарисован сейчас.
  LoadingIndicatorFrame get currentFrame =>
      frame?.value ??
      LoadingIndicatorMotion.determinateFrame(
        progress!,
        morphCount: sequence.morphs.length,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // `Box.clip(containerShape).background(containerColor)`: CornerFull.
    final Rect box = Offset.zero & size;
    canvas.clipRRect(
      RRect.fromRectAndRadius(box, Radius.circular(size.shortestSide / 2)),
    );
    if (containerColor != null) {
      canvas.drawRect(box, Paint()..color = containerColor!);
    }

    // `Spacer.aspectRatio(1f, matchHeightConstraintsFirst = true)`.
    final double side = size.shortestSide;
    final Offset center = box.center;

    final LoadingIndicatorFrame current = currentFrame;
    final Morph morph =
        sequence.morphs[current.morphIndex % sequence.morphs.length];
    Path path = morph.toPath(progress: current.morphProgress);

    // `processPath`: масштаб на сторону × коэффициент, затем центр границ
    // пути совмещается с центром области.
    final double scale = side * sequence.scaleFactor;
    path = path.transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
    path = path.shift(center - path.getBounds().center);

    // `DrawScope.rotate(degrees)` — вокруг центра, по часовой.
    canvas.translate(center.dx, center.dy);
    canvas.rotate(current.rotationDegrees * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(LoadingIndicatorPainter oldDelegate) {
    return oldDelegate.sequence != sequence ||
        oldDelegate.color != color ||
        oldDelegate.containerColor != containerColor ||
        oldDelegate.progress != progress ||
        oldDelegate.frame != frame;
  }
}
