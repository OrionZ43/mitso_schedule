import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:mitso_schedule/widgets/m3_buttons.dart';
import 'package:mitso_schedule/widgets/m3_checkbox.dart';
import 'package:mitso_schedule/widgets/m3_fab.dart';
import 'package:mitso_schedule/widgets/segmented_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_mitso_api.dart';

/// Поднимает приложение целиком.
///
/// Сайт подменён [FakeMitsoApi] с настоящей страницей 2423 УИР, время
/// зафиксировано на [fakeNow]. `pumpAndSettle` не применяется: индикатор
/// загрузки, волнистая шкала и пульсирующая точка анимируются бесконечно,
/// поэтому кадры прокручиваются явными [WidgetTester.pump].
Future<FakeMitsoApi> pumpApp(
  WidgetTester tester, {
  bool withGroup = true,
  FakeMitsoApi? api,
  Map<String, Object> preferences = const {},
}) async {
  // По умолчанию тестовый экран 800x600 — это не телефон. Берём метрики
  // Medium Phone API 36: 1080x2400 при плотности 2.625.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({
    if (withGroup) 'group.selected': jsonEncode(group2423.toJson()),
    ...preferences,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final FakeMitsoApi fake = api ?? FakeMitsoApi();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appBootProvider.overrideWith((ref) async {}),
        mitsoApiProvider.overrideWith((ref) async => fake),
        clockProvider.overrideWithValue(() => fakeNow),
      ],
      child: const ScheduleApp(),
    ),
  );

  // Экран загрузки -> главный экран, расписание разобрано.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 100));
  return fake;
}

