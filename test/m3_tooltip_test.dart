import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mitso_schedule/widgets/m3_tooltip.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.green);

const String _message = 'Сменить группу';

Future<void> _pump(
  WidgetTester tester, {
  bool preferBelow = false,
  Alignment alignment = Alignment.center,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3PlainTooltip(
                message: _message,
                preferBelow: preferBelow,
                anchorPadding: M3PlainTooltip.iconButtonPadding,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Symbols.group),
                ),
              ),
              M3PlainTooltip(
                message: 'Назад',
                anchorPadding: M3PlainTooltip.iconButtonPadding,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Symbols.arrow_back),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder _box(String message) => find
    .ancestor(of: find.text(message), matching: find.byType(DecoratedBox))
    .first;

/// Долгое нажатие, палец отпущен; пружины появления успокоились.
Future<void> _longPress(WidgetTester tester, IconData icon) async {
  await tester.longPress(find.byIcon(icon));
  await _frames(tester, 30);
}

void main() {
  testWidgets('вид по токенам plain tooltip', (tester) async {
    await _pump(tester);
    await _longPress(tester, Symbols.group);
    expect(find.text(_message), findsOneWidget);

    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(_box(_message)).decoration as BoxDecoration;
    expect(decoration.color, _scheme.inverseSurface);
    expect(decoration.borderRadius, BorderRadius.circular(4));

    final TextStyle style = tester.widget<Text>(find.text(_message)).style!;
    final TextStyle bodySmall = Theme.of(
      tester.element(find.text(_message)),
    ).textTheme.bodySmall!;
    expect(style.color, _scheme.onInverseSurface);
    expect(style.fontSize, bodySmall.fontSize);

    final Size size = tester.getSize(_box(_message));
    expect(size.height, greaterThanOrEqualTo(24));
    expect(
      tester.getTopLeft(find.text(_message)).dx -
          tester.getTopLeft(_box(_message)).dx,
      8,
    );
    await _frames(tester, 150);
  });

  testWidgets('над кнопкой с зазором 4dp от контейнера 40dp', (tester) async {
    await _pump(tester);
    await _longPress(tester, Symbols.group);

    final Rect button = tester.getRect(find.byType(IconButton).first);
    final Rect visual = button.deflate(4);
    final Rect tooltip = tester.getRect(_box(_message));
    expect(visual.height, 40);
    expect(tooltip.bottom, moreOrLessEquals(visual.top - 4));
    expect(tooltip.center.dx, moreOrLessEquals(visual.center.dx));
    await _frames(tester, 150);
  });

  testWidgets('preferBelow: под кнопкой с тем же зазором', (tester) async {
    await _pump(tester, preferBelow: true);
    await _longPress(tester, Symbols.group);

    final Rect visual = tester
        .getRect(find.byType(IconButton).first)
        .deflate(4);
    final Rect tooltip = tester.getRect(_box(_message));
    expect(tooltip.top, moreOrLessEquals(visual.bottom + 4));
    await _frames(tester, 150);
  });

  testWidgets('у верхнего края уходит вниз, у левого прижимается к краю', (
    tester,
  ) async {
    await _pump(tester, alignment: Alignment.topLeft);
    await _longPress(tester, Symbols.group);
    final Rect visual = tester
        .getRect(find.byType(IconButton).first)
        .deflate(4);
    final Rect tooltip = tester.getRect(_box(_message));
    expect(tooltip.top, moreOrLessEquals(visual.bottom + 4));
    expect(tooltip.left, 0);
    await _frames(tester, 150);
  });

  testWidgets('появление: масштаб 0.8 → 1 и прозрачность', (tester) async {
    await _pump(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Symbols.group)),
    );
    await tester.pump(kLongPressTimeout);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final Opacity opacity = tester.widget<Opacity>(
      find.ancestor(of: _box(_message), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, greaterThan(0));
    expect(opacity.opacity, lessThan(1));
    final double width = tester.getSize(_box(_message)).width;
    final double scaled = tester.getRect(_box(_message)).width;
    expect(scaled, lessThan(width));
    expect(scaled, greaterThan(width * 0.8));

    await _frames(tester, 30);
    expect(tester.getRect(_box(_message)).width, moreOrLessEquals(width));
    await gesture.up();
    await _frames(tester, 150);
  });

  testWidgets('скрывается через 1,5 с после того, как палец отпущен', (
    tester,
  ) async {
    await _pump(tester);
    await tester.longPress(find.byIcon(Symbols.group));
    await tester.pump();
    expect(find.text(_message), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text(_message), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    // Началось скрытие; оверлей уходит, когда пружины закончились.
    await _frames(tester, 40);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('одновременно видна одна подсказка', (tester) async {
    await _pump(tester);
    await _longPress(tester, Symbols.group);
    expect(find.text(_message), findsOneWidget);

    await _longPress(tester, Symbols.arrow_back);
    await _frames(tester, 40);
    expect(find.text('Назад'), findsOneWidget);
    expect(find.text(_message), findsNothing);
    await _frames(tester, 150);
  });

  testWidgets('долгое нажатие не нажимает кнопку', (tester) async {
    int presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: M3PlainTooltip(
              message: _message,
              child: IconButton(
                onPressed: () => presses++,
                icon: const Icon(Symbols.group),
              ),
            ),
          ),
        ),
      ),
    );
    await _longPress(tester, Symbols.group);
    expect(presses, 0);
    await tester.tap(find.byIcon(Symbols.group));
    await tester.pump();
    expect(presses, 1);
    await _frames(tester, 150);
  });

  testWidgets('семантика: текст подсказки у кнопки', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(find.byType(IconButton).first),
      isSemantics(tooltip: _message, isButton: true),
    );
    handle.dispose();
  });
}
