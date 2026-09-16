import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_checkbox.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

/// Чекбокс, значением которого управляет тест через [setValue].
late void Function(bool? value) setValue;

Future<void> _pump(
  WidgetTester tester, {
  bool? initial = false,
  bool tristate = false,
  bool enabled = true,
  bool isError = false,
  bool selfUpdate = true,
  FocusNode? focusNode,
  List<bool?>? changes,
}) async {
  bool? value = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              setValue = (v) => setState(() => value = v);
              return M3Checkbox(
                value: value,
                tristate: tristate,
                isError: isError,
                focusNode: focusNode,
                onChanged: enabled
                    ? (v) {
                        changes?.add(v);
                        if (selfUpdate) setState(() => value = v);
                      }
                    : null,
              );
            },
          ),
        ),
      ),
    ),
  );
}

M3CheckboxState _state(WidgetTester tester) =>
    tester.state<M3CheckboxState>(find.byType(M3Checkbox));

Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('зона нажатия 48dp, контейнер 18dp', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(M3Checkbox)), const Size(48, 48));
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(M3Checkbox),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == const Size.square(18),
          ),
        ),
      ),
      const Size(18, 18),
    );
  });

  testWidgets('галочка прорисовывается пружиной при включении', (tester) async {
    await _pump(tester);
    expect(_state(tester).checkFraction, 0);

    await tester.tap(find.byType(M3Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final double early = _state(tester).checkFraction;
    expect(early, greaterThan(0));
    expect(early, lessThan(1));

    // DefaultSpatial (0.8 / 380) — с небольшим перелётом.
    double max = 0;
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double f = _state(tester).checkFraction;
      if (f > max) max = f;
    }
    expect(max, greaterThan(1));
    expect(_state(tester).checkFraction, 1);
    expect(_state(tester).gravitationFraction, 0);
  });

  testWidgets('при выключении галочка исчезает через 100 мс разом', (
    tester,
  ) async {
    await _pump(tester, initial: true);
    expect(_state(tester).checkFraction, 1);

    await tester.tap(find.byType(M3Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_state(tester).checkFraction, 1);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_state(tester).checkFraction, 1);
    await tester.pump(const Duration(milliseconds: 20));
    expect(_state(tester).checkFraction, 0);
    await _frames(tester, 30);
  });

  testWidgets('цвета: заливка DefaultEffects, сброс FastEffects', (
    tester,
  ) async {
    await _pump(tester);
    var (box, border, check) = _state(tester).currentColors;
    expect(box, Colors.transparent);
    expect(border, _scheme.onSurfaceVariant);
    expect(check, Colors.transparent);

    setValue(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    (box, _, _) = _state(tester).currentColors;
    expect(box, isNot(_scheme.primary));
    expect(box.a, greaterThan(0));
    await _frames(tester, 40);
    (box, border, check) = _state(tester).currentColors;
    expect(box, _scheme.primary);
    expect(border, _scheme.primary);
    expect(check, _scheme.onPrimary);

    // Сброс быстрее заливки: через одинаковое время дальше от старта.
    setValue(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final double outAlpha = _state(tester).currentColors.$1.a;
    await _frames(tester, 40);
    setValue(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final double inAlpha = _state(tester).currentColors.$1.a;
    expect(1 - outAlpha, greaterThan(inAlpha));
    await _frames(tester, 40);
  });

  testWidgets('нажатие меняет обводку невыбранного на onSurface', (
    tester,
  ) async {
    await _pump(tester, selfUpdate: false);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(M3Checkbox)),
    );
    await _frames(tester, 30);
    expect(_state(tester).currentColors.$2, _scheme.onSurface);
    await gesture.cancel();
    await _frames(tester, 30);
    expect(_state(tester).currentColors.$2, _scheme.onSurfaceVariant);
  });

  testWidgets('ошибка и недоступный — по токенам', (tester) async {
    await _pump(tester, initial: true, isError: true);
    var (box, border, check) = _state(tester).currentColors;
    expect(box, _scheme.error);
    expect(check, _scheme.onError);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, isError: true);
    (_, border, _) = _state(tester).currentColors;
    expect(border, _scheme.error);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, initial: true, enabled: false);
    (box, border, check) = _state(tester).currentColors;
    expect(box, _scheme.onSurface.withValues(alpha: 0.38));
    expect(check, _scheme.surface);

    // Недоступный меняет фон и обводку без анимации.
    setValue(false);
    await tester.pump();
    (box, border, _) = _state(tester).currentColors;
    expect(box, Colors.transparent);
    expect(border, _scheme.onSurface.withValues(alpha: 0.38));
    await _frames(tester, 30);
  });

  testWidgets('tristate: неопределённый → выбран → снят → выбран', (
    tester,
  ) async {
    final List<bool?> changes = [];
    await _pump(tester, initial: null, tristate: true, changes: changes);
    expect(_state(tester).checkFraction, 1);
    expect(_state(tester).gravitationFraction, 1);

    await tester.tap(find.byType(M3Checkbox));
    await _frames(tester, 40);
    expect(_state(tester).gravitationFraction, 0);
    expect(_state(tester).checkFraction, 1);

    await tester.tap(find.byType(M3Checkbox));
    await _frames(tester, 40);
    expect(_state(tester).checkFraction, 0);

    await tester.tap(find.byType(M3Checkbox));
    await _frames(tester, 40);
    expect(changes, [true, false, true]);

    // Выбран → неопределённый (решает родитель): черта — DefaultSpatial.
    setValue(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final double g = _state(tester).gravitationFraction;
    expect(g, greaterThan(0));
    expect(g, lessThan(1));
    await _frames(tester, 40);
    expect(_state(tester).gravitationFraction, 1);
  });

  testWidgets('из снятого в неопределённый черта появляется без сдвига', (
    tester,
  ) async {
    await _pump(tester, tristate: true);
    setValue(null);
    await tester.pump();
    // `initialState == Off` → snap() для сдвига к центру.
    expect(_state(tester).gravitationFraction, 1);
    await _frames(tester, 40);
  });

  testWidgets('семантика: checked и mixed', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, initial: true, tristate: true);
    expect(
      tester.getSemantics(find.byType(M3Checkbox)),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isCheckStateMixed: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    setValue(null);
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(M3Checkbox)),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        isCheckStateMixed: true,
      ),
    );
    await _frames(tester, 40);
    handle.dispose();
  });

  testWidgets('клавиатура: Space переключает', (tester) async {
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    final List<bool?> changes = [];
    await _pump(tester, focusNode: node, changes: changes);
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _frames(tester, 40);
    expect(changes, [true]);
  });
}
