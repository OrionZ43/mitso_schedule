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
import 'package:google_fonts/google_fonts.dart';
import 'package:mitso_schedule/app.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _outputDir = 'docs/screenshots';

/// Метрики Medium Phone API 36.
const Size _physicalSize = Size(1080, 2400);
const double _devicePixelRatio = 2.625;

final GlobalKey _rootKey = GlobalKey();

/// Центры четырёх пунктов navigation bar по подписям.
const List<String> _tabs = ['Расписание', 'Пропуски', 'Заметки', 'Профиль'];
const List<String> _fileNames = [
  '1-schedule',
  '2-absences',
  '3-notes',
  '4-profile',
];

Future<void> _pumpApp(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = _physicalSize;
  tester.view.devicePixelRatio = _devicePixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({'settings.dark': dark});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appBootProvider.overrideWith((ref) async {}),
      ],
      child: RepaintBoundary(key: _rootKey, child: const ScheduleApp()),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
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

    final Directory dir = Directory(_outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_outputDir/$name.png').writeAsBytesSync(data.buffer.asUint8List());
  });
}

/// Подгружает настоящие шрифты: иначе тестовая среда рисует текст и иконки
/// заглушечными прямоугольниками и по скриншотам ничего не проверить.
Future<void> _loadFonts() async {
  final String? flutterRoot = _flutterRoot();
  if (flutterRoot != null) {
    final String dir = '$flutterRoot/bin/cache/artifacts/material_fonts';

    // google_fonts запрашивает семейства с суффиксом начертания
    // (Roboto_regular / Roboto_500 / Roboto_700), поэтому настоящий Roboto
    // регистрируется именно под этими именами, плюс под 'Roboto' —
    // так резолвится и запасное семейство из AppTypography.
    const Map<String, String> families = {
      'Roboto': 'roboto-regular.ttf',
      'Roboto_regular': 'roboto-regular.ttf',
      'Roboto_500': 'roboto-medium.ttf',
      'Roboto_700': 'roboto-bold.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    };

    for (final MapEntry<String, String> entry in families.entries) {
      final File file = File('$dir/${entry.value}');
      if (!file.existsSync()) continue;
      final FontLoader loader = FontLoader(entry.key)
        ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
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

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  for (final bool dark in [false, true]) {
    final String theme = dark ? 'dark' : 'light';

    testWidgets('скриншоты вкладок — $theme', (tester) async {
      await _pumpApp(tester, dark: dark);

      for (int i = 0; i < _tabs.length; i++) {
        await tester.tap(find.widgetWithText(NavigationDestination, _tabs[i]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _capture(tester, '${_fileNames[i]}-$theme');
      }
    });
  }

  testWidgets('скриншот пустого дня — суббота', (tester) async {
    await _pumpApp(tester, dark: false);
    await tester.tap(find.text('Сб'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, '5-empty-saturday-light');
  });

  testWidgets('скриншот шита отправки справки', (tester) async {
    await _pumpApp(tester, dark: false);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Пропуски'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Оправдать пропуск'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, '6-certificate-sheet-light');
  });
}
