import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Поднимает приложение целиком с чистыми настройками.
///
/// `pumpAndSettle` здесь не применяется: индикатор загрузки, волнистая шкала
/// и пульсирующая точка анимируются бесконечно, поэтому дерево никогда не
/// «успокаивается». Кадры прокручиваются явными [WidgetTester.pump].
Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Без искусственной задержки загрузки.
        appBootProvider.overrideWith((ref) async {}),
      ],
      child: const ScheduleApp(),
    ),
  );

  // Экран загрузки -> главный экран.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Переход на вкладку по подписи в navigation bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('переключение вкладок меняет содержимое', (tester) async {
    await pumpApp(tester);

    // Стартуем на расписании.
    expect(find.text('Базы данных'), findsWidgets);

    await openTab(tester, 'Пропуски');
    expect(find.text('часов пропущено'), findsOneWidget);
    expect(find.text('Мои справки'), findsOneWidget);

    await openTab(tester, 'Заметки');
    expect(find.text('Сдать лабораторную №3'), findsOneWidget);

    await openTab(tester, 'Профиль');
    expect(find.text('Артём Кузнецов'), findsOneWidget);
  });

  testWidgets('отметка задачи переносит её в «Выполненные»', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Заметки');

    const String task = 'Сдать лабораторную №3';
    expect(find.text(task), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Из активных задача ушла.
    expect(find.text(task), findsNothing);

    // И появилась среди выполненных.
    await tester.tap(find.text('Выполненные'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(task), findsOneWidget);
  });

  testWidgets('отправка справки добавляет её в начало списка', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Пропуски');

    expect(find.text('Новая справка'), findsNothing);

    await tester.tap(find.text('Оправдать пропуск'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Прикрепить фото справки'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Отправить'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Отправить'));
    await tester.pump();
    // Отправка занимает 900 мс, всё это время в кнопке крутится индикатор.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Новая справка'), findsOneWidget);
    expect(find.text('Отправлено только что'), findsOneWidget);
  });

  testWidgets('тумблер темы переключает ThemeMode и сохраняется', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Профиль');

    final Finder darkSwitch = find.widgetWithText(
      SwitchListTile,
      'Тёмная тема',
    );
    expect(darkSwitch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(darkSwitch).value, isFalse);

    await tester.tap(darkSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );

    // Значение уехало в SharedPreferences.
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings.dark'), isTrue);
  });
}
