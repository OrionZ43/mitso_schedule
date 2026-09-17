// Зонд производительности: сколько виджетов перестраивается и сколько
// render-объектов рисуется за кадр в типовых сценариях.
//
//   flutter test test/perf_probe.dart
//
// Имя без суффикса _test.dart — обычный `flutter test` его не запускает.
// Счётчики не заменяют профилирование на телефоне (`flutter run --profile`),
// но показывают лишнюю работу: перестройку всего экрана на кадре анимации
// или перерисовку списка из-за маленького индикатора.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/features/schedule/lesson_card.dart';
import 'package:mitso_schedule/widgets/day_selector.dart';
import 'package:mitso_schedule/widgets/m3_fab.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';
import 'package:mitso_schedule/widgets/m3_switch.dart';

import 'app_test.dart' show pumpApp;

/// Виджеты приложения, к которым приписываются перестройки.
final RegExp _ownWidget = RegExp(
  r'^(M3|Day|Lesson|Segmented|Schedule|Expandable|Connected|Profile|Absences|'
  r'Notes|Home|FadeThrough|Sliver[A-Z]\w*FlexibleAppBar)',
);

class _Probe {
  final Map<String, int> _builds = {};
  final Map<String, int> _paints = {};
  int _frames = 0;

  void start() {
    _builds.clear();
    _paints.clear();
    _frames = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      String owner = '?';
      element.visitAncestorElements((ancestor) {
        final String type = ancestor.widget.runtimeType.toString();
        if (!_ownWidget.hasMatch(type)) return true;
        owner = type;
        return false;
      });
      final String key = '${element.widget.runtimeType} ← $owner';
      _builds[key] = (_builds[key] ?? 0) + 1;
    };
    debugOnProfilePaint = (renderObject) {
      final String key = renderObject.runtimeType.toString();
      _paints[key] = (_paints[key] ?? 0) + 1;
    };
  }

  Future<void> frames(WidgetTester tester, int count) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      _frames++;
    }
  }

  void report(String name) {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
    int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
    String top(Map<String, int> m) {
      final entries = m.entries.toList()..sort((a, b) => b.value - a.value);
      return entries.take(8).map((e) => '    ${e.value} ${e.key}').join('\n');
    }

    final int frames = _frames == 0 ? 1 : _frames;
    // ignore: avoid_print
    print(
      '=== $name: кадров $_frames, '
      'перестроек ${total(_builds)} (${total(_builds) ~/ frames}/кадр), '
      'отрисовок ${total(_paints)} (${total(_paints) ~/ frames}/кадр)\n'
      '  перестройки:\n${top(_builds)}\n  отрисовки:\n${top(_paints)}',
    );
  }
}

Future<void> _tapTab(WidgetTester tester, String label) => tester.tap(
  find.descendant(of: find.byType(M3NavigationBar), matching: find.text(label)),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('зонд производительности', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 2));
    final _Probe probe = _Probe();

    probe.start();
    await probe.frames(tester, 60);
    probe.report('простой на расписании, идёт пара');

    probe.start();
    final TestGesture swipe = await tester.startGesture(
      tester.getCenter(find.text('Сегодня')),
    );
    for (int i = 0; i < 20; i++) {
      await swipe.moveBy(const Offset(-15, 0));
      await probe.frames(tester, 1);
    }
    await swipe.up();
    await probe.frames(tester, 40);
    probe.report('свайп дня');

    probe.start();
    await tester.tap(
      find
          .descendant(
            of: find.byType(DaySelector),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await probe.frames(tester, 50);
    probe.report('выбор дня в ленте');

    probe.start();
    final TestGesture press = await tester.startGesture(
      tester.getCenter(find.byType(LessonCard).first),
    );
    await probe.frames(tester, 30);
    probe.report('удержание карточки пары');
    await press.cancel();
    await tester.pump(const Duration(seconds: 1));

    probe.start();
    final TestGesture button = await tester.startGesture(
      tester.getCenter(find.byTooltip('Сменить группу')),
    );
    await probe.frames(tester, 30);
    probe.report('удержание кнопки');
    await button.cancel();
    await tester.pump(const Duration(seconds: 1));

    probe.start();
    final TestGesture scroll = await tester.startGesture(
      const Offset(200, 600),
    );
    for (int i = 0; i < 20; i++) {
      await scroll.moveBy(const Offset(0, -10));
      await probe.frames(tester, 1);
    }
    await scroll.up();
    await probe.frames(tester, 30);
    probe.report('прокрутка');

    probe.start();
    await _tapTab(tester, 'Профиль');
    await probe.frames(tester, 60);
    probe.report('переход на вкладку «Профиль»');

    probe.start();
    await tester.tap(find.byType(M3Switch).first);
    await probe.frames(tester, 50);
    probe.report('переключатель динамических цветов');

    probe.start();
    await _tapTab(tester, 'Пропуски');
    await probe.frames(tester, 60);
    probe.report('переход на вкладку «Пропуски»');

    probe.start();
    await tester.tap(find.byType(M3ExtendedFab));
    await probe.frames(tester, 60);
    probe.report('открытие листа');

    probe.start();
    await probe.frames(tester, 60);
    probe.report('простой с открытым листом');
  });
}
