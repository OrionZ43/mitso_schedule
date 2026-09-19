import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/data/certificate_photos.dart';
import 'package:mitso_schedule/features/absences/widgets/absence_donut.dart';
import 'package:mitso_schedule/features/schedule/lesson_card.dart';
import 'package:mitso_schedule/features/updater/update_provider.dart';
import 'package:mitso_schedule/state/absences_controller.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:mitso_schedule/widgets/m3_buttons.dart';
import 'package:mitso_schedule/widgets/m3_checkbox.dart';
import 'package:mitso_schedule/widgets/m3_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitso_schedule/state/student_controller.dart';

import 'support/fake_certificate_photos.dart';
import 'support/fake_student_api.dart';
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
  CertificatePhotos? photos,
  FakeStudentApi? student,
  FakeBalanceAlerts? alerts,
  Map<String, Object> preferences = const {},
  List<Override> overrides = const [],
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
        certificatePhotosProvider.overrideWithValue(
          photos ?? FakeCertificatePhotos(),
        ),
        studentApiProvider.overrideWith(
          (ref) async => student ?? FakeStudentApi(),
        ),
        balanceAlertsProvider.overrideWithValue(alerts ?? FakeBalanceAlerts()),
        // Версия читается плагином из платформы, которой в тестах нет.
        appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
        ...overrides,
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

