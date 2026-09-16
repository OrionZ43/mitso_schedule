import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/theme/compose_spring.dart';
import 'package:mitso_schedule/widgets/m3_loading_indicator.dart';
import 'package:mitso_schedule/widgets/m3_pull_to_refresh.dart';

/// Список с pull-to-refresh; [onRefresh] и [isRefreshing] управляются из
/// теста.
Widget _list({
  required Future<void> Function() onRefresh,
  bool? isRefreshing,
  double edgeOffset = 0,
  ScrollController? controller,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: M3PullToRefresh(
          onRefresh: onRefresh,
          isRefreshing: isRefreshing,
          edgeOffset: edgeOffset,
          child: ListView.builder(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 30,
            itemBuilder: (_, i) =>
                SizedBox(height: 64, child: Text('Строка $i')),
          ),
        ),
      ),
    ),
  );
}

final Finder _indicator = find.byType(M3LoadingIndicator);

/// Начинает жест. Прокрутка — единственный участник арены, поэтому
/// побеждает сразу при касании, и весь путь пальца идёт в прокрутку.
Future<TestGesture> _startDrag(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.text('Строка 1')),
  );
  await tester.pump();
  return gesture;
}

/// Ведёт палец на [distance] шагами по 10dp (вниз — положительное).
Future<void> _move(
  WidgetTester tester,
  TestGesture gesture,
  double distance,
) async {
  const double step = 10;
  double moved = 0;
  while ((distance - moved).abs() > 1e-9) {
    final double delta = (distance - moved).abs() < step
        ? distance - moved
        : step * distance.sign;
    await gesture.moveBy(Offset(0, delta));
    moved += delta;
    await tester.pump();
  }
}

/// Тянет список вниз от верхней кромки на [distance] (после slop).
Future<TestGesture> _pullDown(WidgetTester tester, double distance) async {
  final TestGesture gesture = await _startDrag(tester);
  await _move(tester, gesture, distance);
  return gesture;
}

/// `distanceFraction` по положению индикатора: центр бокса 48dp стоит на
/// `fraction × 80 − 48 + 24` от кромки. Центр не зависит от поворота.
double _fraction(WidgetTester tester, {double edgeOffset = 0}) {
  final double top = tester.getTopLeft(find.byType(M3PullToRefresh)).dy;
  final double center = tester.getCenter(_indicator.first).dy;
  return (center - top - edgeOffset + 24) / 80;
}

M3LoadingIndicator _indicatorWidget(WidgetTester tester) =>
    tester.widget<M3LoadingIndicator>(_indicator.first);

/// Прокручивает кадры и проверяет, что индикатор уходит монотонно: не прыгает
/// вниз и не появляется снова после исчезновения.
Future<void> _expectSettlesAway(WidgetTester tester) async {
  double? lastCenter;
  bool vanished = false;

  for (int frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 16));

    if (_indicator.evaluate().isEmpty) {
      vanished = true;
      continue;
    }
    expect(
      vanished,
      isFalse,
      reason: 'индикатор появился снова на кадре $frame',
    );

    final double center = tester.getCenter(_indicator.first).dy;
    if (lastCenter != null) {
      expect(
        center,
        lessThanOrEqualTo(lastCenter + 0.5),
        reason:
            'индикатор прыгнул вниз на кадре $frame: $lastCenter -> $center',
      );
    }
    lastCenter = center;
  }

  expect(_indicator, findsNothing, reason: 'индикатор остался на экране');
}

