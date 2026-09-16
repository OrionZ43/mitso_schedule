import 'dart:ui' show SemanticsAction, SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/theme/app_motion.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';

const List<M3NavigationDestination> _destinations = [
  M3NavigationDestination(icon: Icons.calendar_month, label: 'Расписание'),
  M3NavigationDestination(icon: Icons.event_busy, label: 'Пропуски'),
  M3NavigationDestination(icon: Icons.checklist, label: 'Заметки'),
  M3NavigationDestination(icon: Icons.person, label: 'Профиль'),
];

final ThemeData _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
);

/// Панель внизу экрана с переключением по нажатию; вызовы колбэков
/// записываются в [selected] и [reselected].
Future<void> _pumpBar(
  WidgetTester tester, {
  required List<int> selected,
  required List<int> reselected,
  double textScale = 1,
  // Глифы тестового шрифта квадратные и шире Roboto: при 412dp «Расписание»
  // уже переносится.
  double width = 600,
}) async {
  tester.view.physicalSize = Size(width * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  int index = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          bottomNavigationBar: M3NavigationBar(
            selectedIndex: index,
            destinations: _destinations,
            onSelected: (value) {
              selected.add(value);
              setState(() => index = value);
            },
            onReselected: reselected.add,
          ),
        ),
      ),
    ),
  );
}

/// Индикатор внутри пункта с подписью [label] или `null`, если он скрыт.
Finder _indicatorOf(String label) {
  final Finder item = find.ancestor(
    of: find.text(label),
    matching: find.byType(MergeSemantics),
  );
  return find.descendant(
    of: item,
    matching: find.byKey(const ValueKey<String>('m3-navigation-indicator')),
  );
}

double _indicatorWidth(WidgetTester tester, String label) {
  final Finder indicator = _indicatorOf(label);
  if (indicator.evaluate().isEmpty) return 0;
  return tester.getSize(indicator).width;
}

double _indicatorAlpha(WidgetTester tester, String label) {
  final Finder indicator = _indicatorOf(label);
  if (indicator.evaluate().isEmpty) return 0;
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: indicator, matching: find.byType(DecoratedBox)),
  );
  final Color color = (box.decoration as ShapeDecoration).color!;
  return color.a / _theme.colorScheme.secondaryContainer.a;
}

