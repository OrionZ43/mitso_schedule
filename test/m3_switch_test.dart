import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_switch.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

/// Переключатель с состоянием внутри теста.
Future<void> _pump(
  WidgetTester tester, {
  bool initial = false,
  bool enabled = true,
  M3SwitchIcons icons = M3SwitchIcons.selectedOnly,
  FocusNode? focusNode,
  ValueChanged<bool>? onChanged,
}) async {
  bool value = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => M3Switch(
              value: value,
              icons: icons,
              focusNode: focusNode,
              onChanged: enabled
                  ? (v) {
                      onChanged?.call(v);
                      setState(() => value = v);
                    }
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Прокручивает кадры, пока пружины не успокоятся (без pumpAndSettle).
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

final Finder _handle = find.byKey(M3Switch.handleKey);

double _handleSize(WidgetTester tester) => tester.getSize(_handle).width;

/// Центр ручки относительно левого края переключателя.
double _handleCenterX(WidgetTester tester) =>
    tester.getCenter(_handle).dx - tester.getTopLeft(find.byType(M3Switch)).dx;

Color _handleColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_handle).decoration as BoxDecoration).color!;

ShapeDecoration _track(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(M3Switch.trackKey)).decoration
        as ShapeDecoration;

void main() {
  testWidgets('размер виджета: трек 52×32 в зоне нажатия 52×48', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(M3Switch)), const Size(52, 48));
    expect(
      tester.getSize(find.byKey(M3Switch.trackKey)),
      const Size(M3Switch.trackWidth, M3Switch.trackHeight),
    );
    expect((_track(tester).shape as StadiumBorder).side.width, 2);
  });

  testWidgets('ручка: 16dp выключен, 24dp включён, 24dp с иконкой', (
    tester,
  ) async {
    await _pump(tester);
    expect(_handleSize(tester), 16);
    expect(_handleCenterX(tester), 16);
    expect(find.byType(Icon), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, initial: true);
    expect(_handleSize(tester), 24);
    expect(_handleCenterX(tester), 36);
    expect(find.byType(Icon), findsOneWidget);

    // Иконки в обоих состояниях: выключенная ручка тоже 24dp (with-icon).
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, icons: M3SwitchIcons.both);
    expect(_handleSize(tester), 24);
    expect(_handleCenterX(tester), 16);

    // Без иконок: выключенная 16dp.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, icons: M3SwitchIcons.none);
    expect(_handleSize(tester), 16);
  });

  testWidgets('нажатие мгновенно делает ручку 28dp, центр на месте', (
    tester,
  ) async {
    await _pump(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(M3Switch)),
    );
    // Горизонтальное перетаскивание конкурирует с касанием: onTapDown
    // приходит через kPressTimeout.
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(_handleSize(tester), 28);
    expect(_handleCenterX(tester), 16);
    expect(_handleColor(tester), _scheme.onSurfaceVariant);

    // Отпускание: пружина к 24dp справа.
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final double midSize = _handleSize(tester);
    final double midCenter = _handleCenterX(tester);
    expect(midCenter, greaterThan(16));
    expect(midCenter, lessThan(36));
    expect(midSize, isNot(28));

    await _settle(tester);
    expect(_handleSize(tester), 24);
    expect(_handleCenterX(tester), 36);
  });

  testWidgets('нажатие включённого: 28dp у правого края трека', (tester) async {
    await _pump(tester, initial: true);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(M3Switch)),
    );
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(_handleSize(tester), 28);
    expect(_handleCenterX(tester), 36);
    expect(_handleColor(tester), _scheme.primaryContainer);
    await gesture.cancel();
    await _settle(tester);
    expect(_handleSize(tester), 24);
  });

  testWidgets('быстрое касание: без вспышки 28dp, пружина с перелётом', (
    tester,
  ) async {
    await _pump(tester);
    // Нажатие и отпускание в одном кадре: как в Compose (цели считаются в
    // measure), 28dp не показывается, ручка сразу растёт 16 → 24.
    await tester.tap(find.byType(M3Switch));
    double maxSize = 0;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      final double size = _handleSize(tester);
      if (size > maxSize) maxSize = size;
    }
    await _settle(tester);
    expect(_handleSize(tester), 24);
    // FastSpatial (ratio 0.6) проскакивает цель примерно на 10%.
    expect(maxSize, greaterThan(24.3));
    expect(maxSize, lessThan(28));
  });

  testWidgets('цвета по токенам без интерполяции', (tester) async {
    await _pump(tester);
    expect(_track(tester).color, _scheme.surfaceContainerHighest);
    expect((_track(tester).shape as StadiumBorder).side.color, _scheme.outline);
    expect(_handleColor(tester), _scheme.outline);

    await tester.tap(find.byType(M3Switch));
    await tester.pump();
    // Сразу после переключения, без промежуточных цветов.
    expect(_track(tester).color, _scheme.primary);
    expect(
      (_track(tester).shape as StadiumBorder).side.color,
      Colors.transparent,
    );
    expect(_handleColor(tester), _scheme.onPrimary);
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, _scheme.onPrimaryContainer);
    await _settle(tester);
  });

  testWidgets('недоступный: цвета сведены на surface', (tester) async {
    await _pump(tester, initial: true, enabled: false);
    Color over(Color c, double a) =>
        Color.alphaBlend(c.withValues(alpha: a), _scheme.surface);
    expect(_track(tester).color, over(_scheme.onSurface, 0.12));
    expect(_handleColor(tester), _scheme.surface);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, enabled: false);
    expect(_track(tester).color, over(_scheme.surfaceContainerHighest, 0.12));
    expect(
      (_track(tester).shape as StadiumBorder).side.color,
      over(_scheme.onSurface, 0.12),
    );
    expect(_handleColor(tester), over(_scheme.onSurface, 0.38));

    await tester.tap(find.byType(M3Switch), warnIfMissed: false);
    await tester.pump();
    expect(_handleSize(tester), 16);
  });

  testWidgets('семантика: toggled, нажатие переключает', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, initial: true);
    expect(
      tester.getSemantics(find.byType(M3Switch)),
      isSemantics(
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(M3Switch));
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(M3Switch)),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    await _settle(tester);
    handle.dispose();
  });

  testWidgets('перетаскивание переключает и держит ручку 28dp', (tester) async {
    final List<bool> changes = [];
    await _pump(tester, onChanged: changes.add);
    final Offset start = tester.getCenter(find.byType(M3Switch));
    final TestGesture gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
    }
    expect(_handleSize(tester), 28);
    expect(_handleCenterX(tester), greaterThan(16));
    await gesture.up();
    await tester.pump();
    expect(changes, [true]);
    await _settle(tester);
    expect(_handleSize(tester), 24);
    expect(_handleCenterX(tester), 36);
  });

  testWidgets('короткое перетаскивание возвращает ручку', (tester) async {
    final List<bool> changes = [];
    await _pump(tester, onChanged: changes.add);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(M3Switch)),
    );
    await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(3, 0));
    await tester.pump();
    await gesture.up();
    await _settle(tester);
    expect(changes, isEmpty);
    expect(_handleSize(tester), 16);
    expect(_handleCenterX(tester), 16);
  });

  testWidgets('клавиатура: Space и Enter переключают', (tester) async {
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    final List<bool> changes = [];
    await _pump(tester, focusNode: node, onChanged: changes.add);
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, [true, false]);
    await _settle(tester);
  });
}
