// Генератор скриншотов: рендерит все четыре вкладки в светлой и тёмной теме
// и складывает PNG в docs/screenshots/.
//
//   flutter test test/screenshot_generator.dart
//
// Имя без суффикса _test.dart: обычный `flutter test` такие файлы не подхватывает,
// поэтому генератор не запускается вместе с проверками.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/data/models/student_account.dart';
import 'package:mitso_schedule/data/photo_picker.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/data/models/lesson.dart';
import 'package:mitso_schedule/features/updater/update_provider.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitso_schedule/state/student_controller.dart';

import 'support/fake_photo_picker.dart';
import 'support/fake_student_api.dart';
import 'support/fake_mitso_api.dart';

const String _outputDir = 'docs/screenshots';

/// Метрики Medium Phone API 36.
const Size _physicalSize = Size(1080, 2400);
const double _devicePixelRatio = 2.625;

final GlobalKey _rootKey = GlobalKey();

/// Фото профиля для скриншотов: кадр из арта владельца приложения.
const String _avatarPath = 'test/fixtures/avatar.png';

/// Пункты navigation bar по подписям.
const List<String> _tabs = ['Расписание', 'Заметки', 'Профиль'];
const List<String> _fileNames = ['1-schedule', '2-notes', '3-profile'];

/// Профиль на скриншотах — владельца приложения, с его фото и группой.
/// Номера счёта в кадре нет: вместо него нули.
StudentAccount _account({required double balance}) => StudentAccount(
  number: '000000',
  fullName: 'Ковалёв Денис Дмитриевич',
  balance: balance,
  debt: balance < 0 ? 60 : 0,
  penalty: balance < 0 ? 7 : 0,
  asOf: DateTime(2026, 9, 17, 23, 59),
  fetchedAt: fakeNow,
  moodle: const MoodleAccess(
    group: '2423 УИР',
    login: '000000',
    password: 'mitso2026',
  ),
);

Future<void> _pumpApp(
  WidgetTester tester, {
  required bool dark,
  double balance = 67,
  String appVersion = '1.6.0 (12)',
  List<ScheduleWeek>? weeks,
  DateTime? now,
  Map<String, Object> preferences = const {},
}) async {
  tester.view.physicalSize = _physicalSize;
  tester.view.devicePixelRatio = _devicePixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({
    'settings.dark': dark,
    'group.selected': jsonEncode(group2423.toJson()),
    // Лицевой счёт подключён: профиль на скриншотах с балансом и СДО.
    'student.number': FakeStudentApi.number,
    'profile.avatar': _avatarPath,
    // Окно «Что нового» всплывает только там, где оно и нужно.
    'app.lastSeenVersion': '1.6.0',
    ...preferences,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appBootProvider.overrideWith((ref) async {}),
        // Настоящая страница 2423 УИР и фиксированное время вместо сети.
        mitsoApiProvider.overrideWith(
          (ref) async => FakeMitsoApi(weeks: weeks),
        ),
        clockProvider.overrideWithValue(() => now ?? fakeNow),
        photoPickerProvider.overrideWithValue(FakePhotoPicker()),
        studentApiProvider.overrideWith(
          (ref) async => FakeStudentApi(account: _account(balance: balance)),
        ),
        // Версию читает плагин, которого в тестах нет.
        appVersionProvider.overrideWith((ref) async => appVersion),
        balanceAlertsProvider.overrideWithValue(FakeBalanceAlerts()),
      ],
      child: RepaintBoundary(key: _rootKey, child: const ScheduleApp()),
    ),
  );

  await tester.pump();
  await _frames(tester, 600);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary =
      _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(
      pixelRatio: _devicePixelRatio,
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) return;

    final File file = File('$_outputDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data.buffer.asUint8List());
  });
}