void main() {
  group('константы PullToRefresh.kt', () {
    test('порог, множитель, размер индикатора, пружина', () {
      expect(M3PullToRefresh.positionalThreshold, 80);
      expect(M3PullToRefresh.indicatorMaxDistance, 80);
      expect(M3PullToRefresh.dragMultiplier, 0.5);
      expect(M3PullToRefresh.indicatorSize, 48);
      expect(M3PullToRefresh.positionSpringDampingRatio, 1);
      expect(M3PullToRefresh.positionSpringStiffness, 1500);
      expect(ComposeSpringSimulation.defaultDisplacementThreshold, 0.01);
    });

    test('calculateVerticalOffset: линейно до порога, упруго до 2×', () {
      expect(M3PullToRefresh.calculateVerticalOffset(40), 40);
      expect(M3PullToRefresh.calculateVerticalOffset(80), 80);
      // t = 0.5: 80 × (1 + 0.5 − 0.25 / 4).
      expect(M3PullToRefresh.calculateVerticalOffset(120), 115);
      // t = 2: предел — два порога.
      expect(M3PullToRefresh.calculateVerticalOffset(240), 160);
      expect(M3PullToRefresh.calculateVerticalOffset(1000), 160);
    });

    test('оценка длительности пружины spring() как в Compose', () {
      // Критическое демпфирование, порог 0.01: от порога до скрытия 171 мс.
      expect(
        ComposeSpringSimulation.estimateDuration(
          dampingRatio: 1,
          stiffness: 1500,
          start: 1,
          end: 0,
        ),
        const Duration(milliseconds: 171),
      );
      final ComposeSpringSimulation spring = ComposeSpringSimulation(
        dampingRatio: 1,
        stiffness: 1500,
        start: 1,
        end: 0,
      );
      // До конца оценки пружина ещё у порога 0.01, в конце — ровно в цели.
      expect(spring.isDone(0.170), isFalse);
      expect(spring.x(0.170), closeTo(0.01, 0.001));
      expect(spring.isDone(0.171), isTrue);
      expect(spring.x(0.171), 0);
    });
  });

  testWidgets('протяжка: палец × 0.5, определённый индикатор', (tester) async {
    await tester.pumpWidget(_list(onRefresh: () async {}));
    expect(_indicator, findsNothing);

    final TestGesture gesture = await _pullDown(tester, 100);
    expect(_indicator, findsOneWidget);
    expect(_indicatorWidget(tester).progress, closeTo(50 / 80, 1e-9));
    expect(_indicatorWidget(tester).contained, isTrue);
    expect(_fraction(tester), closeTo(50 / 80, 1e-6));

    await gesture.up();
    await tester.pump();
    await _expectSettlesAway(tester);
  });

  testWidgets('за порогом: упругое смещение и поворот −(p − 1)·180°', (
    tester,
  ) async {
    await tester.pumpWidget(_list(onRefresh: () async {}));
    // Палец 240 → протяжка 120 → смещение 115 → доля 1.4375.
    final TestGesture gesture = await _pullDown(tester, 240);
    expect(_fraction(tester), closeTo(115 / 80, 1e-6));
    expect(_indicatorWidget(tester).progress, closeTo(115 / 80, 1e-9));

    final Transform rotation = tester.widget<Transform>(
      find.ancestor(of: _indicator, matching: find.byType(Transform)).first,
    );
    // Матрица поворота на −0.4375π: cos в [0][0].
    expect(
      rotation.transform.storage[0],
      closeTo(math.cos(-(115 / 80 - 1) * math.pi), 1e-9),
    );
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('обновление — только если протяжка строго больше порога', (
    tester,
  ) async {
    int refreshes = 0;
    await tester.pumpWidget(_list(onRefresh: () async => refreshes++));

    // Палец 160 → протяжка ровно 80: не больше порога.
    TestGesture gesture = await _pullDown(tester, 160);
    await gesture.up();
    await tester.pump();
    expect(refreshes, 0);
    await _expectSettlesAway(tester);

    gesture = await _pullDown(tester, 162);
    await gesture.up();
    await tester.pump();
    expect(refreshes, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('вернуть палец назад за порог — обновление отменяется', (
    tester,
  ) async {
    int refreshes = 0;
    await tester.pumpWidget(_list(onRefresh: () async => refreshes++));
    final TestGesture gesture = await _pullDown(tester, 200);
    await _move(tester, gesture, -60);
    expect(_fraction(tester), closeTo(70 / 80, 1e-6));
    await gesture.up();
    await tester.pump();
    expect(refreshes, 0);
    await _expectSettlesAway(tester);
  });

  testWidgets('движение вверх сначала сворачивает протяжку, потом список', (
    tester,
  ) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _list(onRefresh: () async {}, controller: controller),
    );
    final TestGesture gesture = await _pullDown(tester, 100);
    await _move(tester, gesture, -40);
    // onPreScroll: протяжка 100 → 60, список не сдвинулся.
    expect(controller.offset, 0);
    expect(_fraction(tester), closeTo(30 / 80, 1e-6));

    await _move(tester, gesture, -100);
    // Остаток 40 достаётся списку.
    expect(controller.offset, closeTo(40, 1e-6));
    expect(_indicator, findsNothing);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('протяжка за порог: к порогу, неопределённый индикатор, уход', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Completer<void> refresh = Completer<void>();
    int refreshes = 0;
    await tester.pumpWidget(
      _list(
        onRefresh: () {
          refreshes++;
          return refresh.future;
        },
      ),
    );

    final TestGesture gesture = await _pullDown(tester, 240);
    expect(
      tester.getSemantics(_indicator.first).getSemanticsData().role,
      SemanticsRole.progressBar,
    );
    await gesture.up();
    await tester.pump();
    expect(refreshes, 1);

    // Пружина к порогу и кросс-фейд на неопределённый индикатор.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_indicator, findsOneWidget);
    expect(_indicatorWidget(tester).progress, isNull);
    expect(_fraction(tester), closeTo(1, 1e-9));
    final SemanticsData data = tester
        .getSemantics(_indicator)
        .getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);
    expect(data.label, 'Обновление расписания');

    // Во время обновления протяжка не принимается.
    final TestGesture again = await _pullDown(tester, 200);
    expect(_fraction(tester), closeTo(1, 1e-9));
    await again.up();
    await tester.pump();
    expect(refreshes, 1);

    refresh.complete();
    await tester.pump();
    await _expectSettlesAway(tester);
    semantics.dispose();
  });

  testWidgets('isRefreshing снаружи: индикатор выезжает и уходит', (
    tester,
  ) async {
    int refreshes = 0;
    Future<void> onRefresh() async => refreshes++;
    await tester.pumpWidget(_list(onRefresh: onRefresh, isRefreshing: false));
    expect(_indicator, findsNothing);

    await tester.pumpWidget(_list(onRefresh: onRefresh, isRefreshing: true));
    await tester.pump();
    expect(_indicator, findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_fraction(tester), closeTo(1, 1e-9));
    expect(_indicatorWidget(tester).progress, isNull);
    expect(refreshes, 0, reason: 'кнопка вызывает обновление сама');

    await tester.pumpWidget(_list(onRefresh: onRefresh, isRefreshing: false));
    await tester.pump();
    await _expectSettlesAway(tester);
  });

  testWidgets('isRefreshing: true с самого начала — сразу на пороге', (
    tester,
  ) async {
    await tester.pumpWidget(_list(onRefresh: () async {}, isRefreshing: true));
    expect(_fraction(tester), closeTo(1, 1e-9));
    expect(_indicatorWidget(tester).progress, isNull);
  });

  testWidgets('edgeOffset: индикатор выезжает из-под кромки', (tester) async {
    await tester.pumpWidget(
      _list(onRefresh: () async {}, isRefreshing: true, edgeOffset: 56),
    );
    expect(_fraction(tester, edgeOffset: 56), closeTo(1, 1e-9));
    final RenderClipRect clip = tester.renderObject<RenderClipRect>(
      find.ancestor(of: _indicator, matching: find.byType(ClipRect)).first,
    );
    expect(
      clip.localToGlobal(Offset.zero).dy -
          tester.getTopLeft(find.byType(M3PullToRefresh)).dy,
      56,
    );
  });

  testWidgets('короткая протяжка: индикатор плавно уходит и не возвращается', (
    tester,
  ) async {
    int refreshes = 0;
    await tester.pumpWidget(_list(onRefresh: () async => refreshes++));

    final TestGesture gesture = await _pullDown(tester, 60);
    expect(_indicator, findsOneWidget);

    await gesture.up();
    await tester.pump();
    await _expectSettlesAway(tester);
    expect(refreshes, 0, reason: 'до порога обновление запускаться не должно');
  });

  testWidgets('повторная протяжка во время отката не ломает состояние', (
    tester,
  ) async {
    await tester.pumpWidget(_list(onRefresh: () async {}));

    final TestGesture first = await _pullDown(tester, 60);
    await first.up();
    // Откат только начался.
    await tester.pump(const Duration(milliseconds: 48));

    // Пока идёт откат, `state.isAnimating`: Compose протяжку не принимает.
    final TestGesture second = await _startDrag(tester);
    await _move(tester, second, 20);
    final double during = _fraction(tester);
    await _move(tester, second, 20);
    expect(_fraction(tester), lessThanOrEqualTo(during));

    // Откат закончился, палец продолжает тянуть — индикатор снова едет за ним.
    await tester.pump(const Duration(milliseconds: 200));
    await _move(tester, second, 40);
    expect(_indicator, findsOneWidget);
    expect(_fraction(tester), closeTo(20 / 80, 1e-6));

    // Пока палец держит протяжку, завершение старого отката не должно прятать
    // индикатор. Проверяем каждый кадр: обнуление из устаревшего колбэка
    // проявляется только на кадре после его завершения.
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _indicator,
        findsOneWidget,
        reason: 'индикатор пропал на кадре $frame, хотя палец держит протяжку',
      );
      expect(_fraction(tester), closeTo(20 / 80, 1e-6));
    }

    await second.up();
    await tester.pump();
    await _expectSettlesAway(tester);
  });

  testWidgets('уменьшение движения: уход без анимации', (tester) async {
    await tester.pumpWidget(
      _list(onRefresh: () async {}, disableAnimations: true),
    );
    final TestGesture gesture = await _pullDown(tester, 100);
    expect(_indicator, findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(_indicator, findsNothing);
  });
}
