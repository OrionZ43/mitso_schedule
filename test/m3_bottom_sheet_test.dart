import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/widgets/m3_bottom_sheet.dart';

final ColorScheme _scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

/// Экран с кнопкой, открывающей лист. Результат закрытия — в [results].
Future<void> _pumpApp(
  WidgetTester tester, {
  required M3BottomSheetBuilder builder,
  bool halfExpandedFirst = false,
  List<Object?>? results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final Object? result = await showM3ModalBottomSheet<Object?>(
                  context: context,
                  halfExpandedFirst: halfExpandedFirst,
                  builder: builder,
                );
                results?.add(result);
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Открыть'));
  await _frames(tester, 90);
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _shortContent(BuildContext context, ScrollController controller) =>
    const SizedBox(height: 200, child: Center(child: Text('Содержимое')));

Widget _longList(BuildContext context, ScrollController controller) =>
    ListView.builder(
      controller: controller,
      itemCount: 50,
      itemExtent: 56,
      itemBuilder: (context, i) => Text('Пункт $i'),
    );

Finder get _surface => find.byWidgetPredicate(
  (w) => w is Material && w.color == _scheme.surfaceContainerLow,
);

/// Scrim — ColoredBox под GestureDetector листа, а не фон страниц.
Finder get _scrim => find.descendant(
  of: find.bySemanticsLabel(M3BottomSheetDefaults.scrimLabel),
  matching: find.byType(ColoredBox),
);

Finder get _handle => find.byTooltip(M3BottomSheetDefaults.dragHandleLabel);

double _scrimAlpha(WidgetTester tester) =>
    tester.widget<ColoredBox>(_scrim).color.a;

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
  testWidgets('контейнер, ручка и scrim по токенам', (tester) async {
    await _pumpApp(tester, builder: _shortContent);
    await tester.tap(find.text('Открыть'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // Прозрачность scrim растёт пружиной DefaultEffects.
    final double early = _scrimAlpha(tester);
    expect(early, greaterThan(0));
    expect(early, lessThan(0.32));
    await _frames(tester, 90);

    final Material surface = tester.widget(_surface);
    expect(surface.elevation, 1);
    expect(
      (surface.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    // Ширина до 640dp, по центру; высота — ручка 48 + содержимое 200.
    expect(tester.getRect(_surface), const Rect.fromLTWH(80, 352, 640, 248));

    final Color scrim = tester.widget<ColoredBox>(_scrim).color;
    expect(scrim.a, closeTo(0.32, 1e-6));
    expect(scrim.withValues(alpha: 1), _scheme.scrim.withValues(alpha: 1));

    final Finder bar = find.descendant(
      of: _handle,
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(bar), const Size(32, 4));
    expect(tester.getTopLeft(bar).dy - 352, 22);
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(bar).decoration as BoxDecoration;
    expect(decoration.color, _scheme.onSurfaceVariant);
  });

  testWidgets('нажатие на scrim закрывает лист', (tester) async {
    final List<Object?> results = [];
    await _pumpApp(tester, builder: _shortContent, results: results);
    await _open(tester);

    await tester.tapAt(const Offset(400, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_scrimAlpha(tester), lessThan(0.32));
    await _frames(tester, 30);

    expect(_surface, findsNothing);
    expect(results, [null]);
  });

  testWidgets('Navigator.pop из содержимого возвращает результат', (
    tester,
  ) async {
    final List<Object?> results = [];
    await _pumpApp(
      tester,
      results: results,
      builder: (context, controller) => TextButton(
        onPressed: () => Navigator.pop(context, 'готово'),
        child: const Text('Готово'),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Готово'));
    await _frames(tester, 30);
    expect(_surface, findsNothing);
    expect(results, ['готово']);
  });

  testWidgets(
    'halfExpandedFirst: открывается на половину и тянется до полного',
    (tester) async {
      await _pumpApp(tester, builder: _longList, halfExpandedFirst: true);
      await _open(tester);
      expect(tester.getTopLeft(_surface).dy, 300);

      // Жест по списку вверх сначала поднимает лист (`onPreScroll`).
      await tester.timedDrag(
        find.text('Пункт 2'),
        const Offset(0, -150),
        const Duration(milliseconds: 300),
      );
      await _frames(tester, 90);
      expect(tester.getTopLeft(_surface).dy, 0);
      // Список при этом не прокрутился.
      expect(tester.getTopLeft(find.text('Пункт 0')).dy, 48);

      // Жест вниз от начала списка опускает лист обратно до половины.
      await tester.timedDrag(
        find.text('Пункт 2'),
        const Offset(0, 150),
        const Duration(milliseconds: 300),
      );
      await _frames(tester, 90);
      expect(tester.getTopLeft(_surface).dy, 300);
    },
  );

  testWidgets('ручка: из половины разворачивает, из полного закрывает', (
    tester,
  ) async {
    final List<Object?> results = [];
    await _pumpApp(
      tester,
      builder: _longList,
      halfExpandedFirst: true,
      results: results,
    );
    await _open(tester);
    expect(tester.getTopLeft(_surface).dy, 300);

    await tester.tap(_handle);
    await _frames(tester, 90);
    expect(tester.getTopLeft(_surface).dy, 0);

    await tester.tap(_handle);
    await _frames(tester, 60);
    expect(_surface, findsNothing);
    expect(results, [null]);
  });

  testWidgets('бросок вниз закрывает лист', (tester) async {
    final List<Object?> results = [];
    await _pumpApp(tester, builder: _shortContent, results: results);
    await _open(tester);
    await tester.fling(_handle, const Offset(0, 200), 1500);
    await _frames(tester, 90);
    expect(_surface, findsNothing);
    expect(results, [null]);
  });

  testWidgets('«назад»: из полного — до половины, из половины — закрыть', (
    tester,
  ) async {
    await _pumpApp(tester, builder: _longList, halfExpandedFirst: true);
    await _open(tester);
    await tester.tap(_handle);
    await _frames(tester, 90);
    expect(tester.getTopLeft(_surface).dy, 0);

    await tester.binding.handlePopRoute();
    await _frames(tester, 90);
    expect(tester.getTopLeft(_surface).dy, 300);

    await tester.binding.handlePopRoute();
    await _frames(tester, 60);
    expect(_surface, findsNothing);
  });

  testWidgets('predictive back сжимает лист, отмена возвращает', (
    tester,
  ) async {
    await _pumpApp(tester, builder: _shortContent);
    await _open(tester);

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 1);
    await tester.pump();
    // `PredictiveBackMaxScaleXDistance` = 48dp.
    expect(tester.getRect(_surface).width, closeTo(640 - 48, 0.5));
    expect(tester.getRect(_surface).height, closeTo(248 - 24, 0.5));

    await _backGesture(tester, 'cancelBackGesture');
    await _frames(tester, 60);
    expect(tester.getRect(_surface).width, closeTo(640, 0.01));

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.5);
    await _backGesture(tester, 'commitBackGesture');
    await _frames(tester, 60);
    expect(_surface, findsNothing);
  });
}