SemanticsNode _semanticsWithRole(WidgetTester tester, SemanticsRole role) {
  final List<SemanticsNode> found = [];
  void visit(SemanticsNode node) {
    if (node.role == role) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  expect(found, hasLength(1), reason: 'узлов с ролью $role');
  return found.single;
}

void main() {
  testWidgets('высота 64dp, индикатор 56×32 у активного пункта', (
    tester,
  ) async {
    await _pumpBar(tester, selected: [], reselected: []);

    expect(tester.getSize(find.byType(M3NavigationBar)).height, 64);
    expect(_indicatorWidth(tester, 'Расписание'), 56);
    expect(tester.getSize(_indicatorOf('Расписание')).height, 32);
    expect(_indicatorOf('Пропуски'), findsNothing);

    // Индикатор — по центру иконки, 6dp от верха пункта.
    final Rect bar = tester.getRect(find.byType(M3NavigationBar));
    final Rect indicator = tester.getRect(_indicatorOf('Расписание'));
    final Rect icon = tester.getRect(find.byIcon(Icons.calendar_month));
    expect(indicator.center, icon.center);
    expect(indicator.top - bar.top, 6);
    // Подпись — 4dp ниже индикатора.
    expect(tester.getRect(find.text('Расписание')).top - indicator.bottom, 4);

    // Иконка активного пункта заполнена, остальных — нет.
    expect(tester.widget<Icon>(find.byIcon(Icons.calendar_month)).fill, 1);
    expect(tester.widget<Icon>(find.byIcon(Icons.event_busy)).fill, 0);
  });

  testWidgets(
    'ширина и прозрачность индикатора идут по пружине DefaultSpatial',
    (tester) async {
      final List<int> selected = [];
      await _pumpBar(tester, selected: selected, reselected: []);

      await tester.tap(find.text('Пропуски'));
      // Первый кадр запускает тикер: прошедшее время 0.
      await tester.pump();
      expect(selected, [1]);

      final spring = AppMotion.defaultSpatial.simulate(from: 0, to: 1);
      double maxWidth = 0;
      double previousOutgoing = 56;
      bool settled = false;
      const int frameMs = 16;
      for (int frame = 1; frame <= 40; frame++) {
        await tester.pump(const Duration(milliseconds: frameMs));
        final double t = frame * frameMs / 1000;
        // Контроллер останавливается на первом кадре, где пружина
        // успокоилась, и ставит значение ровно в цель.
        settled = settled || spring.isDone(t);
        final double expected = settled ? 1 : spring.x(t);

        final double width = _indicatorWidth(tester, 'Пропуски');
        expect(width, closeTo(56 * expected, 0.01), reason: 'кадр $frame');
        expect(
          _indicatorAlpha(tester, 'Пропуски'),
          closeTo(expected.clamp(0.0, 1.0), 0.01),
          reason: 'кадр $frame',
        );
        maxWidth = width > maxWidth ? width : maxWidth;

        // Уходящий индикатор той же пружиной сужается к 0 и не прыгает вверх.
        final double outgoing = _indicatorWidth(tester, 'Расписание');
        expect(outgoing, lessThanOrEqualTo(previousOutgoing + 0.01));
        previousOutgoing = outgoing;
      }

      // Перелёт: пружина с damping 0.8 шире 56dp, но не больше чем на ~2%.
      expect(maxWidth, greaterThan(56));
      expect(maxWidth, lessThan(56 * 1.02));
      expect(_indicatorOf('Расписание'), findsNothing);
      expect(_indicatorWidth(tester, 'Пропуски'), 56);
    },
  );

  testWidgets('при смене цели посреди движения скорость сохраняется', (
    tester,
  ) async {
    await _pumpBar(tester, selected: [], reselected: []);

    await tester.tap(find.text('Пропуски'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final double before = _indicatorWidth(tester, 'Пропуски');
    expect(before, inExclusiveRange(0, 56));

    // Назад на первый пункт: индикатор «Пропусков» по инерции ещё растёт.
    await tester.tap(find.text('Расписание'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_indicatorWidth(tester, 'Пропуски'), greaterThan(before));

    await tester.pump(const Duration(seconds: 1));
    expect(_indicatorOf('Пропуски'), findsNothing);
    expect(_indicatorWidth(tester, 'Расписание'), 56);
  });

  testWidgets('повторное нажатие на активный пункт — onReselected', (
    tester,
  ) async {
    final List<int> selected = [];
    final List<int> reselected = [];
    await _pumpBar(tester, selected: selected, reselected: reselected);

    await tester.tap(find.text('Расписание'));
    await tester.pump();
    expect(reselected, [0]);
    expect(selected, isEmpty);

    // Нажатие по краю пункта, вне индикатора, тоже считается.
    final Rect item = tester.getRect(
      find.ancestor(
        of: find.text('Заметки'),
        matching: find.byType(MergeSemantics),
      ),
    );
    await tester.tapAt(item.bottomLeft + const Offset(2, -2));
    await tester.pump();
    expect(selected, [2]);
  });

  testWidgets('роли tabBar и tab, выбранный пункт отмечен', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpBar(tester, selected: [], reselected: []);

    final SemanticsNode bar = _semanticsWithRole(tester, SemanticsRole.tabBar);
    expect(bar.childrenCount, _destinations.length);

    final List<SemanticsNode> tabs = [];
    bar.visitChildren((child) {
      tabs.add(child);
      return true;
    });
    for (int i = 0; i < tabs.length; i++) {
      final SemanticsData data = tabs[i].getSemanticsData();
      expect(data.role, SemanticsRole.tab);
      expect(data.label, contains(_destinations[i].label));
      // В русской локализации между словами неразрывные пробелы.
      expect(
        data.label.replaceAll(' ', ' '),
        contains('${i + 1} из ${_destinations.length}'),
      );
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(
        data.flagsCollection.isSelected,
        i == 0 ? Tristate.isTrue : Tristate.isFalse,
      );
    }
    handle.dispose();
  });

  testWidgets('клавиатура: Tab переводит фокус, Enter выбирает', (
    tester,
  ) async {
    final List<int> selected = [];
    await _pumpBar(tester, selected: selected, reselected: []);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, [1]);
  });

  testWidgets('шрифт 2×: подписи целиком, панель растёт без переполнения', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      selected: [],
      reselected: [],
      textScale: 2,
      width: 360,
    );
    expect(tester.takeException(), isNull);

    final Rect bar = tester.getRect(find.byType(M3NavigationBar));
    double tallestLabel = 0;
    for (final M3NavigationDestination destination in _destinations) {
      final Rect label = tester.getRect(find.text(destination.label));
      expect(label.bottom, lessThanOrEqualTo(bar.bottom - 6));
      final double height = label.height;
      tallestLabel = height > tallestLabel ? height : tallestLabel;
    }
    // Одна строка labelMedium при 2× — 32dp; длинные подписи переносятся.
    expect(tallestLabel, greaterThan(32));
    expect(bar.height, 6 + 32 + 4 + tallestLabel + 6);
    expect(bar.height, greaterThan(M3NavigationBar.containerHeight));
  });
}
