import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_loading_indicator.dart';
import 'package:mitso_schedule/widgets/m3_loading_shapes.dart';
import 'package:mitso_schedule/widgets/m3_wavy_linear_progress.dart';

void main() {
  group('M3LoadingShapes', () {
    test('последовательность из семи форм', () {
      expect(M3LoadingShapes.sequence, hasLength(7));
      expect(M3LoadingShapes.names, hasLength(7));
    });

    test('у всех форм одинаковое число опорных точек', () {
      // Это условие обязательно для морфинга интерполяцией:
      // https://m3.material.io/styles/shape/shape-morph
      for (final List<Offset> shape in M3LoadingShapes.sequence) {
        expect(shape, hasLength(M3LoadingShapes.pointCount));
      }
    });

    test('координаты нормированы в 0..1', () {
      for (final List<Offset> shape in M3LoadingShapes.sequence) {
        for (final Offset point in shape) {
          expect(point.dx, inInclusiveRange(0.0, 1.0));
          expect(point.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('формы действительно различаются между собой', () {
      for (int i = 1; i < M3LoadingShapes.sequence.length; i++) {
        expect(
          M3LoadingShapes.sequence[i],
          isNot(equals(M3LoadingShapes.sequence[i - 1])),
          reason:
              'формы ${M3LoadingShapes.names[i - 1]} и '
              '${M3LoadingShapes.names[i]} совпадают',
        );
      }
    });
  });

  group('M3LoadingIndicator', () {
    test('размеры contained-варианта', () {
      expect(M3LoadingIndicator.containerSize, 48);
      expect(M3LoadingIndicator.containedIndicatorSize, 38);
      expect(M3LoadingIndicator.uncontainedIndicatorSize, 48);
    });

    test('цикл морфинга равен семи шагам по 650 мс', () {
      expect(
        M3LoadingIndicator.morphInterval,
        const Duration(milliseconds: 650),
      );
      expect(
        M3LoadingIndicator.morphDuration,
        const Duration(milliseconds: 4550),
      );
    });

    test('полный оборот — 45 градусов за шаг морфинга', () {
      expect(M3LoadingIndicator.rotationPerMorph, 45);
      // 360 / 45 = 8 шагов по 650 мс.
      expect(
        M3LoadingIndicator.rotationDuration,
        const Duration(milliseconds: 5200),
      );
    });

    testWidgets('занимает заданный размер и анимируется', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: M3LoadingIndicator())),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(M3LoadingIndicator)),
        const Size(
          M3LoadingIndicator.containerSize,
          M3LoadingIndicator.containerSize,
        ),
      );

      // Анимация бесконечная, поэтому дерево не «успокаивается» —
      // просто прокручиваем несколько кадров.
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('M3WavyLinearProgress', () {
    test('геометрия по спеке', () {
      expect(M3WavyLinearProgress.wavelength, 40);
      expect(M3WavyLinearProgress.amplitude, 3);
      expect(M3WavyLinearProgress.thickness, 4);
      expect(M3WavyLinearProgress.trackGap, 4);
      expect(M3WavyLinearProgress.stopIndicatorSize, 4);
    });

    test('амплитуда плавно уходит в ноль на 100%', () {
      expect(M3WavyLinearProgress.amplitudeFor(0.0), 3);
      expect(M3WavyLinearProgress.amplitudeFor(0.66), 3);
      expect(M3WavyLinearProgress.amplitudeFor(0.9), 3);
      expect(M3WavyLinearProgress.amplitudeFor(0.95), closeTo(1.5, 1e-9));
      expect(M3WavyLinearProgress.amplitudeFor(1.0), 0);
    });

    test('значения вне 0..1 приводятся к границам', () {
      expect(M3WavyLinearProgress.amplitudeFor(-1), 3);
      expect(M3WavyLinearProgress.amplitudeFor(2), 0);
    });

    testWidgets('высота фиксирована и равна 14dp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: M3WavyLinearProgress(value: 0.66),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(M3WavyLinearProgress)).height,
        M3WavyLinearProgress.height,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });
}
