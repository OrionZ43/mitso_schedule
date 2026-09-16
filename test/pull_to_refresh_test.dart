import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_loading_indicator.dart';
import 'package:mitso_schedule/widgets/m3_pull_to_refresh.dart';

/// Список с pull-to-refresh; [onRefresh] управляется из теста.
Future<void> _pumpList(
  WidgetTester tester, {
  required Future<void> Function() onRefresh,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: M3PullToRefresh(
          onRefresh: onRefresh,
          child: ListView.builder(
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

/// Тянет список вниз от верхней кромки, не отпуская палец.
Future<TestGesture> _pullDown(WidgetTester tester, double distance) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.text('Строка 1')),
  );
  const double step = 20;
  for (double moved = 0; moved < distance; moved += step) {
    await gesture.moveBy(const Offset(0, step));
    await tester.pump();
  }
  return gesture;
}

/// Прокручивает кадры после отпускания и проверяет, что индикатор уходит
/// монотонно: не прыгает обратно вниз и не появляется снова после исчезновения.
Future<void> _expectSettlesAway(WidgetTester tester) async {
  double? lastTop;
  bool vanished = false;

  for (int frame = 0; frame < 90; frame++) {
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

    final double top = tester.getTopLeft(_indicator).dy;
    if (lastTop != null) {
      expect(
        top,
        lessThanOrEqualTo(lastTop + 0.5),
        reason: 'индикатор прыгнул вниз на кадре $frame: $lastTop -> $top',
      );
    }
    lastTop = top;
  }

  expect(_indicator, findsNothing, reason: 'индикатор остался на экране');
}

void main() {
  testWidgets('короткая протяжка: индикатор плавно уходит и не возвращается', (
    tester,
  ) async {
    int refreshes = 0;
    await _pumpList(tester, onRefresh: () async => refreshes++);

    final TestGesture gesture = await _pullDown(tester, 60);
    expect(_indicator, findsOneWidget);

    await gesture.up();
    await tester.pump();
    await _expectSettlesAway(tester);
    expect(refreshes, 0, reason: 'до порога обновление запускаться не должно');
  });

  testWidgets('протяжка за порог: обновление, затем индикатор уходит', (
    tester,
  ) async {
    final Completer<void> refresh = Completer<void>();
    int refreshes = 0;
    await _pumpList(
      tester,
      onRefresh: () {
        refreshes++;
        return refresh.future;
      },
    );

    final TestGesture gesture = await _pullDown(tester, 200);
    await gesture.up();
    await tester.pump();

    expect(refreshes, 1);
    // Пока обновление идёт, индикатор держится на месте.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_indicator, findsOneWidget);

    refresh.complete();
    await tester.pump();
    await _expectSettlesAway(tester);
  });

  testWidgets('повторная протяжка во время отката не ломает состояние', (
    tester,
  ) async {
    await _pumpList(tester, onRefresh: () async {});

    final TestGesture first = await _pullDown(tester, 60);
    await first.up();
    // Откат только начался.
    await tester.pump(const Duration(milliseconds: 48));

    final TestGesture second = await _pullDown(tester, 40);
    // Пока палец держит протяжку, старый откат не должен прятать индикатор.
    // Проверяем каждый кадр: обнуление из устаревшего колбэка отката
    // проявляется только на кадре после его завершения.
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _indicator,
        findsOneWidget,
        reason: 'индикатор пропал на кадре $frame, хотя палец держит протяжку',
      );
    }

    await second.up();
    await tester.pump();
    await _expectSettlesAway(tester);
  });
}
