import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/models/lesson.dart';
import 'package:mitso_schedule/theme/app_typography.dart';
import 'package:mitso_schedule/widgets/day_selector.dart';
import 'package:mitso_schedule/widgets/m3_button_group.dart';
import 'package:mitso_schedule/widgets/m3_buttons.dart';
import 'package:mitso_schedule/widgets/m3_toggle_button.dart';

/// Две недели Пн–Сб: 14–19 и 21–26 сентября 2026.
final List<ScheduleDay> _days = [
  for (final int day in [14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26])
    ScheduleDay(date: DateTime(2026, 9, day), lessons: const []),
];

final ThemeData _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  textTheme: AppTypography.textTheme(Brightness.light),
);

Future<void> _pump(
  WidgetTester tester, {
  required int selected,
  ValueChanged<int>? onSelected,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: DaySelector(
            days: _days,
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

double _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    // Medium Phone: 1080×2400 при плотности 2.625 — 411dp в ширину.
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2400,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 2.625;
  });

  tearDown(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  test('дни делятся на календарные недели с понедельника', () {
    expect(DaySelector.weeksOf(_days), [
      [0, 1, 2, 3, 4, 5],
      [6, 7, 8, 9, 10, 11],
    ]);
    final List<ScheduleDay> fromWednesday = [
      for (final int day in [16, 17, 21])
        ScheduleDay(date: DateTime(2026, 9, day), lessons: const []),
    ];
    expect(DaySelector.weeksOf(fromWednesday), [
      [0, 1],
      [2],
    ]);
  });

  testWidgets('неделя — одна группа во всю ширину, без прокрутки', (
    tester,
  ) async {
    await _pump(tester, selected: 2);

    expect(find.byType(M3ButtonGroup), findsOneWidget);
    expect(find.byType(M3ToggleButton), findsNWidgets(6));
    // (411.43 − 2·16 − 5·8) / 6: промежуток M = 8dp.
    final double width = tester
        .getSize(find.byType(M3ToggleButton).first)
        .width;
    expect(width, closeTo((1080 / 2.625 - 32 - 40) / 6, 0.01));
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);

    // Высота 8 + 20 (labelLarge) + 24 (titleMedium) + 8 = 60 → корзина M.
    final Finder selected = find.byType(M3ToggleButton).at(2);
    final Finder material = find
        .descendant(of: selected, matching: find.byType(Material))
        .first;
    expect(tester.getSize(material).height, 60);
    final M3CornerShape shape =
        tester.widget<Material>(material).shape! as M3CornerShape;
    expect(shape.corners, M3Corners.circular(16));
    expect(tester.widget<Material>(material).color, _theme.colorScheme.primary);
    final Material other = tester.widget(
      find
          .descendant(
            of: find.byType(M3ToggleButton).first,
            matching: find.byType(Material),
          )
          .first,
    );
    expect(other.color, _theme.colorScheme.surfaceContainer);
    expect((other.shape! as M3CornerShape).corners, M3Corners.full);
  });

  testWidgets('тап выбирает день', (tester) async {
    final List<int> selected = [];
    await _pump(tester, selected: 0, onSelected: selected.add);
    await tester.tap(find.text('17'));
    await tester.pump();
    expect(selected, [3]);
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('выбор дня другой недели плавно листает страницу', (
    tester,
  ) async {
    await _pump(tester, selected: 2);
    expect(_page(tester), 0);
    expect(find.text('16'), findsOneWidget);

    await _pump(tester, selected: 8);
    await tester.pump(); // Кадр с post-frame callback запускает анимацию.
    await tester.pump(const Duration(milliseconds: 150));
    final double midway = _page(tester);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pump(const Duration(milliseconds: 600));
    expect(_page(tester), 1);
    expect(find.text('23'), findsOneWidget);

    // Смена дня внутри той же недели страницу не трогает.
    await _pump(tester, selected: 9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_page(tester), 1);
  });

  testWidgets('неделя листается пальцем', (tester) async {
    await _pump(tester, selected: 0);
    await tester.fling(find.text('17'), const Offset(-300, 0), 1000);
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_page(tester), 1);
  });

  testWidgets('семантика: кнопка, одиночный выбор, полная дата', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, selected: 2);

    expect(
      tester.getSemantics(find.byType(M3ToggleButton).at(2)),
      isSemantics(
        label: 'Среда, 16 сентября',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(M3ToggleButton).at(0)),
      isSemantics(
        label: 'Понедельник, 14 сентября',
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('масштаб шрифта 200%: высота растёт, переполнений нет', (
    tester,
  ) async {
    await _pump(tester, selected: 2);
    final double normal = tester.getSize(find.byType(DaySelector)).height;

    await _pump(tester, selected: 2, textScale: 2);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);

    final double large = tester.getSize(find.byType(DaySelector)).height;
    expect(normal, 60);
    // 8 + 40 + 48 + 8 = 104 → корзина L: выбранная 28dp, промежуток 8dp.
    expect(large, 104);
    final Finder material = find
        .descendant(
          of: find.byType(M3ToggleButton).at(2),
          matching: find.byType(Material),
        )
        .first;
    expect(
      (tester.widget<Material>(material).shape! as M3CornerShape).corners,
      M3Corners.circular(28),
    );
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });
}
