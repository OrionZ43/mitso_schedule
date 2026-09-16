import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/segmented_list.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 400, child: child),
        ),
      ),
    ),
  );
}

/// Прокручивает кадры, пока пружины не успокоятся.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Material _containerOf(WidgetTester tester, Finder item) => tester.widget(
  find.descendant(of: item, matching: find.byType(Material)).first,
);

BorderRadius _radiusOf(WidgetTester tester, Finder item) =>
    (_containerOf(tester, item).shape! as RoundedRectangleBorder).borderRadius
        as BorderRadius;

void main() {
  testWidgets('высоты 56 / 72 / 88 и поля 16 / 12 / 16', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          M3ListItem(
            key: ValueKey('one'),
            leading: Icon(Icons.star, key: ValueKey('icon')),
            headline: Text('Одна строка'),
            trailing: Icon(Icons.chevron_right, key: ValueKey('trailing')),
          ),
          M3ListItem(
            key: ValueKey('two'),
            headline: Text('Две строки'),
            supporting: Text('Пояснение'),
          ),
          M3ListItem(
            key: ValueKey('three'),
            overline: Text('Надстрочник'),
            headline: Text('Три строки'),
            supporting: Text('Пояснение'),
          ),
        ],
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('one'))).height, 56);
    expect(tester.getSize(find.byKey(const ValueKey('two'))).height, 72);
    expect(tester.getSize(find.byKey(const ValueKey('three'))).height, 88);

    final Rect item = tester.getRect(find.byKey(const ValueKey('one')));
    final Rect icon = tester.getRect(find.byKey(const ValueKey('icon')));
    final Rect headline = tester.getRect(find.text('Одна строка'));
    final Rect trailing = tester.getRect(
      find.byKey(const ValueKey('trailing')),
    );
    expect(icon.left - item.left, 16);
    expect(headline.left - icon.right, 12);
    expect(item.right - trailing.right, 16);
    // Однострочный пункт — по центру.
    expect(icon.center.dy, closeTo(item.center.dy, 0.5));

    // Трёхстрочный (88dp) — выше порога 60dp: по верху, поле 10dp.
    final Rect three = tester.getRect(find.byKey(const ValueKey('three')));
    expect(tester.getTopLeft(find.text('Надстрочник')).dy - three.top, 10);
  });

  testWidgets('текст и цвета слотов по ListTokens', (tester) async {
    await _pump(
      tester,
      const M3ListItem(
        overline: Text('O'),
        headline: Text('H'),
        supporting: Text('S'),
        leading: Icon(Icons.star),
      ),
    );
    final ThemeData theme = Theme.of(tester.element(find.text('H')));
    TextStyle styleOf(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style;

    expect(styleOf('H').fontSize, theme.textTheme.bodyLarge!.fontSize);
    expect(styleOf('H').color, _scheme.onSurface);
    expect(styleOf('S').fontSize, theme.textTheme.bodyMedium!.fontSize);
    expect(styleOf('S').color, _scheme.onSurfaceVariant);
    expect(styleOf('O').fontSize, theme.textTheme.labelSmall!.fontSize);
    expect(styleOf('O').color, _scheme.onSurfaceVariant);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.star))).color,
      _scheme.onSurfaceVariant,
    );
    expect(
      _containerOf(tester, find.byType(M3ListItem)).color,
      _scheme.surfaceContainer,
    );
  });

  testWidgets('позиционные формы: 16 снаружи, 4 на стыках, зазор 2', (
    tester,
  ) async {
    await _pump(
      tester,
      SegmentedList(
        children: [
          for (int i = 0; i < 3; i++)
            M3ListItem(headline: Text('Пункт $i'), onTap: () {}),
        ],
      ),
    );

    final Finder items = find.byType(M3ListItem);
    expect(
      _radiusOf(tester, items.at(0)),
      const BorderRadius.vertical(
        top: Radius.circular(16),
        bottom: Radius.circular(4),
      ),
    );
    expect(_radiusOf(tester, items.at(1)), BorderRadius.circular(4));
    expect(
      _radiusOf(tester, items.at(2)),
      const BorderRadius.vertical(
        top: Radius.circular(4),
        bottom: Radius.circular(16),
      ),
    );
    expect(
      tester.getTopLeft(items.at(1)).dy - tester.getBottomLeft(items.at(0)).dy,
      2,
    );

    await _pump(
      tester,
      const SegmentedList(children: [M3ListItem(headline: Text('Один'))]),
    );
    expect(
      _radiusOf(tester, find.byType(M3ListItem)),
      BorderRadius.circular(16),
    );
  });

  testWidgets('обычные виджеты в SegmentedList остаются в контейнере', (
    tester,
  ) async {
    await _pump(
      tester,
      const SegmentedList(
        children: [
          ListTile(title: Text('A')),
          ListTile(title: Text('B')),
        ],
      ),
    );
    final Material first = tester.widget(
      find.ancestor(of: find.text('A'), matching: find.byType(Material)).first,
    );
    expect(first.color, _scheme.surfaceContainer);
    expect(
      (first.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(
        top: Radius.circular(16),
        bottom: Radius.circular(4),
      ),
    );
  });

  testWidgets('нажатие морфит форму до 16dp и возвращает обратно', (
    tester,
  ) async {
    await _pump(
      tester,
      SegmentedList(
        children: [
          for (int i = 0; i < 3; i++)
            M3ListItem(headline: Text('Пункт $i'), onTap: () {}),
        ],
      ),
    );
    final Finder middle = find.byType(M3ListItem).at(1);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(middle),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 16));
    // Пружина FastSpatial с перелётом: радиус идёт через 16dp.
    final double early = _radiusOf(tester, middle).topLeft.x;
    expect(early, greaterThan(4));
    await _settle(tester);
    expect(_radiusOf(tester, middle), BorderRadius.circular(16));

    await gesture.up();
    await _settle(tester);
    expect(_radiusOf(tester, middle), BorderRadius.circular(4));
  });

  testWidgets('выбранный пункт: secondaryContainer и 16dp, флаг selected', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    Widget build(bool selected) => SegmentedList(
      children: [
        M3ListItem(headline: const Text('A'), onTap: () {}),
        M3ListItem(
          headline: const Text('B'),
          leading: const Icon(Icons.check),
          selected: selected,
          onTap: () {},
        ),
        M3ListItem(headline: const Text('C'), onTap: () {}),
      ],
    );

    await _pump(tester, build(false));
    await _pump(tester, build(true));
    final Finder item = find.byType(M3ListItem).at(1);

    // Цвет — пружина DefaultEffects: в середине пути ещё не конечный.
    await tester.pump(const Duration(milliseconds: 16));
    expect(_containerOf(tester, item).color, isNot(_scheme.secondaryContainer));
    await _settle(tester);

    expect(_containerOf(tester, item).color, _scheme.secondaryContainer);
    expect(_radiusOf(tester, item), BorderRadius.circular(16));
    expect(
      DefaultTextStyle.of(tester.element(find.text('B'))).style.color,
      _scheme.onSecondaryContainer,
    );
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.check))).color,
      _scheme.onSecondaryContainer,
    );

    final SemanticsData data = tester
        .getSemantics(find.text('B'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('отключённый пункт: 38% onSurface и без нажатия', (tester) async {
    int taps = 0;
    await _pump(
      tester,
      M3ListItem(
        headline: const Text('Нет'),
        enabled: false,
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.text('Нет'));
    await _settle(tester);
    expect(taps, 0);
    expect(
      DefaultTextStyle.of(tester.element(find.text('Нет'))).style.color,
      _scheme.onSurface.withValues(alpha: 0.38),
    );
  });
}
