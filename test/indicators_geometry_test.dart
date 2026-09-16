import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:mitso_schedule/widgets/m3_loading_indicator.dart';
import 'package:mitso_schedule/widgets/m3_wavy_linear_progress.dart';

/// Движение на момент [ms] миллисекунд, прогнанное покадрово, как в приложении.
LoadingIndicatorMotion _motionAt(int ms, {int frameMs = 16}) {
  final LoadingIndicatorMotion motion = LoadingIndicatorMotion();
  for (int t = 0; t < ms; t += frameMs) {
    motion.update(Duration(milliseconds: t));
  }
  motion.update(Duration(milliseconds: ms));
  return motion;
}

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

void main() {
  group('LoadingIndicatorShapes', () {
    test('семь форм и семь морфов, как INDETERMINATE_SHAPES в MDC', () {
      expect(LoadingIndicatorShapes.shapes, hasLength(7));
      expect(LoadingIndicatorShapes.morphs, hasLength(7));
    });

    test('каждая форма нормирована по max bounds в квадрат [-1, 1]', () {
      for (final RoundedPolygon shape in LoadingIndicatorShapes.shapes) {
        final List<double> bounds = shape.calculateMaxBounds();
        expect(bounds[0], closeTo(-1, 1e-3));
        expect(bounds[1], closeTo(-1, 1e-3));
        expect(bounds[2], closeTo(1, 1e-3));
        expect(bounds[3], closeTo(1, 1e-3));
      }
    });

    test('морфы сцеплены: конец одного совпадает с началом следующего', () {
      // Сравниваем геометрию, а не Path.getBounds(): тот берёт границы по
      // контрольным точкам, а морф режет одну и ту же форму на кубики
      // по-разному.
      final List<Morph> morphs = LoadingIndicatorShapes.morphs;
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

  group(
    'LoadingIndicatorMotion — формулы LoadingIndicatorAnimatorDelegate',
    () {
      test('константы совпадают с MDC', () {
        expect(
          LoadingIndicatorMotion.durationPerShape,
          const Duration(milliseconds: 650),
        );
        expect(LoadingIndicatorMotion.constantRotationPerShape, 50);
        expect(LoadingIndicatorMotion.extraRotationPerShape, 90);
        expect(LoadingIndicatorMotion.springStiffness, 200);
        expect(LoadingIndicatorMotion.springDampingRatio, 0.6);
        expect(M3LoadingIndicator.containerSize, 48);
        expect(M3LoadingIndicator.indicatorSize, 34);
      });

      test('старт: ни поворота, ни морфа', () {
        final LoadingIndicatorMotion motion = LoadingIndicatorMotion()
          ..update(Duration.zero);
        expect(motion.morphFactor, 0);
        expect(motion.rotationDegrees, 0);
      });

      test('внутри первого шага поворот = 50° · время + 90° · morphFactor', () {
        final LoadingIndicatorMotion motion = _motionAt(325);
        expect(
          motion.rotationDegrees,
          closeTo(50 * 0.5 + 90 * motion.morphFactor, 1e-6),
        );
      });

      test(
        'после повтора цель сдвигается: база даёт 140° за пройденный шаг',
        () {
          final LoadingIndicatorMotion motion = _motionAt(650);
          // На самом повторе timeFactorPerShape = 0, morphFactorBase = 1.
          expect(
            motion.rotationDegrees,
            closeTo((140 + 90 * (motion.morphFactor - 1)) % 360, 1e-6),
          );
        },
      );

      test('пружина недодемпфирована: форма пролетает цель', () {
        final LoadingIndicatorMotion motion = LoadingIndicatorMotion();
        double peak = 0;
        for (int t = 0; t < 650; t += 4) {
          motion.update(Duration(milliseconds: t));
          peak = math.max(peak, motion.morphFactor);
        }
        expect(peak, greaterThan(1.0));
      });

      test('поворот непрерывен, в том числе на стыках шагов', () {
        final LoadingIndicatorMotion motion = LoadingIndicatorMotion();
        double? previous;
        for (int t = 0; t <= 5000; t += 16) {
          motion.update(Duration(milliseconds: t));
          final double current = motion.rotationDegrees;
          if (previous != null) {
            double delta = (current - previous) % 360;
            if (delta > 180) delta -= 360;
            expect(delta.abs(), lessThan(40), reason: 'рывок на $t мс');
          }
          previous = current;
        }
      });

      test('на длинной дистанции morphFactor не уплывает от цели', () {
        final LoadingIndicatorMotion motion = _motionAt(650 * 20 + 640);
        // За 640 мс шага пружина почти успокоилась у цели 21.
        expect(motion.morphFactor, closeTo(21, 0.05));
        expect(motion.rotationDegrees, inInclusiveRange(0, 360));
      });
    },
  );

  group('M3LoadingIndicator', () {
    testWidgets('48×48 по умолчанию и анимируется без ошибок', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: M3LoadingIndicator())),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(M3LoadingIndicator)),
        const Size.square(M3LoadingIndicator.containerSize),
      );

      CustomPainter painter() => tester
          .renderObject<RenderCustomPaint>(
            find.descendant(
              of: find.byType(M3LoadingIndicator),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;

      // Прокручиваем кадры через несколько шагов морфинга и проверяем, что
      // кадры действительно меняются: ленивый тикер когда-то молча оставлял
      // индикатор неподвижным.
      CustomPainter previous = painter();
      int changedFrames = 0;
      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final CustomPainter current = painter();
        if (current.shouldRepaint(previous)) changedFrames++;
        previous = current;
      }
      expect(
        changedFrames,
        greaterThan(100),
        reason: 'индикатор не анимируется',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uncontained масштабируется под заданный размер', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: M3LoadingIndicator(contained: false, size: 24)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getSize(find.byType(M3LoadingIndicator)),
        const Size.square(24),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('M3WavyLinearProgress — токены и DeterminateDrawable из MDC', () {
    test('геометрия по токенам', () {
      expect(M3WavyLinearProgress.thickness, 4);
      expect(M3WavyLinearProgress.trackGap, 4);
      expect(M3WavyLinearProgress.stopIndicatorSize, 4);
      expect(M3WavyLinearProgress.amplitude, 3);
      expect(M3WavyLinearProgress.wavelength, 40);
      expect(M3WavyLinearProgress.height, 10);
    });

    test('полная амплитуда только в диапазоне 0.1..0.9', () {
      expect(M3WavyLinearProgress.hasFullAmplitude(0.0), isFalse);
      expect(M3WavyLinearProgress.hasFullAmplitude(0.05), isFalse);
      expect(M3WavyLinearProgress.hasFullAmplitude(0.1), isTrue);
      expect(M3WavyLinearProgress.hasFullAmplitude(0.66), isTrue);
      expect(M3WavyLinearProgress.hasFullAmplitude(0.9), isTrue);
      expect(M3WavyLinearProgress.hasFullAmplitude(0.95), isFalse);
      expect(M3WavyLinearProgress.hasFullAmplitude(1.0), isFalse);
    });

    test('зазор сходит на нет у самого начала', () {
      expect(M3WavyLinearProgress.displayedGap(0), 0);
      expect(M3WavyLinearProgress.displayedGap(0.005), closeTo(2, 1e-9));
      expect(M3WavyLinearProgress.displayedGap(0.5), 4);
    });

    Widget progress(double value) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: M3WavyLinearProgress(value: value),
          ),
        ),
      ),
    );

    testWidgets('неподвижная волна не перерисовывается покадрово', (
      tester,
    ) async {
      await tester.pumpWidget(progress(0.66));
      await tester.pump();
      expect(
        tester.getSize(find.byType(M3WavyLinearProgress)).height,
        M3WavyLinearProgress.height,
      );
      // waveSpeed = 0, как по умолчанию в MDC: новых кадров не заказывается.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('выход за 0.9 гасит волну анимацией за 500 мс', (tester) async {
      CustomPainter painter() => tester
          .renderObject<RenderCustomPaint>(
            find.descendant(
              of: find.byType(M3WavyLinearProgress),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;

      await tester.pumpWidget(progress(0.66));
      await tester.pump();

      await tester.pumpWidget(progress(0.95));
      await tester.pump(const Duration(milliseconds: 250));
      final CustomPainter midway = painter();
      await tester.pump(const Duration(milliseconds: 300));
      final CustomPainter settled = painter();

      // На середине амплитуда ещё гаснет, к концу — ноль и дальше не меняется.
      expect(settled.shouldRepaint(midway), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter().shouldRepaint(settled), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
