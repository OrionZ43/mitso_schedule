import 'dart:math' as math;

import 'package:flutter/material.dart' hide Cubic;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:mitso_schedule/theme/compose_spring.dart';
import 'package:mitso_schedule/widgets/m3_loading_indicator.dart';
import 'package:mitso_schedule/widgets/m3_wavy_linear_progress.dart';

/// Границы по точкам на самой кривой.
Rect _curveBounds(Path path) {
  double left = double.infinity, top = double.infinity;
  double right = -double.infinity, bottom = -double.infinity;
  for (final metric in path.computeMetrics()) {
    for (double d = 0; d <= metric.length; d += metric.length / 2000) {
      final Offset p = metric.getTangentForOffset(d)!.position;
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

LoadingIndicatorFrame _frame(int ms, {bool reduceMotion = false}) =>
    LoadingIndicatorMotion.frameAt(
      Duration(milliseconds: ms),
      shapeCount: 7,
      reduceMotion: reduceMotion,
    );

/// Пружина морфа Compose: `spring(0.6f, 200f, visibilityThreshold = 0.1f)`.
final ComposeSpringSimulation _morphSpring = ComposeSpringSimulation(
  dampingRatio: 0.6,
  stiffness: 200,
  visibilityThreshold: 0.1,
  start: 0,
  end: 1,
);

T _painter<T extends CustomPainter>(WidgetTester tester, Finder of) =>
    tester
            .renderObject<RenderCustomPaint>(
              find.descendant(of: of, matching: find.byType(CustomPaint)).first,
            )
            .painter!
        as T;

void main() {
  group('LoadingIndicatorShapes — LoadingIndicatorDefaults', () {
    test('IndeterminateIndicatorPolygons: семь форм в порядке Compose', () {
      expect(LoadingIndicatorShapes.indeterminatePolygons, [
        MaterialShapes.softBurst,
        MaterialShapes.cookie9Sided,
        MaterialShapes.pentagon,
        MaterialShapes.pill,
        MaterialShapes.sunny,
        MaterialShapes.cookie4Sided,
        MaterialShapes.oval,
      ]);
      // circularSequence = true: последняя форма морфится в первую.
      expect(LoadingIndicatorShapes.indeterminate.morphs, hasLength(7));
    });

    test(
      'DeterminateIndicatorPolygons: круг, повёрнутый на 18°, и SoftBurst',
      () {
        final List<RoundedPolygon> polygons =
            LoadingIndicatorShapes.determinatePolygons;
        expect(polygons, hasLength(2));
        expect(polygons[1], MaterialShapes.softBurst);
        expect(LoadingIndicatorShapes.determinateCircleRotationDegrees, 18);

        // Первая вершина круга повёрнута на 18° вокруг начала координат.
        final Cubic original = MaterialShapes.circle.cubics.first;
        final Cubic rotated = polygons[0].cubics.first;
        const double r = 18 * math.pi / 180;
        expect(
          rotated.anchor0X,
          closeTo(
            original.anchor0X * math.cos(r) - original.anchor0Y * math.sin(r),
            1e-9,
          ),
        );
        expect(
          rotated.anchor0Y,
          closeTo(
            original.anchor0X * math.sin(r) + original.anchor0Y * math.cos(r),
            1e-9,
          ),
        );
        // Без замыкания — один морф.
        expect(LoadingIndicatorShapes.determinate.morphs, hasLength(1));
      },
    );

    test('токены: контейнер 48dp, форма 38dp, масштаб 38/48', () {
      expect(M3LoadingIndicator.containerSize, 48);
      expect(M3LoadingIndicator.indicatorSize, 38);
      expect(M3LoadingIndicator.activeIndicatorScale, 38 / 48);
    });

    test(
      'calculateScaleFactor: один коэффициент на всю последовательность',
      () {
        final List<RoundedPolygon> polygons =
            LoadingIndicatorShapes.indeterminatePolygons;
        final double k = LoadingIndicatorShapeSequence.calculateScaleFactor(
          polygons,
        );
        expect(k, closeTo(0.866, 1e-3));
        expect(
          LoadingIndicatorShapes.indeterminate.scaleFactor,
          closeTo(k * 38 / 48, 1e-12),
        );

        // Нормализованная форма вписана в единичный квадрат, значит в 48dp
        // каждая занимает 48 · k · 38/48 = 38 · k ≈ 32,9dp.
        const double side = 48;
        final double drawn =
            side * LoadingIndicatorShapes.indeterminate.scaleFactor;
        expect(drawn, closeTo(32.9, 0.05));

        // При вращении форма заметает не больше 38dp, а самая «широкая» —
        // ровно 38dp: так коэффициент и выбран.
        double widestSweep = 0;
        for (final RoundedPolygon polygon in polygons) {
          final RoundedPolygon normalized = polygon.normalized();
          final List<double> bounds = normalized.calculateBounds();
          final List<double> maxBounds = normalized.calculateMaxBounds();
          final double boundsSide = math.max(
            bounds[2] - bounds[0],
            bounds[3] - bounds[1],
          );
          final double sweep =
              (maxBounds[2] - maxBounds[0]) / boundsSide * drawn;
          expect(sweep, lessThanOrEqualTo(38 + 1e-6));
          widestSweep = math.max(widestSweep, sweep);
        }
        expect(widestSweep, closeTo(38, 1e-6));
      },
    );

    test('морфы сцеплены: конец одного совпадает с началом следующего', () {
      // Сравниваем геометрию, а не Path.getBounds(): тот берёт границы по
      // контрольным точкам, а морф режет одну и ту же форму на кубики
      // по-разному.
      final List<Morph> morphs = LoadingIndicatorShapes.indeterminate.morphs;
      for (int i = 0; i < morphs.length; i++) {
        final Rect end = _curveBounds(morphs[i].toPath(progress: 1));
        final Rect start = _curveBounds(
          morphs[(i + 1) % morphs.length].toPath(progress: 0),
        );
        expect(end.left, closeTo(start.left, 1e-2), reason: 'морф $i');
        expect(end.top, closeTo(start.top, 1e-2), reason: 'морф $i');
        expect(end.right, closeTo(start.right, 1e-2), reason: 'морф $i');
        expect(end.bottom, closeTo(start.bottom, 1e-2), reason: 'морф $i');
      }
    });
  });

  group('LoadingIndicatorMotion — неопределённый LoadingIndicatorImpl', () {
    test('константы совпадают с Compose', () {
      expect(
        LoadingIndicatorMotion.morphInterval,
        const Duration(milliseconds: 650),
      );
      expect(
        LoadingIndicatorMotion.globalRotationDuration,
        const Duration(milliseconds: 4666),
      );
      expect(LoadingIndicatorMotion.quarterRotation, 90);
      expect(LoadingIndicatorMotion.morphSpringDampingRatio, 0.6);
      expect(LoadingIndicatorMotion.morphSpringStiffness, 200);
      expect(LoadingIndicatorMotion.morphSpringVisibilityThreshold, 0.1);
    });

    test('пружина морфа с порогом 0.1 укладывается в интервал 650 мс', () {
      // estimateAnimationDurationMillis для 0 → 1: огибающая 12,5·e^(−8,49·t)
      // опускается до порога через 297 мс.
      expect(
        LoadingIndicatorMotion.morphSpringDuration,
        const Duration(milliseconds: 297),
      );
      expect(
        LoadingIndicatorMotion.morphSpringDuration,
        lessThan(LoadingIndicatorMotion.morphInterval),
      );
      // К моменту завершения пружина уже в пределах порога от цели.
      expect((_morphSpring.x(0.2969) - 1).abs(), lessThan(0.1));
      expect(_morphSpring.x(0.297), 1);
    });

    test('старт: первая форма, морф 0, угол 90°', () {
      final LoadingIndicatorFrame frame = _frame(0);
      expect(frame.morphIndex, 0);
      expect(frame.morphProgress, 0);
      expect(frame.rotationDegrees, 90);
    });

    test('угол = morph × 90 + цель + общее вращение 360°/4666 мс', () {
      final LoadingIndicatorFrame frame = _frame(150);
      final double morph = _morphSpring.x(0.150);
      expect(frame.morphIndex, 0);
      expect(frame.morphProgress, closeTo(morph, 1e-9));
      expect(
        frame.rotationDegrees,
        closeTo(morph * 90 + 90 + 150 / 4666 * 360, 1e-9),
      );
    });

    test('пружина недодемпфирована: морф пролетает 1', () {
      double peak = 0;
      for (int t = 0; t < 297; t += 2) {
        peak = math.max(peak, _frame(t).morphProgress);
      }
      expect(peak, greaterThan(1.0));
    });

    test(
      'после пружины: snapTo(0), индекс +1, цель +90° до конца интервала',
      () {
        for (final int t in [297, 400, 649]) {
          final LoadingIndicatorFrame frame = _frame(t);
          expect(frame.morphIndex, 1, reason: '$t мс');
          expect(frame.morphProgress, 0, reason: '$t мс');
          expect(
            frame.rotationDegrees,
            closeTo(180 + t / 4666 * 360, 1e-9),
            reason: '$t мс',
          );
        }
      },
    );

    test('следующий морф начинается ровно через 650 мс с нуля', () {
      final LoadingIndicatorFrame frame = _frame(650 + 100);
      expect(frame.morphIndex, 1);
      expect(frame.morphProgress, closeTo(_morphSpring.x(0.1), 1e-9));
      expect(
        frame.rotationDegrees,
        closeTo(_morphSpring.x(0.1) * 90 + 180 + 750 / 4666 * 360, 1e-9),
      );
    });

    test('индекс идёт по кругу, цель — по модулю 360°', () {
      // Семь завершённых морфов: снова первая форма, 90 + 7·90 = 720 ≡ 0°.
      final LoadingIndicatorFrame frame = _frame(6 * 650 + 400);
      expect(frame.morphIndex, 0);
      final double global = (6 * 650 + 400) % 4666 / 4666 * 360;
      expect(frame.rotationDegrees, closeTo(0 + global, 1e-9));
    });

    test('общее вращение перезапускается каждые 4666 мс', () {
      expect(
        _frame(4666).rotationDegrees - _frame(0).rotationDegrees,
        // На 4666 мс: 7 интервалов + 116 мс, морф 7 уже начат заново.
        closeTo(_morphSpring.x(0.116) * 90 + (90 + 7 * 90) % 360 - 90, 1e-9),
      );
    });

    test('на снапе картинка не прыгает: морф i в 1 = морф i+1 в 0', () {
      // Угол до снапа отличается от угла после не больше чем на порог
      // пружины (0.1 × 90°).
      final LoadingIndicatorFrame before = _frame(296);
      final LoadingIndicatorFrame after = _frame(297);
      expect(
        (after.rotationDegrees - before.rotationDegrees).abs(),
        lessThan(9.5),
      );
    });

    test(
      'уменьшение движения: смена формы раз в 650 мс без морфа и вращения',
      () {
        final LoadingIndicatorFrame first = _frame(0, reduceMotion: true);
        expect(first.morphIndex, 1);
        expect(first.morphProgress, 0);
        expect(first.rotationDegrees, 180 + 360);
        expect(_frame(649, reduceMotion: true), first);

        final LoadingIndicatorFrame second = _frame(650, reduceMotion: true);
        expect(second.morphIndex, 2);
        expect(second.rotationDegrees, 270 + 360);
      },
    );
  });

  group('LoadingIndicatorMotion — определённый LoadingIndicatorImpl', () {
    test('морф и поворот −progress × 180°', () {
      LoadingIndicatorFrame at(double p, [int morphs = 1]) =>
          LoadingIndicatorMotion.determinateFrame(p, morphCount: morphs);

      expect(at(0).morphIndex, 0);
      expect(at(0).morphProgress, 0);
      expect(at(0).rotationDegrees, -0.0);

      expect(at(0.5).morphProgress, 0.5);
      expect(at(0.5).rotationDegrees, -90);

      // progress == 1 на последнем морфе: берётся 1, а не 0.
      expect(at(1).morphIndex, 0);
      expect(at(1).morphProgress, 1);
      expect(at(1).rotationDegrees, -180);

      // Вне диапазона значения приводятся к 0..1, NaN — к 0.
      expect(at(1.4), at(1));
      expect(at(-0.3), at(0));
      expect(at(double.nan), at(0));

      // Три формы — два морфа.
      expect(at(0.75, 2).morphIndex, 1);
      expect(at(0.75, 2).morphProgress, closeTo(0.5, 1e-12));
      expect(at(1, 2).morphIndex, 1);
      expect(at(1, 2).morphProgress, 1);
    });
  });

  group('M3LoadingIndicator', () {
    testWidgets('по умолчанию без контейнера, 48dp, цвет primary', (
      tester,
    ) async {
      final ThemeData theme = ThemeData();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(child: M3LoadingIndicator()),
        ),
      );
      final Finder indicator = find.byType(M3LoadingIndicator);
      expect(tester.getSize(indicator), const Size.square(48));

      final LoadingIndicatorPainter painter = _painter(tester, indicator);
      expect(painter.containerColor, isNull);
      expect(painter.color, theme.colorScheme.primary);
      expect(painter.sequence, LoadingIndicatorShapes.indeterminate);
    });

    testWidgets('contained: primaryContainer и onPrimaryContainer', (
      tester,
    ) async {
      final ThemeData theme = ThemeData();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(child: M3LoadingIndicator(contained: true)),
        ),
      );
      final LoadingIndicatorPainter painter = _painter(
        tester,
        find.byType(M3LoadingIndicator),
      );
      expect(painter.containerColor, theme.colorScheme.primaryContainer);
      expect(painter.color, theme.colorScheme.onPrimaryContainer);
    });

    testWidgets('анимируется покадрово и совпадает с моделью', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: M3LoadingIndicator())),
      );
      final LoadingIndicatorPainter painter = _painter(
        tester,
        find.byType(M3LoadingIndicator),
      );
      int repaints = 0;
      painter.addListener(() => repaints++);

      // Ленивый тикер когда-то молча оставлял индикатор неподвижным.
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(repaints, greaterThan(50), reason: 'индикатор не анимируется');
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Первый кадр тикера — момент старта, дальше 60 × 16 мс.
      expect(painter.currentFrame, _frame(60 * 16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('уменьшение движения: перерисовка только при смене формы', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(child: M3LoadingIndicator()),
          ),
        ),
      );
      final LoadingIndicatorPainter painter = _painter(
        tester,
        find.byType(M3LoadingIndicator),
      );
      int repaints = 0;
      painter.addListener(() => repaints++);
      for (int i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 1280 мс — две смены формы.
      expect(repaints, 1);
      expect(painter.currentFrame.morphProgress, 0);
    });

    testWidgets('determinate: без тикера, семантика progress bar', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: M3LoadingIndicator.determinate(
              progress: 0.42,
              semanticsLabel: 'Обновление страницы',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      final LoadingIndicatorPainter painter = _painter(
        tester,
        find.byType(M3LoadingIndicator),
      );
      expect(painter.sequence, LoadingIndicatorShapes.determinate);
      expect(painter.currentFrame.rotationDegrees, closeTo(-0.42 * 180, 1e-9));

      final SemanticsData data = tester
          .getSemantics(find.byType(M3LoadingIndicator))
          .getSemanticsData();
      expect(data.role, SemanticsRole.progressBar);
      expect(data.label, 'Обновление страницы');
      expect(data.value, '42');
      expect(data.minValue, '0');
      expect(data.maxValue, '100');
      semantics.dispose();
    });

    testWidgets('indeterminate: роль loading spinner без live region', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: M3LoadingIndicator(semanticsLabel: 'Загрузка')),
        ),
      );
      final SemanticsData data = tester
          .getSemantics(find.byType(M3LoadingIndicator))
          .getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);
      expect(data.label, 'Загрузка');
      expect(data.flagsCollection.isLiveRegion, isFalse);
      semantics.dispose();
    });

    testWidgets('свои polygons и размер 24dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: M3LoadingIndicator(
              size: 24,
              polygons: [MaterialShapes.circle, MaterialShapes.square],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final Finder indicator = find.byType(M3LoadingIndicator);
      expect(tester.getSize(indicator), const Size.square(24));
      final LoadingIndicatorPainter painter = _painter(tester, indicator);
      expect(painter.sequence.morphs, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('M3WavyLinearProgress — токены Compose', () {
    test('размеры и длительности', () {
      expect(M3WavyLinearProgress.thickness, 4);
      expect(M3WavyLinearProgress.trackThickness, 4);
      expect(M3WavyLinearProgress.trackGap, 4);
      expect(M3WavyLinearProgress.stopIndicatorSize, 4);
      expect(M3WavyLinearProgress.amplitude, 3);
      expect(M3WavyLinearProgress.wavelength, 40);
      expect(M3WavyLinearProgress.height, 10);
      expect(M3WavyLinearProgress.containerWidth, 240);
      expect(
        M3WavyLinearProgress.progressAnimationDuration,
        const Duration(milliseconds: 500),
      );
      expect(
        M3WavyLinearProgress.amplitudeAnimationDuration,
        const Duration(milliseconds: 500),
      );
      expect(M3WavyLinearProgress.increasingAmplitudeEasing, Easing.standard);
      expect(
        M3WavyLinearProgress.decreasingAmplitudeEasing,
        Easing.emphasizedAccelerate,
      );
    });

    test('indicatorAmplitude: волна только при 0.1 < p < 0.95', () {
      expect(M3WavyLinearProgress.indicatorAmplitude(0), 0);
      expect(M3WavyLinearProgress.indicatorAmplitude(0.1), 0);
      expect(M3WavyLinearProgress.indicatorAmplitude(0.1001), 1);
      expect(M3WavyLinearProgress.indicatorAmplitude(0.66), 1);
      expect(M3WavyLinearProgress.indicatorAmplitude(0.9499), 1);
      expect(M3WavyLinearProgress.indicatorAmplitude(0.95), 0);
      expect(M3WavyLinearProgress.indicatorAmplitude(1), 0);
    });

    test('скорость волны: длина волны в секунду, не быстрее 50 мс', () {
      expect(
        M3WavyLinearProgress.waveCycleDuration(40, 40),
        const Duration(seconds: 1),
      );
      expect(
        M3WavyLinearProgress.waveCycleDuration(40, 10000),
        const Duration(milliseconds: 50),
      );
      expect(M3WavyLinearProgress.waveCycleDuration(40, 0), isNull);
    });
  });

  group('LinearWavyProgressGeometry — LinearProgressDrawingCache', () {
    LinearWavyProgressGeometry at(double p) =>
        LinearWavyProgressGeometry.compute(width: 200, height: 10, progress: p);

    test('ноль: активной части нет, трек во всю ширину', () {
      final LinearWavyProgressGeometry g = at(0);
      expect(g.capWidth, 2);
      expect(g.hasActiveIndicator, isFalse);
      expect(g.trackStart, 2);
      expect(g.trackEnd, 198);
      expect(g.stopIndicatorSize, 4);
      expect(g.stopIndicatorX, 196);
    });

    test(
      'середина: голова p·width, зазор 4dp, трек после head + gap + 2·cap',
      () {
        final LinearWavyProgressGeometry g = at(0.5);
        expect(g.activeStart, 2);
        expect(g.activeEnd, 100);
        expect(g.trackGap, 4);
        expect(g.trackStart, 100 + 4 + 4);
      },
    );

    test('у начала зазор = min(head − cap, gap)', () {
      expect(at(0.005).trackGap, 0); // голова 1dp < cap
      expect(at(0.01).trackGap, 0); // голова ровно на cap
      expect(at(0.01).trackStart, 2 + 0 + 4);
      expect(at(0.015).trackGap, closeTo(1, 1e-9));
      expect(at(0.015).trackStart, closeTo(3 + 1 + 4, 1e-9));
    });

    test('голова зажата в [cap, width − cap]', () {
      expect(at(0.001).activeEnd, 2);
      expect(at(1).activeEnd, 198);
      expect(at(1).trackStart, isNull);
    });

    test('stop indicator уменьшается, когда голова его догоняет', () {
      // progressX = width·p + cap; индикатор начинается с width − 4.
      expect(at(0.96).stopIndicatorSize, 4); // 194 < 196
      expect(at(0.98).stopIndicatorSize, closeTo(2, 1e-9));
      expect(at(0.98).stopIndicatorX, closeTo(198, 1e-9));
      expect(at(1).stopIndicatorSize, 0);
    });
  });

  group('M3WavyLinearProgress', () {
    Widget progress(
      double value, {
      bool disableAnimations = false,
      bool tickerEnabled = true,
      double? waveSpeed,
    }) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickerEnabled,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: M3WavyLinearProgress(
                  value: value,
                  waveSpeed: waveSpeed,
                  semanticsLabel: 'Прогресс пары',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    WavyLinearProgressPainter painter(WidgetTester tester) =>
        _painter(tester, find.byType(M3WavyLinearProgress));

    testWidgets('высота 10dp, семантика progress bar', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(progress(0.66));
      expect(
        tester.getSize(find.byType(M3WavyLinearProgress)),
        const Size(200, 10),
      );
      final SemanticsData data = tester
          .getSemantics(find.byType(M3WavyLinearProgress))
          .getSemanticsData();
      expect(data.role, SemanticsRole.progressBar);
      expect(data.label, 'Прогресс пары');
      expect(data.value, '66');
      semantics.dispose();
    });

    testWidgets('смена значения анимируется 500 мс линейно', (tester) async {
      await tester.pumpWidget(progress(0.2));
      await tester.pumpWidget(progress(0.6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(painter(tester).progress.value, closeTo(0.4, 1e-6));
      await tester.pump(const Duration(milliseconds: 250));
      expect(painter(tester).progress.value, 0.6);
    });

    testWidgets('волна бежит со скоростью длины волны в секунду', (
      tester,
    ) async {
      await tester.pumpWidget(progress(0.5));
      await tester.pump();
      final double start = painter(tester).waveOffset.value;
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        (painter(tester).waveOffset.value - start) % 1,
        closeTo(0.25, 1e-6),
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('без амплитуды и вне экрана тикер волны не крутится', (
      tester,
    ) async {
      await tester.pumpWidget(progress(0.05));
      await tester.pump();
      expect(painter(tester).amplitude.value, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(progress(0.5, tickerEnabled: false));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('амплитуда нарастает при p > 0.1 и гаснет при p ≥ 0.95', (
      tester,
    ) async {
      await tester.pumpWidget(progress(0.05));
      await tester.pumpWidget(progress(0.5));
      final List<double> rising = [];
      for (int i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        rising.add(painter(tester).amplitude.value);
      }
      expect(rising.any((a) => a > 0 && a < 1), isTrue);
      expect(rising.last, 1);
      for (int i = 1; i < rising.length; i++) {
        expect(rising[i], greaterThanOrEqualTo(rising[i - 1]));
      }

      await tester.pumpWidget(progress(0.97));
      final List<double> falling = [];
      for (int i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        falling.add(painter(tester).amplitude.value);
      }
      expect(falling.any((a) => a > 0 && a < 1), isTrue);
      expect(falling.last, 0);
      for (int i = 1; i < falling.length; i++) {
        expect(falling[i], lessThanOrEqualTo(falling[i - 1]));
      }
      // Волна погасла — покадровой перерисовки больше нет.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'уменьшение движения: значение и амплитуда сразу, волна стоит',
      (tester) async {
        await tester.pumpWidget(progress(0.05, disableAnimations: true));
        await tester.pumpWidget(progress(0.5, disableAnimations: true));
        await tester.pump();
        expect(painter(tester).progress.value, 0.5);
        expect(painter(tester).amplitude.value, 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets('без трека и в RTL рисуется без ошибок', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 120,
                child: M3WavyLinearProgress(value: 0.4, showTrack: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final WavyLinearProgressPainter p = painter(tester);
      expect(p.trackColor, isNull);
      expect(p.textDirection, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  });
}
