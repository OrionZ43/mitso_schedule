import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/connected_button_group.dart';
import 'package:mitso_schedule/widgets/m3_button_group.dart';
import 'package:mitso_schedule/widgets/m3_buttons.dart';
import 'package:mitso_schedule/widgets/m3_fab.dart';
import 'package:mitso_schedule/widgets/m3_toggle_button.dart';

final ThemeData _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
);

Future<void> _pumpApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(body: child),
    ),
  );
}

/// Прокручивает кадры по 16 мс; бесконечных анимаций нет, но `pumpAndSettle`
/// не используется, как и во всём проекте.
Future<void> _frames(WidgetTester tester, Duration total) async {
  for (Duration t = Duration.zero; t < total; t += _frame) {
    await tester.pump(_frame);
  }
}

const Duration _frame = Duration(milliseconds: 16);

Finder _materialOf(Finder button) =>
    find.descendant(of: button, matching: find.byType(Material)).first;

BorderRadius _radiiOf(WidgetTester tester, Finder button) {
  final Finder material = _materialOf(button);
  final M3CornerShape shape =
      tester.widget<Material>(material).shape! as M3CornerShape;
  return shape.radiiFor(tester.getSize(material));
}

void main() {
  group('ButtonGroupMeasurePolicy: перераспределение ширины', () {
    List<double> expand(
      List<double> widths,
      List<double> progress, {
      List<double>? limits,
      double ratio = 0.15,
    }) => M3ButtonGroup.expandPressed(
      widths: widths,
      progress: progress,
      compressionLimits: limits ?? List.filled(widths.length, 24),
      expandedRatio: ratio,
    );

    double sum(List<double> values) => values.reduce((a, b) => a + b);

    test('первая кнопка растёт за счёт правой соседки', () {
      final List<double> result = expand([100, 100, 100], [1, 0, 0]);
      expect(result, [115, 85, 100]);
      expect(sum(result), 300);
    });

    test('средняя растёт за счёт обеих соседок, по половине', () {
      final List<double> result = expand([100, 100, 100], [0, 1, 0]);
      expect(result, [92.5, 115, 92.5]);
      expect(sum(result), 300);
    });

    test('последняя растёт за счёт левой соседки', () {
      final List<double> result = expand([100, 100, 100], [0, 0, 1]);
      expect(result, [100, 85, 115]);
      expect(sum(result), 300);
    });

    test('прирост пропорционален прогрессу, в том числе перелёту', () {
      expect(expand([100, 100], [0.5, 0]), [107.5, 92.5]);
      // Пружина FastSpatial уходит ниже нуля — кнопка ненадолго сужается.
      expect(expand([100, 100], [-0.1, 0]), [98.5, 101.5]);
    });

    test('рост ограничен compressionLimit соседей', () {
      // Средняя: min(0.15 · 200 / 2, 10, 24) = 10.
      expect(expand([200, 200, 200], [0, 1, 0], limits: [10, 24, 24]), [
        190,
        220,
        190,
      ]);
      // Первая: min(0.15 · 200, 5) = 5.
      expect(expand([200, 200], [1, 0], limits: [24, 5]), [205, 195]);
      // Сосед не сжимается меньше нуля.
      expect(expand([100, 5], [1, 0], ratio: 1, limits: [100, 100]), [105, 0]);
    });

    test('одна кнопка не меняется, нажатия применяются по порядку', () {
      expect(expand([100], [1]), [100]);
      final List<double> both = expand([100, 100, 100], [1, 1, 0]);
      // Первая: +15 (соседка 85). Вторая, средняя: min(0.15·85/2, 24) = 6.375.
      expect(both[0], closeTo(115 - 6.375, 1e-9));
      expect(both[1], closeTo(85 + 12.75, 1e-9));
      expect(both[2], closeTo(100 - 6.375, 1e-9));
      expect(sum(both), closeTo(300, 1e-9));
    });
  });

  group('M3ButtonGroup', () {
    Widget groupOf3() => Center(
      child: SizedBox(
        width: 336,
        child: M3ButtonGroup(
          spacing: 12,
          children: [
            for (final String label in ['Один', 'Два', 'Три'])
              M3ButtonGroupItem(
                weight: 1,
                builder: (context, states) => M3Button(
                  onPressed: () {},
                  statesController: states,
                  child: Text(label),
                ),
              ),
          ],
        ),
      ),
    );

    List<double> widths(WidgetTester tester) => [
      for (int i = 0; i < 3; i++)
        tester.getSize(find.byType(M3Button).at(i)).width,
    ];

    testWidgets('нажатая средняя кнопка расширяется, общая ширина постоянна', (
      tester,
    ) async {
      await _pumpApp(tester, groupOf3());
      // (336 - 2 · 12) / 3 = 104.
      expect(widths(tester), [104, 104, 104]);
      final double groupWidth = tester
          .getSize(find.byType(M3ButtonGroup))
          .width;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(M3Button).at(1)),
      );
      await _frames(tester, const Duration(milliseconds: 800));

      // Средняя: 2 · min(0.15 · 104 / 2, 24, 24) = 15.6.
      final List<double> pressed = widths(tester);
      expect(pressed[1], closeTo(119.6, 0.01));
      expect(pressed[0], closeTo(96.2, 0.01));
      expect(pressed[2], closeTo(96.2, 0.01));
      expect(pressed[0] + pressed[1] + pressed[2] + 24, closeTo(336, 0.01));
      expect(tester.getSize(find.byType(M3ButtonGroup)).width, groupWidth);
      expect(
        tester.getTopLeft(find.byType(M3Button).at(2)).dx +
            pressed[2] -
            tester.getTopLeft(find.byType(M3Button).at(0)).dx,
        closeTo(336, 0.01),
      );

      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 1500));
      for (final double w in widths(tester)) {
        expect(w, closeTo(104, 0.01));
      }
    });

    testWidgets('после короткого тапа прогресс доходит до 0.75 и только '
        'потом возвращается', (tester) async {
      await _pumpApp(tester, groupOf3());
      final Finder first = find.byType(M3Button).first;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(first),
      );
      await tester.pump(); // Пружина стартует с первым кадром.
      await tester.pump(_frame);
      final double atRelease = tester.getSize(first).width - 104;
      // Полный прирост первой: min(0.15 · 104, 24) = 15.6.
      expect(atRelease, lessThan(0.75 * 15.6));
      await gesture.up();

      double maxGrowth = atRelease;
      int framesUntilPeak = 0;
      for (int frame = 0; frame < 90; frame++) {
        await tester.pump(_frame);
        final double growth = tester.getSize(first).width - 104;
        if (growth > maxGrowth) {
          maxGrowth = growth;
          framesUntilPeak = frame;
        }
      }
      expect(maxGrowth, greaterThan(0.75 * 15.6));
      expect(framesUntilPeak, greaterThan(0));
      expect(tester.getSize(first).width, closeTo(104, 0.01));
    });

    testWidgets('повторное нажатие отменяет возврат', (tester) async {
      await _pumpApp(tester, groupOf3());
      final Finder first = find.byType(M3Button).first;

      TestGesture gesture = await tester.startGesture(tester.getCenter(first));
      await _frames(tester, const Duration(milliseconds: 600));
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 48));
      gesture = await tester.startGesture(tester.getCenter(first));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(tester.getSize(first).width, closeTo(119.6, 0.01));
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 1500));
    });

    testWidgets('при «Удалить анимации» ширина не меняется', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: groupOf3()),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(M3Button).at(1)),
      );
      await _frames(tester, const Duration(milliseconds: 300));
      expect(widths(tester), [104, 104, 104]);
      await gesture.up();
      await tester.pump(_frame);
    });
  });

  group('M3Button', () {
    testWidgets('S: 40dp, зона нажатия 48dp, морф без перелёта', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        Center(
          child: M3Button(onPressed: () {}, child: const Text('Сохранить')),
        ),
      );
      final Finder button = find.byType(M3Button);
      expect(tester.getSize(_materialOf(button)).height, 40);
      expect(tester.getSize(button).height, 48);
      expect(_radiiOf(tester, button).topLeft.x, 20);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(button),
      );
      double min = 20;
      for (int frame = 0; frame < 40; frame++) {
        await tester.pump(_frame);
        final double r = _radiiOf(tester, button).topLeft.x;
        if (r < min) min = r;
      }
      // DefaultEffects: damping 1, радиус не проскакивает 8dp.
      expect(min, greaterThanOrEqualTo(8 - 1e-6));
      expect(_radiiOf(tester, button).topLeft.x, closeTo(8, 1e-6));
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 600));
      expect(_radiiOf(tester, button).topLeft.x, closeTo(20, 1e-6));
    });

    testWidgets('outlined — подпись onSurfaceVariant; disabled — 10% / 38%', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        const Column(
          children: [
            M3Button(
              key: Key('outlined'),
              onPressed: _noop,
              color: M3ButtonColor.outlined,
              child: Text('Отмена'),
            ),
            M3Button(
              key: Key('disabled'),
              onPressed: null,
              child: Text('Отправить'),
            ),
          ],
        ),
      );
      final ColorScheme colors = _theme.colorScheme;

      final Material outlined = tester.widget(
        _materialOf(find.byKey(const Key('outlined'))),
      );
      expect(outlined.textStyle!.color, colors.onSurfaceVariant);
      expect(
        (outlined.shape! as M3CornerShape).side.color,
        colors.outlineVariant,
      );

      final Material disabled = tester.widget(
        _materialOf(find.byKey(const Key('disabled'))),
      );
      expect(disabled.color, colors.onSurface.withValues(alpha: 0.1));
      expect(
        disabled.textStyle!.color,
        colors.onSurface.withValues(alpha: 0.38),
      );
    });

    testWidgets('icon button: размер по ширине, toggle меняет форму', (
      tester,
    ) async {
      Widget build(bool selected) => Row(
        children: [
          M3IconButton(
            key: const Key('uniform'),
            onPressed: _noop,
            icon: const Icon(Icons.add),
          ),
          M3IconButton(
            key: const Key('wide'),
            onPressed: _noop,
            width: M3IconButtonWidth.wide,
            icon: const Icon(Icons.add),
          ),
          M3IconButton(
            key: const Key('toggle'),
            onPressed: _noop,
            isSelected: selected,
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
          ),
        ],
      );
      await _pumpApp(tester, build(false));
      expect(
        tester.getSize(_materialOf(find.byKey(const Key('uniform')))),
        const Size(40, 40),
      );
      expect(
        tester.getSize(_materialOf(find.byKey(const Key('wide')))),
        const Size(52, 40),
      );
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await _pumpApp(tester, build(true));
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      // Выбранная round → `selected.container.shape.round` = 12dp.
      expect(
        _radiiOf(tester, find.byKey(const Key('toggle'))).topLeft.x,
        closeTo(12, 1e-6),
      );
    });
  });

  group('M3ToggleButton', () {
    Widget toggle({required bool checked, ValueChanged<bool>? onChange}) =>
        Center(
          child: M3ToggleButton(
            checked: checked,
            onCheckedChange: onChange ?? (_) {},
            child: const Text('Тест'),
          ),
        );

    testWidgets('приоритет формы: pressed > checked > default', (tester) async {
      final Finder button = find.byType(M3ToggleButton);
      double radius() => _radiiOf(tester, button).topLeft.x;

      await _pumpApp(tester, toggle(checked: true));
      expect(radius(), 12); // checked (S): corner.medium

      TestGesture gesture = await tester.startGesture(tester.getCenter(button));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(radius(), closeTo(8, 1e-6)); // pressed побеждает checked
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 800));
      expect(radius(), closeTo(12, 1e-6));

      await _pumpApp(tester, toggle(checked: false));
      expect(radius(), closeTo(12, 1e-6)); // морф ещё не начался
      await _frames(tester, const Duration(milliseconds: 800));
      expect(radius(), closeTo(20, 1e-6)); // default: full

      gesture = await tester.startGesture(tester.getCenter(button));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(radius(), closeTo(8, 1e-6));
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 800));
    });

    testWidgets(
      'цвет меняется сразу, форма — пружиной FastSpatial с перелётом',
      (tester) async {
        final Finder button = find.byType(M3ToggleButton);
        await _pumpApp(tester, toggle(checked: false));
        expect(
          tester.widget<Material>(_materialOf(button)).color,
          _theme.colorScheme.surfaceContainer,
        );

        await _pumpApp(tester, toggle(checked: true));
        expect(
          tester.widget<Material>(_materialOf(button)).color,
          _theme.colorScheme.primary,
        );

        double min = 20;
        for (int frame = 0; frame < 50; frame++) {
          await tester.pump(_frame);
          final double r = _radiiOf(tester, button).topLeft.x;
          if (r < min) min = r;
        }
        // 20 → 12 с перелётом damping 0.6 уходит ниже 12.
        expect(min, lessThan(11.8));
        expect(_radiiOf(tester, button).topLeft.x, closeTo(12, 1e-6));
      },
    );

    testWidgets('семантика по умолчанию — чекбокс', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpApp(tester, toggle(checked: true));
      expect(
        tester.getSemantics(find.byType(M3ToggleButton)),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Тест',
        ),
      );
      handle.dispose();
    });

    test('shapesFor подбирает размер по высоте', () {
      expect(M3ToggleButtonDefaults.sizeForHeight(36), M3ButtonSize.extraSmall);
      expect(M3ToggleButtonDefaults.sizeForHeight(48), M3ButtonSize.small);
      expect(M3ToggleButtonDefaults.sizeForHeight(60), M3ButtonSize.medium);
      expect(M3ToggleButtonDefaults.sizeForHeight(76), M3ButtonSize.medium);
      expect(M3ToggleButtonDefaults.sizeForHeight(104), M3ButtonSize.large);
      expect(
        M3ToggleButtonDefaults.sizeForHeight(117),
        M3ButtonSize.extraLarge,
      );
      final M3ToggleButtonShapes medium = M3ToggleButtonDefaults.shapesFor(60);
      expect(medium.shape, M3Corners.full);
      expect(medium.pressedShape, M3Corners.circular(12));
      expect(medium.checkedShape, M3Corners.circular(16));
      final M3ToggleButtonShapes square = M3ToggleButtonDefaults.shapesFor(
        40,
        shape: M3ButtonShape.square,
      );
      expect(square.shape, M3Corners.circular(12));
      expect(square.checkedShape, M3Corners.full);
    });
  });

  group('ConnectedButtonGroup', () {
    Widget groupWith({required int selected, required ValueChanged<int> on}) =>
        Center(
          child: SizedBox(
            width: 360,
            child: ConnectedButtonGroup<int>(
              values: const [0, 1, 2],
              labelOf: (v) => ['Обе', '1-я', '2-я'][v],
              selected: selected,
              onSelected: on,
            ),
          ),
        );

    testWidgets('зона нажатия 48dp по всей высоте', (tester) async {
      final List<int> taps = [];
      await _pumpApp(tester, groupWith(selected: 0, on: taps.add));
      final Finder second = find.byType(M3ToggleButton).at(1);
      expect(tester.getSize(second).height, 48);
      expect(tester.getSize(_materialOf(second)).height, 40);

      // 23dp над центром — вне кнопки 40dp, но внутри зоны 48dp.
      await tester.tapAt(tester.getCenter(second) - const Offset(0, 23));
      await tester.pump();
      await tester.tapAt(tester.getCenter(second) + const Offset(0, 23));
      await tester.pump();
      expect(taps, [1, 1]);
      await _frames(tester, const Duration(milliseconds: 1000));
    });

    testWidgets('нажатие важнее выбора: внутренние углы сжимаются до 4dp', (
      tester,
    ) async {
      await _pumpApp(tester, groupWith(selected: 0, on: (_) {}));
      final Finder first = find.byType(M3ToggleButton).first;
      expect(_radiiOf(tester, first).topRight.x, 20); // выбранная: full

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(first),
      );
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_radiiOf(tester, first).topLeft.x, closeTo(20, 1e-6));
      expect(_radiiOf(tester, first).topRight.x, closeTo(4, 1e-6));
      await gesture.up();
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_radiiOf(tester, first).topRight.x, closeTo(20, 1e-6));

      // Невыбранная средняя: 8dp на всех углах.
      final BorderRadius middle = _radiiOf(
        tester,
        find.byType(M3ToggleButton).at(1),
      );
      expect(middle.topLeft.x, 8);
      expect(middle.bottomRight.x, 8);
    });

    testWidgets('подписи без многоточия, одиночный выбор в семантике', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpApp(tester, groupWith(selected: 2, on: (_) {}));
      final RichText label = tester.widget(
        find.descendant(
          of: find.byType(M3ToggleButton).first,
          matching: find.byType(RichText),
        ),
      );
      expect(label.overflow, TextOverflow.visible);
      expect(label.softWrap, isFalse);
      expect(label.maxLines, 1);

      expect(
        tester.getSemantics(find.byType(M3ToggleButton).at(2)),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          label: '2-я',
        ),
      );
      expect(
        tester.getSemantics(find.byType(M3ToggleButton).at(0)),
        isSemantics(isSelected: false, isInMutuallyExclusiveGroup: true),
      );
      handle.dispose();
    });
  });

  group('FAB', () {
    testWidgets('размеры и цвета medium FAB', (tester) async {
      await _pumpApp(
        tester,
        const Center(
          child: M3Fab(
            onPressed: _noop,
            size: M3FabSize.medium,
            color: M3FabColor.tertiary,
            icon: Icon(Icons.add),
          ),
        ),
      );
      final Finder fab = find.byType(M3Fab);
      expect(tester.getSize(fab), const Size(80, 80));
      final Material material = tester.widget(_materialOf(fab));
      expect(material.color, _theme.colorScheme.tertiary);
      expect(material.elevation, 6);
      expect(_radiiOf(tester, fab).topLeft.x, 20);
      expect(
        tester.widget<IconTheme>(find.byType(IconTheme).last).data.size,
        28,
      );
    });

    testWidgets('скрытый FAB занимает 0×0 и не принимает касаний', (
      tester,
    ) async {
      int taps = 0;
      Widget build(bool visible) => Align(
        alignment: Alignment.bottomRight,
        child: M3AnimatedFabVisibility(
          visible: visible,
          alignment: Alignment.bottomRight,
          child: M3Fab(onPressed: () => taps++, icon: const Icon(Icons.add)),
        ),
      );

      await _pumpApp(tester, build(true));
      final Finder visibility = find.byType(M3AnimatedFabVisibility);
      final Offset center = tester.getCenter(visibility);
      final Offset corner = tester.getBottomRight(find.byType(M3Fab));
      expect(tester.getSize(visibility), const Size(56, 56));
      await tester.tapAt(center);
      expect(taps, 1);

      await _pumpApp(tester, build(false));
      await tester.pump(_frame);
      await tester.pump(_frame);
      // Ещё виден: сжимается к правому нижнему углу.
      expect(tester.getSize(visibility), const Size(56, 56));
      final Rect scaled = tester.getRect(find.byType(M3Fab));
      expect(scaled.width, lessThan(56));
      expect(scaled.bottomRight.dx, closeTo(corner.dx, 0.01));
      expect(scaled.bottomRight.dy, closeTo(corner.dy, 0.01));

      await _frames(tester, const Duration(milliseconds: 800));
      expect(tester.getSize(visibility), Size.zero);
      await tester.tapAt(center);
      expect(taps, 1);
      expect(
        tester
            .hitTestOnBinding(center)
            .path
            .any(
              (entry) =>
                  entry.target is RenderBox &&
                  find
                      .byType(M3Fab)
                      .evaluate()
                      .any((e) => e.renderObject == entry.target),
            ),
        isFalse,
      );

      await _pumpApp(tester, build(true));
      await tester.pump(_frame);
      expect(tester.getSize(visibility), const Size(56, 56));
      await _frames(tester, const Duration(milliseconds: 800));
      await tester.tapAt(center);
      expect(taps, 2);
    });

    testWidgets('изначально скрытый — без анимации', (tester) async {
      await _pumpApp(
        tester,
        const Center(
          child: M3AnimatedFabVisibility(
            visible: false,
            alignment: Alignment.center,
            child: M3Fab(onPressed: _noop, icon: Icon(Icons.add)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(M3AnimatedFabVisibility)), Size.zero);
    });

    testWidgets('extended FAB сворачивается до ширины высоты', (tester) async {
      Widget build(bool expanded) => Center(
        child: M3ExtendedFab(
          onPressed: _noop,
          label: 'Оправдать',
          icon: const Icon(Icons.add),
          expanded: expanded,
        ),
      );
      await _pumpApp(tester, build(true));
      final Finder fab = find.byType(M3ExtendedFab);
      // Small: отступы 16, иконка 24, промежуток 8.
      final double labelWidth = tester.getSize(find.text('Оправдать')).width;
      expect(tester.getSize(fab).height, 56);
      expect(
        tester.getSize(fab).width,
        closeTo(16 + 24 + 8 + labelWidth + 16, 0.01),
      );
      expect(find.text('Оправдать'), findsOneWidget);

      await _pumpApp(tester, build(false));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(tester.getSize(fab), const Size(56, 56));
      expect(find.text('Оправдать'), findsNothing);
    });
  });
}

void _noop() {}
