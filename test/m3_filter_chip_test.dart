import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mitso_schedule/widgets/m3_filter_chip.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange);

Future<void> _pump(
  WidgetTester tester, {
  bool initial = false,
  bool enabled = true,
  Widget? leading,
  List<bool>? changes,
}) async {
  bool selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => M3FilterChip(
              label: const Text('Преподаватель'),
              selected: selected,
              leading: leading,
              onSelected: enabled
                  ? (v) {
                      changes?.add(v);
                      setState(() => selected = v);
                    }
                  : null,
            ),
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

final Finder _container = find.byKey(M3FilterChip.containerKey);
final Finder _slot = find.byKey(M3FilterChip.leadingSlotKey);

Material _material(WidgetTester tester) => tester.widget<Material>(_container);

BorderSide _side(WidgetTester tester) =>
    (_material(tester).shape! as RoundedRectangleBorder).side;

Color? _labelColor(WidgetTester tester) =>
    DefaultTextStyle.of(tester.element(find.text('Преподаватель'))).style.color;

double _labelInset(WidgetTester tester) =>
    tester.getTopLeft(find.text('Преподаватель')).dx -
    tester.getTopLeft(_container).dx;

void main() {
  testWidgets('контейнер 32dp, форма 8dp, зона нажатия 48dp', (tester) async {
    await _pump(tester);
    expect(tester.getSize(_container).height, 32);
    expect(tester.getSize(find.byType(M3FilterChip)).height, 48);
    final RoundedRectangleBorder shape =
        _material(tester).shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(8)));

    // Касание в зоне 48dp вне контейнера 32dp тоже выбирает.
    final List<bool> changes = [];
    await _pump(tester, changes: changes);
    final Rect chip = tester.getRect(_container);
    await tester.tapAt(Offset(chip.center.dx, chip.top - 6));
    await _frames(tester, 40);
    expect(changes, [true]);
  });

  testWidgets('невыбранный: обводка 1dp outlineVariant, подпись '
      'onSurfaceVariant, поля 16dp', (tester) async {
    await _pump(tester);
    expect(_material(tester).color, Colors.transparent);
    expect(_side(tester).color, _scheme.outlineVariant);
    expect(_side(tester).width, 1);
    expect(_labelColor(tester), _scheme.onSurfaceVariant);
    expect(find.byIcon(Symbols.check), findsNothing);
    expect(tester.getSize(_slot).width, 0);
    expect(_labelInset(tester), 16);
    final double right =
        tester.getTopRight(_container).dx -
        tester.getTopRight(find.text('Преподаватель')).dx;
    expect(right, 16);
  });

  testWidgets('выбранный: secondaryContainer без обводки, галочка 18dp', (
    tester,
  ) async {
    await _pump(tester, initial: true);
    expect(_material(tester).color, _scheme.secondaryContainer);
    expect(_side(tester), BorderSide.none);
    expect(_labelColor(tester), _scheme.onSecondaryContainer);
    final Icon check = tester.widget<Icon>(find.byIcon(Symbols.check));
    expect(tester.getSize(find.byIcon(Symbols.check)), const Size(18, 18));
    expect(
      IconTheme.of(tester.element(find.byIcon(Symbols.check))).color,
      _scheme.onSecondaryContainer,
    );
    expect(check.icon, Symbols.check);
    // 8dp поле + 18dp иконка + 8dp промежуток.
    expect(_labelInset(tester), 34);
  });

  testWidgets('галочка выдвигается при выборе и уезжает при снятии', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byType(M3FilterChip));
    await tester.pump();
    // Цвета — сразу, без анимации.
    expect(_material(tester).color, _scheme.secondaryContainer);
    await tester.pump(const Duration(milliseconds: 16));
    final double early = tester.getSize(_slot).width;
    expect(early, greaterThan(0));
    expect(early, lessThan(18));

    // FastSpatial с перелётом.
    double max = 0;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double w = tester.getSize(_slot).width;
      if (w > max) max = w;
    }
    expect(max, greaterThan(18));
    expect(tester.getSize(_slot).width, 18);

    await tester.tap(find.byType(M3FilterChip));
    await tester.pump();
    expect(_material(tester).color, Colors.transparent);
    await tester.pump(const Duration(milliseconds: 16));
    // Пока слот уезжает, в нём остаётся галочка.
    expect(find.byIcon(Symbols.check), findsOneWidget);
    double min = 18;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double w = tester.getSize(_slot).width;
      if (w < min) min = w;
    }
    expect(min, 0);
    expect(find.byIcon(Symbols.check), findsNothing);
  });

  testWidgets('с ведущей иконкой галочка заменяет её без анимации', (
    tester,
  ) async {
    await _pump(tester, leading: const Icon(Symbols.person));
    expect(tester.getSize(_slot).width, 18);
    expect(find.byIcon(Symbols.person), findsOneWidget);
    expect(
      IconTheme.of(tester.element(find.byIcon(Symbols.person))).color,
      _scheme.primary,
    );

    await tester.tap(find.byType(M3FilterChip));
    await tester.pump();
    expect(find.byIcon(Symbols.person), findsNothing);
    expect(find.byIcon(Symbols.check), findsOneWidget);
    expect(tester.getSize(_slot).width, 18);
  });

  testWidgets('недоступный — по токенам disabled', (tester) async {
    await _pump(tester, enabled: false);
    expect(_side(tester).color, _scheme.onSurface.withValues(alpha: 0.12));
    expect(_labelColor(tester), _scheme.onSurface.withValues(alpha: 0.38));

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, initial: true, enabled: false);
    expect(_material(tester).color, _scheme.onSurface.withValues(alpha: 0.12));
    expect(_side(tester), BorderSide.none);
  });

  testWidgets('семантика: checked', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(find.byType(M3FilterChip)),
      isSemantics(
        label: 'Преподаватель',
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    await tester.tap(find.byType(M3FilterChip));
    await _frames(tester, 40);
    expect(
      tester.getSemantics(find.byType(M3FilterChip)),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    handle.dispose();
  });
}
