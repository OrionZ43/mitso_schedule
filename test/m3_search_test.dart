import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_search.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
const String _hint = 'Поиск по расписанию';

Future<void> _pumpBar(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: M3SearchBar(
              hintText: _hint,
              contentBuilder: (context, query) =>
                  ListView(children: [Text('Запрос: $query')]),
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

Finder get _field => find.byType(TextField);

/// Таблетка открытого поиска — Material вокруг TextField.
Finder get _expandedPill =>
    find.ancestor(of: _field, matching: find.byType(Material)).first;

double _surfaceOpacity(WidgetTester tester) {
  final Finder surface = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        (w.decoration as BoxDecoration).color == _scheme.surfaceContainerLow,
  );
  return tester
      .widget<Opacity>(
        find.ancestor(of: surface, matching: find.byType(Opacity)),
      )
      .opacity;
}

double _contentOpacity(WidgetTester tester, String text) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

Future<void> _backGesture(
  WidgetTester tester,
  String method, [
  double progress = 0,
]) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(
      method,
      method == 'startBackGesture' || method == 'updateBackGestureProgress'
          ? <String, Object?>{
              'touchOffset': <double>[5, 300],
              'progress': progress,
              'swipeEdge': 0,
            }
          : null,
    ),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}

void main() {
  testWidgets(
    'свёрнутая строка: 56dp, surfaceContainerHigh, иконка и подсказка',
    (tester) async {
      await _pumpBar(tester);
      final Finder bar = find.byType(M3SearchBar);
      expect(tester.getSize(bar), const Size(720, 56));

      final Material pill = tester.widget(
        find.descendant(of: bar, matching: find.byType(Material)).first,
      );
      expect(pill.color, _scheme.surfaceContainerHigh);
      expect(pill.shape, isA<StadiumBorder>());
      expect(pill.elevation, 0);

      // Иконка поиска в 16dp от края таблетки, текст — в 52dp.
      final Rect rect = tester.getRect(bar);
      expect(tester.getTopLeft(find.byType(Icon)).dx - rect.left, 16);
      expect(tester.getTopLeft(find.text(_hint)).dx - rect.left, 52);
      final Text hint = tester.widget(find.text(_hint));
      expect(hint.style!.color, _scheme.onSurfaceVariant);
    },
  );

  testWidgets('открытие: строка уезжает наверх, подложка проявляется, фокус', (
    tester,
  ) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await tester.pump();

    // В первом кадре поле лежит на месте свёрнутой строки.
    expect(tester.getTopLeft(_expandedPill), const Offset(40, 24));
    expect(_surfaceOpacity(tester), 0);

    double maxWidth = 0;
    double lastOpacity = 0;
    bool opacityRose = false;
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      maxWidth = [
        maxWidth,
        tester.getSize(_expandedPill).width,
      ].reduce((a, b) => a > b ? a : b);
      final double opacity = _surfaceOpacity(tester);
      expect(opacity, inInclusiveRange(0, 1));
      if (opacity > lastOpacity) opacityRose = true;
      lastOpacity = opacity;
    }

    expect(opacityRose, isTrue);
    expect(_surfaceOpacity(tester), 1);
    // Поля 12dp, верх — inset (0 в тесте) + 4dp.
    expect(tester.getRect(_expandedPill), const Rect.fromLTWH(12, 4, 776, 56));
    // Ширина считается по неограниченному прогрессу — у FastSpatial перелёт.
    expect(maxWidth, greaterThan(776));
    // Контент на 8dp ниже строки.
    expect(tester.getTopLeft(find.text('Запрос: ')).dy, 4 + 56 + 8);

    final EditableTextState editable = tester.state(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    expect(editable.widget.textInputAction, TextInputAction.search);
    expect(find.byTooltip('Назад'), findsOneWidget);
  });

  testWidgets('контент: пауза 50 мс, проявление за 100 мс', (tester) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await tester.pump();
    await tester.pump(); // первый тик таймера — 0 мс

    await tester.pump(const Duration(milliseconds: 45));
    expect(_contentOpacity(tester, 'Запрос: '), 0);
    await tester.pump(const Duration(milliseconds: 55)); // 100 мс
    final double middle = _contentOpacity(tester, 'Запрос: ');
    expect(middle, greaterThan(0));
    expect(middle, lessThan(1));
    await tester.pump(const Duration(milliseconds: 50)); // 150 мс
    expect(_contentOpacity(tester, 'Запрос: '), 1);
  });

  testWidgets('ввод перестраивает контент, «Очистить» стирает запрос', (
    tester,
  ) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await _frames(tester, 40);

    Finder clearInField() => find.descendant(
      of: _expandedPill,
      matching: find.byTooltip('Очистить'),
    );
    expect(clearInField(), findsNothing);

    await tester.enterText(_field, 'эконом');
    await tester.pump();
    expect(find.text('Запрос: эконом'), findsOneWidget);
    expect(clearInField(), findsOneWidget);

    await tester.tap(clearInField());
    await tester.pump();
    expect(find.text('Запрос: '), findsOneWidget);
    expect(clearInField(), findsNothing);
    final EditableTextState editable = tester.state(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('«Назад» сворачивает поиск, запрос остаётся в строке', (
    tester,
  ) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await _frames(tester, 40);
    await tester.enterText(_field, 'сеть');
    await tester.pump();

    await tester.tap(find.byTooltip('Назад'));
    await tester.pump();
    final EditableTextState editable = tester.state(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isFalse);

    await _frames(tester, 60);
    expect(_field, findsNothing);
    expect(find.text('сеть'), findsOneWidget);
    final Opacity collapsed = tester.widget(
      find
          .ancestor(of: find.text('сеть'), matching: find.byType(Opacity))
          .first,
    );
    expect(collapsed.opacity, 1);
  });

  testWidgets('системный «назад» сворачивает поиск', (tester) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await _frames(tester, 40);

    await tester.binding.handlePopRoute();
    await _frames(tester, 60);
    expect(_field, findsNothing);
    expect(find.text(_hint), findsOneWidget);
  });

  testWidgets('доступность: поле подписано подсказкой', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpBar(tester);
    final SemanticsData collapsed = tester
        .getSemantics(find.text(_hint))
        .getSemanticsData();
    expect(collapsed.label, _hint);
    expect(collapsed.flagsCollection.isTextField, isTrue);

    await tester.tap(find.text(_hint));
    await _frames(tester, 40);
    final SemanticsData expanded = tester
        .getSemantics(find.byType(EditableText))
        .getSemanticsData();
    expect(expanded.flagsCollection.isTextField, isTrue);
    expect('${expanded.label} ${expanded.hint}', contains(_hint));
    handle.dispose();
  });

  testWidgets('predictive back: подложка 90%, поля 8dp, сворачивание', (
    tester,
  ) async {
    await _pumpBar(tester);
    await tester.tap(find.text(_hint));
    await _frames(tester, 40);

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 1);
    await tester.pump();

    final Finder surface = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).color == _scheme.surfaceContainerLow,
    );
    // `SearchBarPredictiveBackMinScale` = 0.9; жест с левого края — подложка
    // прижимается вправо с полем 8dp, но не левее свёрнутой строки.
    final Rect rect = tester.getRect(surface);
    expect(rect.size, const Size(720, 540));
    expect(rect.left, 40);
    expect(
      (tester.widget<DecoratedBox>(surface).decoration as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(28),
    );
    expect(tester.getSize(_expandedPill).width, 720 - 24);

    await _backGesture(tester, 'commitBackGesture');
    await _frames(tester, 60);
    expect(_field, findsNothing);
  });

  testWidgets('M3SearchScope.close и Navigator.pop из контента сворачивают', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: M3SearchBar(
            hintText: _hint,
            contentBuilder: (context, query) => Column(
              children: [
                TextButton(
                  onPressed: () => M3SearchScope.of(context).close(),
                  child: const Text('Закрыть'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Pop'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final String button in ['Закрыть', 'Pop']) {
      await tester.tap(find.text(_hint));
      await _frames(tester, 40);
      await tester.tap(find.text(button));
      await _frames(tester, 60);
      expect(_field, findsNothing, reason: button);
      expect(find.text(_hint), findsOneWidget);
    }
  });
}