/// Даёт настоящему вводу-выводу прочитать и декодировать фото, затем
/// перерисовывает кадр.
Future<void> _loadImages(WidgetTester tester) async {
  // Чтение файла и декодирование идут несколькими асинхронными шагами, и
  // каждый продолжается только на кадре тестовой среды.
  for (int i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await _frames(tester, 100);
}

/// Подгружает настоящие шрифты: иначе тестовая среда рисует текст и иконки
/// заглушечными прямоугольниками и по скриншотам ничего не проверить.
Future<void> _loadFonts() async {
  final String? flutterRoot = _flutterRoot();
  if (flutterRoot != null) {
    final String dir = '$flutterRoot/bin/cache/artifacts/material_fonts';

    // Все начертания Roboto — одно семейство, как системный шрифт на Android.
    const Map<String, List<String>> families = {
      'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    };

    for (final MapEntry<String, List<String>> entry in families.entries) {
      final FontLoader loader = FontLoader(entry.key);
      for (final String name in entry.value) {
        final File file = File('$dir/$name');
        if (!file.existsSync()) continue;
        loader.addFont(
          Future.value(file.readAsBytesSync().buffer.asByteData()),
        );
      }
      await loader.load();
    }
  }

  // Шрифты иконок Material Symbols лежат внутри самого пакета — путь берём
  // из .dart_tool/package_config.json. Symbols.* по умолчанию использует
  // начертание Outlined, но регистрируем все три.
  for (final String face in ['Outlined', 'Rounded', 'Sharp']) {
    final File? font = _packageFile(
      'material_symbols_icons',
      'fonts/MaterialSymbols$face.ttf',
    );
    if (font == null) continue;
    final FontLoader loader = FontLoader(
      'packages/material_symbols_icons/MaterialSymbols$face',
    )..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

/// Находит файл внутри lib/ установленного пакета.
File? _packageFile(String package, String relativePath) {
  final File config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;

  final Map<String, dynamic> json =
      jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final dynamic entry in json['packages'] as List<dynamic>) {
    final Map<String, dynamic> p = entry as Map<String, dynamic>;
    if (p['name'] != package) continue;
    // rootUri приходит без завершающего слэша, а без него resolve() съедает
    // последний сегмент пути.
    String rootPath = p['rootUri'] as String;
    if (!rootPath.endsWith('/')) rootPath = '$rootPath/';
    final Uri root = config.absolute.parent.uri.resolve(rootPath);
    final Uri lib = root.resolve(p['packageUri'] as String);
    final File file = File.fromUri(lib.resolve(relativePath));
    return file.existsSync() ? file : null;
  }
  return null;
}

String? _flutterRoot() {
  final String? fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // dart из состава Flutter лежит в <root>/bin/cache/dart-sdk/bin/dart.
  final List<String> parts = Platform.resolvedExecutable.split(
    RegExp(r'[/\\]'),
  );
  final int index = parts.lastIndexOf('bin');
  if (index > 3) return parts.sublist(0, index - 2).join('/');
  return null;
}

/// [testWidgets] с настоящими тенями.
///
/// Тестовая среда по умолчанию рисует тени сплошными чёрными блоками. Флаг
/// проверяется сразу после тела теста, ещё до tearDown, поэтому
/// возвращается в finally.
void _shot(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

/// Кадры шагами по 50 мс: пружинные анимации стартуют после раскладки.
Future<void> _frames(WidgetTester tester, int milliseconds) async {
  for (int t = 0; t < milliseconds; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await _loadFonts();
  });

  for (final bool dark in [false, true]) {
    final String theme = dark ? 'dark' : 'light';

    _shot('скриншоты вкладок — $theme', (tester) async {
      // Светлая тема — баланс в плюсе, тёмная — долг: в README видно оба
      // состояния карточки счёта.
      await _pumpApp(tester, dark: dark, balance: dark ? -67 : 67);

      for (int i = 0; i < _tabs.length; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(M3NavigationBar),
            matching: find.text(_tabs[i]),
          ),
        );
        await tester.pump();
        await _frames(tester, 500);
        await _frames(tester, 500);
        // Фото профиля читается с диска — даём ему декодироваться.
        await _loadImages(tester);
        await _capture(tester, '${_fileNames[i]}-$theme');
      }
    });
  }

  _shot('скриншот зачёта и экзамена', (tester) async {
    Lesson lesson(String start, String end, String title, LessonType type) =>
        Lesson(
          start: start,
          end: end,
          title: title,
          type: type,
          typeLabel: type.label,
          teacher: 'Гардейчик С. М.',
          room: '71',
        );

    await _pumpApp(
      tester,
      dark: false,
      weeks: [
        ScheduleWeek(
          label: 'Текущая неделя',
          days: [
            ScheduleDay(
              date: fakeNow,
              lessons: [
                lesson('09:45', '11:05', 'Системы баз данных', LessonType.exam),
                lesson('11:15', '12:35', 'Маркетинг', LessonType.credit),
                lesson(
                  '13:05',
                  '14:25',
                  'Эконометрика',
                  LessonType.consultation,
                ),
                lesson(
                  '14:35',
                  '15:55',
                  'Веб-дизайн и шаблоны проектирования',
                  LessonType.lecture,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await _frames(tester, 900);
    await _capture(tester, '14-assessments-light');
  });

  // Неделя преподавателя: группы, окно между парами, компьютерный класс.
  List<ScheduleWeek> teacherWeeks() {
    Lesson lesson(
      String start,
      String end,
      String title,
      String group, {
      String room = '71',
      LessonType type = LessonType.lecture,
    }) => Lesson(
      start: start,
      end: end,
      title: title,
      type: type,
      typeLabel: type.label,
      group: group,
      room: room,
    );

    return [
      ScheduleWeek(
        label: 'Текущая неделя',
        days: [
          ScheduleDay(
            date: fakeNow,
            lessons: [
              lesson('09:45', '11:05', 'Системы баз данных', '2423 УИР'),
              lesson(
                '13:05',
                '14:25',
                'Системы баз данных',
                '2343 МП',
                room: '62 (к)',
                type: LessonType.lab,
              ),
              lesson('14:35', '15:55', 'Маркетинг', '2421 ИСИТ'),
            ],
          ),
          ScheduleDay(
            date: fakeNow.add(const Duration(days: 1)),
            lessons: [
              lesson('09:45', '11:05', 'Маркетинг', '2423 УИР'),
              lesson('11:15', '12:35', 'Эконометрика', '2343 МП'),
            ],
          ),
          ScheduleDay(
            date: fakeNow.add(const Duration(days: 2)),
            lessons: const [],
          ),
        ],
      ),
    ];
  }

  _shot('скриншот дня преподавателя', (tester) async {
    await _pumpApp(
      tester,
      dark: false,
      weeks: teacherWeeks(),
      preferences: {
        'schedule.target': '{"kind":"teacher","name":"Сысун В. В."}',
      },
    );
    await _frames(tester, 900);
    await _capture(tester, '17-teacher-day-light');
  });

  _shot('скриншот нагрузки преподавателя', (tester) async {
    await _pumpApp(
      tester,
      dark: false,
      weeks: teacherWeeks(),
      preferences: {
        'schedule.target': '{"kind":"teacher","name":"Сысун В. В."}',
      },
    );
    await tester.tap(
      find.descendant(
        of: find.byType(M3NavigationBar),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pump();
    await _frames(tester, 700);
    await _loadImages(tester);
    await _capture(tester, '18-teacher-load-light');
  });

  // Хэллоуин целиком: каждая вкладка и настройки, светлая и тёмная тема.
  for (final bool halloweenDark in [false, true]) {
    final String theme = halloweenDark ? 'dark' : 'light';
    _shot('хэллоуин целиком — $theme', (tester) async {
      final DateTime day = DateTime(2026, 10, 30, 10, 30);
      Lesson lesson(String start, String end, String title, String room) =>
          Lesson(
            start: start,
            end: end,
            title: title,
            type: LessonType.lecture,
            typeLabel: LessonType.lecture.label,
            teacher: 'Гардейчик С. М.',
            room: room,
          );
      String task(String id, String text, String? subject, int dueDay) =>
          '{"id":"$id","text":"$text","subject":${subject == null ? 'null' : '"$subject"'},'
          '"dueAt":"2026-10-${dueDay.toString().padLeft(2, '0')}T00:00:00.000","isDone":false}';
      await _pumpApp(
        tester,
        dark: halloweenDark,
        now: day,
        preferences: {
          'tasks.items':
              '[${task('1', 'Лабораторная по базам данных', 'Системы баз данных', 30)},'
              '${task('2', 'Купить тетради', null, 30)},'
              '${task('3', 'Доклад по маркетингу', 'Маркетинг', 31)}]',
        },
        weeks: [
          ScheduleWeek(
            label: 'Текущая неделя',
            days: [
              ScheduleDay(
                date: day,
                lessons: [
                  lesson('09:45', '11:05', 'Системы баз данных', '62 (к)'),
                  lesson('11:15', '12:35', 'Маркетинг', '71'),
                  lesson('13:05', '14:25', 'Эконометрика', '71'),
                ],
              ),
              ScheduleDay(
                date: day.add(const Duration(days: 1)),
                lessons: [lesson('09:45', '11:05', 'Маркетинг', '71')],
              ),
            ],
          ),
        ],
      );
      await _frames(tester, 1500);
      for (int i = 0; i < _tabs.length; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(M3NavigationBar),
            matching: find.text(_tabs[i]),
          ),
        );
        await tester.pump();
        await _frames(tester, 900);
        await _loadImages(tester);
        await _capture(tester, '22-halloween-${_fileNames[i]}-$theme');
      }
      await tester.tap(find.byTooltip('Настройки'));
      await tester.pump();
      await _frames(tester, 900);
      // Образцы значков приложения — картинки из ассетов.
      await _loadImages(tester);
      await _capture(tester, '22-halloween-4-settings-$theme');
    });
  }

  // Пустые экраны Хэллоуина: день без пар и заметки без задач — кот в тыкве
  // на месте фигур.
  for (final bool emptyDark in [false, true]) {
    final String theme = emptyDark ? 'dark' : 'light';
    _shot('хэллоуин пусто — $theme', (tester) async {
      final DateTime day = DateTime(2026, 10, 30, 10, 30);
      await _pumpApp(
        tester,
        dark: emptyDark,
        now: day,
        weeks: [
          ScheduleWeek(
            label: 'Текущая неделя',
            days: [
              ScheduleDay(date: day, lessons: const []),
              ScheduleDay(
                date: day.add(const Duration(days: 1)),
                lessons: [
                  Lesson(
                    start: '09:45',
                    end: '11:05',
                    title: 'Маркетинг',
                    type: LessonType.lecture,
                    typeLabel: LessonType.lecture.label,
                    teacher: 'Гардейчик С. М.',
                    room: '71',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await _frames(tester, 1500);
      for (int i = 0; i < 2; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(M3NavigationBar),
            matching: find.text(_tabs[i]),
          ),
        );
        await tester.pump();
        await _frames(tester, 900);
        await _loadImages(tester);
        await _capture(tester, '23-halloween-empty-${_fileNames[i]}-$theme');
      }
    });
  }

  // Каждый сезон в обеих темах: один и тот же день, чтобы сравнивать.
  final List<(String, DateTime)> seasonDays = [
    ('halloween', DateTime(2026, 10, 30, 10, 30)),
    ('new-year', DateTime(2026, 12, 25, 10, 30)),
    ('spring', DateTime(2027, 3, 4, 10, 30)),
    ('first-bell', DateTime(2026, 9, 2, 10, 30)),
  ];
  for (final (String id, DateTime day) in seasonDays) {
    for (final bool seasonDark in [false, true]) {
      _shot('скриншот сезона $id — ${seasonDark ? 'dark' : 'light'}', (
        tester,
      ) async {
        Lesson lesson(String start, String end, String title, String room) =>
            Lesson(
              start: start,
              end: end,
              title: title,
              type: LessonType.lecture,
              typeLabel: LessonType.lecture.label,
              teacher: 'Гардейчик С. М.',
              room: room,
            );

        await _pumpApp(
          tester,
          dark: seasonDark,
          now: day,
          weeks: [
            ScheduleWeek(
              label: 'Текущая неделя',
              days: [
                ScheduleDay(
                  date: day,
                  lessons: [
                    lesson('09:45', '11:05', 'Системы баз данных', '62 (к)'),
                    lesson('11:15', '12:35', 'Маркетинг', '71'),
                    lesson('13:05', '14:25', 'Эконометрика', '71'),
                  ],
                ),
                ScheduleDay(
                  date: day.add(const Duration(days: 1)),
                  lessons: [lesson('09:45', '11:05', 'Маркетинг', '71')],
                ),
              ],
            ),
          ],
        );
        await _frames(tester, 1500);
        await _capture(
          tester,
          '19-season-$id-${seasonDark ? 'dark' : 'light'}',
        );
      });
    }
  }

  _shot('скриншот «Что нового»', (tester) async {
    await _pumpApp(
      tester,
      dark: false,
      preferences: {'app.lastSeenVersion': '1.4.0'},
    );
    await _frames(tester, 900);
    await _loadImages(tester);
    await _capture(tester, '13-whats-new-light');
  });

  _shot('скриншот пустого дня — суббота', (tester) async {
    await _pumpApp(tester, dark: false);
    await tester.tap(find.text('Сб').first);
    await tester.pump();
    await _frames(tester, 600);
    await _capture(tester, '5-empty-saturday-light');
  });

  _shot('скриншот объединённых подгрупп', (tester) async {
    await _pumpApp(tester, dark: false);
    // Прокрутка до пар: app bar свёрнут в small.
    final ScrollableState list = tester.state(find.byType(Scrollable).first);
    list.position.jumpTo(360);
    await _frames(tester, 300);
    await _capture(tester, '7-subgroups-light');
  });

  _shot('скриншот настроек', (tester) async {
    await _pumpApp(tester, dark: false);
    await tester.tap(
      find.descendant(
        of: find.byType(M3NavigationBar),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pump();
    await _frames(tester, 600);
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pump();
    await _frames(tester, 600);
    await _loadImages(tester);
    await _capture(tester, '10-settings-light');
  });

  _shot('скриншот экрана уведомлений', (tester) async {
    await _pumpApp(
      tester,
      dark: false,
      preferences: {'settings.lessonReminders': true},
    );
    await tester.tap(
      find.descendant(
        of: find.byType(M3NavigationBar),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pump();
    await _frames(tester, 600);
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pump();
    await _frames(tester, 600);
    await tester.tap(find.text('Уведомления').last);
    await tester.pump();
    await _frames(tester, 700);
    await _capture(tester, '15-notifications-light');
  });

  _shot('скриншот подробностей пары', (tester) async {
    await _pumpApp(tester, dark: false);
    final ScrollableState list = tester.state(find.byType(Scrollable).first);
    list.position.jumpTo(300);
    await _frames(tester, 300);
    await tester.tap(find.text('СЕЙЧАС ИДЁТ'));
    await tester.pump();
    await _frames(tester, 700);
    await _capture(tester, '8-lesson-details-light');
  });
}
