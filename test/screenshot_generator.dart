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
import 'package:mitso_schedule/state/absences_controller.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitso_schedule/state/student_controller.dart';

import 'support/fake_certificate_photos.dart';
import 'support/fake_student_api.dart';
import 'support/fake_mitso_api.dart';

const String _outputDir = 'docs/screenshots';

/// Метрики Medium Phone API 36.
const Size _physicalSize = Size(1080, 2400);
const double _devicePixelRatio = 2.625;

final GlobalKey _rootKey = GlobalKey();

/// Пункты navigation bar по подписям.
const List<String> _tabs = ['Расписание', 'Заметки', 'Профиль'];
const List<String> _fileNames = ['1-schedule', '2-notes', '3-profile'];

Future<void> _pumpApp(
  WidgetTester tester, {
  required bool dark,
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
    ...preferences,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appBootProvider.overrideWith((ref) async {}),
        // Настоящая страница 2423 УИР и фиксированное время вместо сети.
        mitsoApiProvider.overrideWith((ref) async => FakeMitsoApi()),
        clockProvider.overrideWithValue(() => fakeNow),
        certificatePhotosProvider.overrideWithValue(FakeCertificatePhotos()),
        studentApiProvider.overrideWith((ref) async => FakeStudentApi()),
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
      await _pumpApp(tester, dark: dark);

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
        await _capture(tester, '${_fileNames[i]}-$theme');
      }
    });
  }

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