/// Переход на вкладку по подписи в navigation bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(M3NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
  // Переход fade through 450 мс, затем появление FAB раздела.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  // Шагами: пружинные анимации листов стартуют после первой раскладки.
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('переключение вкладок меняет содержимое', (tester) async {
    await pumpApp(tester);

    // Стартуем на расписании: реальные пары среды 16 сентября.
    expect(find.text('Веб-дизайн и шаблоны проектирования'), findsWidgets);

    await openTab(tester, 'Пропуски');
    expect(find.text('часов пропущено'), findsOneWidget);

    await openTab(tester, 'Заметки');
    expect(find.textContaining('Дедлайнов пока нет'), findsOneWidget);

    await openTab(tester, 'Профиль');
    expect(find.text('2423 УИР'), findsOneWidget);
    expect(find.textContaining('Экономический'), findsOneWidget);
  });

  testWidgets('открывается сегодняшний день, идущая пара отмечена', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('среда, 16 сентября'), findsOneWidget);
    // Лаба подгрупп в 11:15 — одна пара, а не две.
    expect(find.text('4 пары'), findsOneWidget);
    // 10:30 — идёт вторая пара, 09:45–11:05.
    expect(find.text('Идёт сейчас · осталось 35 мин'), findsOneWidget);
    // Следующая — в 11:15.
    expect(find.text('Начнётся через 45 мин'), findsOneWidget);
  });

  testWidgets('подгруппы в одно время — одна пара', (tester) async {
    await pumpApp(tester);

    // Вертикальный список дня; внутри есть и горизонтальная лента дней.
    await tester.scrollUntilVisible(
      find.textContaining('Пархимович А. В.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final Finder item = find.ancestor(
      of: find.textContaining('Пархимович А. В.'),
      matching: find.byType(M3ListItem),
    );
    expect(item, findsOneWidget);
    expect(
      find.descendant(
        of: item,
        matching: find.text('1 подгруппа · Калинин М. А. · ауд. 62 (к)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: item,
        matching: find.text('2 подгруппа · Пархимович А. В. · ауд. 63 (к)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('своя подгруппа скрывает строки другой', (tester) async {
    await pumpApp(tester, preferences: {'settings.subgroup': 1});

    await tester.scrollUntilVisible(
      find.text('Лаб · 1 подгруппа'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Пархимович А. В.'), findsNothing);
    expect(find.text('4 пары'), findsOneWidget);
  });

  testWidgets('свайп по списку пар листает дни', (tester) async {
    await pumpApp(tester);

    await tester.fling(find.text('Сегодня'), const Offset(-300, 0), 1200);
    await settle(tester);
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Сегодня'), findsNothing);

    await tester.fling(find.text('Завтра'), const Offset(300, 0), 1200);
    await settle(tester);
    expect(find.text('Сегодня'), findsOneWidget);
  });

  testWidgets('пара открывает страницу подробностей', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Идёт сейчас · осталось 35 мин'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Преподаватель и аудитория'), findsOneWidget);
    expect(find.text('Идёт сейчас · осталось 35 мин'), findsOneWidget);
    expect(find.text('Дальше по предмету'), findsOneWidget);

    // Следующее занятие по предмету — лаба в 11:15 того же дня.
    await tester.tap(find.text('Ср, 16 сентября · 11:15'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Дальше по предмету'), findsNothing);
    expect(find.text('Сегодня'), findsOneWidget);
  });

  testWidgets('без группы: выбор по цепочке факультет → курс → группа', (
    tester,
  ) async {
    final FakeMitsoApi api = await pumpApp(tester, withGroup: false);
    expect(find.text('Выберите группу'), findsOneWidget);
    expect(api.scheduleRequests, 0);

    await tester.tap(find.widgetWithText(M3Button, 'Выбрать группу'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Факультет'), findsOneWidget);

    for (final (String option, String nextStep) in [
      ('Экономический', 'Форма обучения'),
      ('Дневная', 'Курс'),
      ('3 курс', 'Группа'),
    ]) {
      // Лист открыт на половину экрана — пункт может быть ниже, его
      // прокручивают в видимую часть.
      await tester.ensureVisible(find.text(option));
      await settle(tester);
      await tester.tap(find.text(option));
      await settle(tester);
      expect(find.text(nextStep), findsOneWidget);
    }

    await tester.ensureVisible(find.text('2423 УИР'));
    await settle(tester);
    await tester.tap(find.text('2423 УИР'));
    await settle(tester);
    await settle(tester);

    expect(api.scheduleRequests, 1);
    expect(find.text('Веб-дизайн и шаблоны проектирования'), findsWidgets);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('group.selected'), contains('2423 UIR'));
  });

  testWidgets('сайт недоступен и кэша нет — ошибка с повтором', (tester) async {
    await pumpApp(tester, api: FakeMitsoApi(failSchedule: true));

    expect(find.text('Не удалось загрузить расписание'), findsOneWidget);
    expect(find.text('Нет соединения с сайтом расписания.'), findsOneWidget);
    expect(find.widgetWithText(M3Button, 'Повторить'), findsOneWidget);
  });

  testWidgets('добавленная задача уходит в «Выполненные» после отметки', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Заметки');

    await tester.tap(find.byType(M3Fab));
    await settle(tester);
    expect(find.text('Новая задача'), findsOneWidget);

    await tester.tap(find.byType(M3Checkbox).first);
    await settle(tester);
    expect(find.text('Новая задача'), findsNothing);

    await tester.tap(find.text('Выполненные'));
    await settle(tester);
    expect(find.text('Новая задача'), findsOneWidget);
  });

  testWidgets('отправка справки добавляет её в начало списка', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Пропуски');

    expect(find.text('Новая справка'), findsNothing);

    await tester.tap(find.text('Оправдать пропуск'));
    await tester.pump();
    // Анимация листа стартует после первой раскладки — кадры по 100 мс.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.widgetWithText(M3Button, 'Отправить'), findsOneWidget);

    await tester.tap(find.widgetWithText(M3Button, 'Отправить'));
    await tester.pump();
    // Отправка занимает 900 мс, всё это время в кнопке крутится индикатор.
    await tester.pump(const Duration(milliseconds: 1000));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Новая справка'), findsOneWidget);
    expect(find.textContaining('Отправлено только что'), findsOneWidget);
  });

  testWidgets('интерфейс переживает масштаб шрифта 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    // Любое переполнение раскладки в тестах прилетает исключением.
    for (final String tab in ['Пропуски', 'Заметки', 'Профиль', 'Расписание']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: 'вкладка «$tab»');
    }
  });

  testWidgets('выбор темы переключает ThemeMode и сохраняется', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Профиль');

    await tester.tap(find.text('Тёмная'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      Theme.of(tester.element(find.byType(M3NavigationBar))).brightness,
      Brightness.dark,
    );

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings.dark'), isTrue);

    // «Системная» снимает явный выбор.
    await tester.tap(find.text('Системная'));
    await tester.pump();
    expect(preferences.getBool('settings.dark'), isNull);
  });
}
