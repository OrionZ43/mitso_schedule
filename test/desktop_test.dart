import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:mitso_schedule/features/widget_mode/app_window.dart';
import 'package:mitso_schedule/features/widget_mode/compact_screen.dart';

import 'app_test.dart';

/// Чем настольная сборка отличается от телефонной.
///
/// Тесты идут на настольной машине, но `defaultTargetPlatform` в них —
/// Android, поэтому обычные тесты проверяют телефон. Здесь платформа
/// подменяется на Windows.
void main() {
  setUpAll(() async => initializeDateFormatting('ru'));

  /// Платформу нужно вернуть до конца тела теста: flutter_test проверяет, что
  /// отладочные переменные не остались изменёнными, ещё до tearDown.
  Future<void> onDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('на компьютере значок приложения не меняется', (tester) async {
    await onDesktop(() async {
      await pumpApp(tester);
      await openTab(tester, 'Профиль');
      await tester.tap(find.byIcon(Symbols.settings));
      await settle(tester);

      // Значок переключается activity-alias'ами — это только Android.
      expect(find.text('Значок приложения'), findsNothing);
      // Остальные настройки на месте.
      expect(find.text('Тема'), findsOneWidget);
      expect(find.text('Динамические цвета'), findsOneWidget);
      expect(find.text('О приложении'), findsOneWidget);
    });
  });

  testWidgets('на компьютере справка добавляется файлом', (tester) async {
    await onDesktop(() async {
      await pumpApp(tester);
      await openTab(tester, 'Пропуски');
      await tester.tap(find.text('Зарегистрировать пропуск'));
      await settle(tester);

      expect(find.text('Выбрать файл'), findsOneWidget);
      expect(find.text('Фото с телефона или скан справки'), findsOneWidget);
      // Камеры на компьютере нет.
      expect(find.text('Сфотографировать'), findsNothing);
    });
  });

  testWidgets('компактное окно показывает часы и идущую пару', (tester) async {
    await onDesktop(() async {
      // Ключ --widget в автозапуске: приложение открывается сразу компактным.
      await pumpApp(
        tester,
        overrides: [startCompactProvider.overrideWithValue(true)],
      );

      expect(find.byType(CompactScreen), findsOneWidget);
      // Среда, 16 сентября, 10:30 — идёт пара 09:45–11:05.
      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('Ср, 16 сент.'), findsOneWidget);
      expect(find.text('Веб-дизайн и шаблоны проектирования'), findsOneWidget);
      expect(find.text('71'), findsOneWidget);
      expect(find.text('09:45–11:05 · осталось 35 мин'), findsOneWidget);
      // Ни навигации, ни списка дней в компактном окне нет.
      expect(find.text('Пропуски'), findsNothing);
    });
  });
}