/// Нажатие в нижнем листе: содержимое длиннее экрана и строится по мере
/// прокрутки, поэтому элемент сначала выводится в видимую часть.
Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
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
    expect(find.text('Справок пока нет'), findsOneWidget);

    await openTab(tester, 'Заметки');
    expect(find.textContaining('Задач нет'), findsOneWidget);

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
    expect(find.text('СЕЙЧАС ИДЁТ'), findsOneWidget);
    expect(find.text('осталось 35 мин'), findsOneWidget);
    // Следующая — в 11:15.
    expect(find.text('Начнётся через 45 мин'), findsOneWidget);
  });

  testWidgets('подгруппы в одно время — одна карточка', (tester) async {
    await pumpApp(tester);

    // Вертикальный список дня; внутри есть и горизонтальная лента дней.
    await tester.scrollUntilVisible(
      find.text('Пархимович А. В.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final Finder card = find.ancestor(
      of: find.text('Пархимович А. В.'),
      matching: find.byType(LessonCard),
    );
    expect(card, findsOneWidget);
    for (final String text in ['Калинин М. А.', '62 (к)', '63 (к)']) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: card,
        matching: find.bySemanticsLabel(
          '2 подгруппа · Пархимович А. В. · ауд. 63 (к)',
        ),
      ),
      findsOneWidget,
    );
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

  testWidgets('переключатель недель открывает тот же день следующей недели', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Эта неделя'), findsOneWidget);
    expect(find.text('14–19 сентября'), findsOneWidget);

    await tester.tap(find.text('Следующая'));
    await settle(tester);
    await settle(tester);
    expect(find.text('21–26 сентября'), findsOneWidget);
    expect(find.text('23 сентября'), findsOneWidget);

    // Обратно — сегодняшний день.
    await tester.tap(find.text('Эта неделя'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Сегодня'), findsOneWidget);
  });

  testWidgets('свайп с субботы на понедельник переключает неделю', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Сб'));
    await settle(tester);
    await settle(tester);
    await tester.fling(find.text('19 сентября'), const Offset(-300, 0), 1200);
    await settle(tester);
    await settle(tester);

    expect(find.text('21–26 сентября'), findsOneWidget);
    expect(find.text('21 сентября'), findsOneWidget);
  });

  testWidgets('поиск из app bar находит пару и открывает её день', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Поиск по расписанию'));
    await settle(tester);
    await tester.tap(find.text('Преподаватели'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Лукашевич');
    await settle(tester);

    // Эконометрика — пятница 18 и 25 сентября.
    final Finder result = find.textContaining('Пт, 25 сентября');
    expect(result, findsWidgets);
    await tester.tap(result.first);
    await settle(tester);
    await settle(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('21–26 сентября'), findsOneWidget);
    expect(find.text('25 сентября'), findsOneWidget);
  });

  testWidgets('пара открывает страницу подробностей', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('СЕЙЧАС ИДЁТ'));
    await settle(tester);
    await tester.tap(find.text('СЕЙЧАС ИДЁТ'));
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

  testWidgets('задача со сроком «Завтра» попадает в свой раздел и в память', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Заметки');

    await tester.tap(find.byType(M3Fab));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Сдать лабораторную');
    await settle(tester);
    await tapInSheet(tester, find.text('Завтра'));
    // Предмет — из загруженного расписания.
    await tapInSheet(tester, find.text('Эконометрика'));
    await tapInSheet(tester, find.text('Добавить'));

    expect(find.text('Завтра'), findsWidgets);
    expect(find.text('Сдать лабораторную'), findsOneWidget);
    expect(find.text('Эконометрика · Завтра'), findsOneWidget);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('tasks.items'),
      contains('Сдать лабораторную'),
    );
  });

  testWidgets('отмеченная задача уходит в «Выполненные»', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Заметки');

    await tester.tap(find.byType(M3Fab));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Прочитать главу');
    await settle(tester);
    await tapInSheet(tester, find.text('Добавить'));
    expect(find.text('Без срока'), findsOneWidget);

    await tester.tap(find.byType(M3Checkbox).first);
    await settle(tester);
    expect(find.text('Прочитать главу'), findsNothing);

    await tester.tap(find.text('Выполненные'));
    await settle(tester);
    expect(find.text('Прочитать главу'), findsOneWidget);
  });

  testWidgets('просроченная задача — первым разделом и красным', (
    tester,
  ) async {
    await pumpApp(
      tester,
      preferences: {
        'tasks.items': jsonEncode([
          {
            'id': '1',
            'text': 'Отдать конспект',
            'subject': 'Эконометрика',
            'dueAt': DateTime(2026, 9, 14).toIso8601String(),
            'isDone': false,
          },
        ]),
      },
    );
    await openTab(tester, 'Заметки');

    expect(find.text('Просрочено'), findsOneWidget);
    expect(find.text('Эконометрика · 14 сентября'), findsOneWidget);
    expect(find.textContaining('просрочена'), findsWidgets);
  });

  testWidgets('нажатие на задачу открывает правку, удаление убирает её', (
    tester,
  ) async {
    await pumpApp(
      tester,
      preferences: {
        'tasks.items': jsonEncode([
          {
            'id': '1',
            'text': 'Отдать конспект',
            'subject': null,
            'dueAt': null,
            'isDone': false,
          },
        ]),
      },
    );
    await openTab(tester, 'Заметки');

    await tester.tap(find.text('Отдать конспект'));
    await settle(tester);
    expect(find.text('Задача'), findsOneWidget);

    await tapInSheet(tester, find.text('Удалить'));
    expect(find.text('Отдать конспект'), findsNothing);
  });

  /// Открывает лист регистрации пропуска на вкладке «Пропуски».
  Future<void> openCertificateSheet(WidgetTester tester) async {
    await openTab(tester, 'Пропуски');
    await tester.tap(find.text('Зарегистрировать пропуск'));
    await tester.pump();
    // Анимация листа стартует после первой раскладки — кадры по 100 мс.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('снятая справка сохраняется в список и в настройки', (
    tester,
  ) async {
    final FakeCertificatePhotos photos = FakeCertificatePhotos();
    await pumpApp(tester, photos: photos);
    await openCertificateSheet(tester);

    // Без фото сохранять нечего.
    final Finder save = find.widgetWithText(M3Button, 'Сохранить');
    expect(tester.widget<M3Button>(save).onPressed, isNull);

    await tester.tap(find.text('Сфотографировать'));
    await settle(tester);
    expect(photos.captures, [CertificatePhotoSource.camera]);
    expect(find.text('Переснять'), findsOneWidget);
    expect(tester.widget<M3Button>(save).onPressed, isNotNull);

    await tester.tap(save);
    await settle(tester);

    expect(find.text('Справок пока нет'), findsNothing);
    expect(find.text('Не отправлено'), findsOneWidget);
    expect(find.text('Сохранена 16 сентября, 10:30'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Object?> saved =
        jsonDecode(prefs.getString('absences.certificates')!) as List<Object?>;
    expect(saved, hasLength(1));
    expect(
      (saved.single! as Map<String, Object?>)['photoPath'],
      '/fake/certificate.jpg',
    );
  });

  testWidgets('сохранённые справки показываются после перезапуска', (
    tester,
  ) async {
    await pumpApp(
      tester,
      preferences: {
        'absences.certificates': jsonEncode([
          {
            'id': '1',
            'photoPath': '/fake/old.jpg',
            'createdAt': DateTime(2026, 9, 12, 18, 24).toIso8601String(),
            'status': 'notSent',
          },
        ]),
      },
    );
    await openTab(tester, 'Пропуски');

    expect(find.text('Мои справки'), findsOneWidget);
    expect(find.text('Сохранена 12 сентября, 18:24'), findsOneWidget);
  });

  testWidgets('недоступная камера — сообщение в листе', (tester) async {
    await pumpApp(tester, photos: FakeCertificatePhotos(failCapture: true));
    await openCertificateSheet(tester);

    await tester.tap(find.text('Сфотографировать'));
    await settle(tester);

    expect(find.text('Не удалось открыть камеру.'), findsOneWidget);
    expect(find.text('Сфотографировать'), findsOneWidget);
  });

  testWidgets('отказ от снимка оставляет лист без фото', (tester) async {
    await pumpApp(tester, photos: FakeCertificatePhotos(photoPath: null));
    await openCertificateSheet(tester);

    await tester.tap(find.text('Выбрать из галереи'));
    await settle(tester);

    expect(find.text('Выбрать из галереи'), findsOneWidget);
    expect(
      tester
          .widget<M3Button>(find.widgetWithText(M3Button, 'Сохранить'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('диаграмма пропусков — без лимита', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AbsenceDonut(justifiedHours: 8, unjustifiedHours: 6),
        ),
      ),
    );

    expect(find.text('14'), findsOneWidget);
    expect(find.text('часов пропущено'), findsOneWidget);
    expect(find.textContaining('лимит'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Пропущено 14 часов. По справке 8 часов, без справки 6 часов.',
      ),
      findsOneWidget,
    );
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

  /// Открывает настройки из профиля.
  Future<void> openSettings(WidgetTester tester) async {
    await openTab(tester, 'Профиль');
    await tester.tap(find.byTooltip('Настройки'));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('лицевой счёт подключается и показывает долг', (tester) async {
    final FakeStudentApi api = FakeStudentApi();
    final FakeBalanceAlerts alerts = FakeBalanceAlerts();
    await pumpApp(tester, student: api, alerts: alerts);
    await openTab(tester, 'Профиль');

    expect(find.text('Баланс и доступ к СДО'), findsOneWidget);
    await tester.tap(find.widgetWithText(M3Button, 'Подключить'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), FakeStudentApi.number);
    await settle(tester);
    await tester.tap(find.widgetWithText(M3Button, 'Подключить').last);
    await settle(tester);
    await settle(tester);

    expect(api.requests, [FakeStudentApi.number]);
    expect(find.textContaining('12,34'), findsWidgets);
    expect(find.text('Есть задолженность'), findsOneWidget);
    expect(find.text('Иванов Иван Иванович'), findsOneWidget);

    // Долг появился — уведомление.
    expect(alerts.shown, hasLength(1));

    // Номер счёта сохранён: после перезапуска данные возьмутся из кэша.
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('student.number'), FakeStudentApi.number);
    expect(preferences.getString('student.cache'), contains('Иванов'));
  });

  testWidgets('пароль СДО скрыт, нажатие показывает', (tester) async {
    await pumpApp(
      tester,
      preferences: {'student.number': FakeStudentApi.number},
    );
    await openTab(tester, 'Профиль');
    await settle(tester);

    expect(find.text('Дистанционное обучение'), findsOneWidget);
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('12345678'), findsNothing);

    await tester.ensureVisible(find.text('••••••••'));
    await settle(tester);
    await tester.tap(find.text('••••••••'));
    await settle(tester);
    expect(find.text('12345678'), findsOneWidget);
  });

  testWidgets('счёт отключается из настроек', (tester) async {
    await pumpApp(
      tester,
      preferences: {'student.number': FakeStudentApi.number},
    );
    await openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('Отключить счёт'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text('Отключить счёт'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Отключить'));
    await settle(tester);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('student.number'), isNull);
    expect(find.text('Отключить счёт'), findsNothing);
  });

  testWidgets('значок приложения переключается из настроек', (tester) async {
    final List<MethodCall> calls = [];
    const MethodChannel channel = MethodChannel('mitso/app_icon');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'current' ? '' : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await pumpApp(tester);
    await openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('Значок приложения'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Значок «Шапка»'));
    await settle(tester);

    expect(calls.last.method, 'select');
    expect(calls.last.arguments, {'name': 'cap'});
    expect(find.textContaining('Значок сменится в лаунчере'), findsOneWidget);
  });

  testWidgets('выбор темы переключает ThemeMode и сохраняется', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);

    await tester.tap(find.text('Тёмная'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      Theme.of(tester.element(find.text('Тёмная'))).brightness,
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
