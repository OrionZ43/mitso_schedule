// Генератор иконки приложения: рисует варианты и складывает PNG в
// docs/icon/. Имя без суффикса _test.dart — обычный `flutter test` его не
// запускает.
//
//   flutter test test/icon_generator.dart
//
// Геометрия — по adaptive icons Android: слой 108dp, видно 72dp, безопасная
// зона — круг 66dp (https://developer.android.com/develop/ui/views/launch/
// icon_design_adaptive). Здесь холст 432 px = 108dp @xxxhdpi.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Холст адаптивной иконки.
const double canvas = 432;

/// Безопасная зона: круг 66 из 108.
const double safe = canvas * 66 / 108;

/// Что видно под маской: 72 из 108.
const double visible = canvas * 72 / 108;

/// Базовая палитра приложения (`AppPalette.baseline` = эталонная схема M3).
const Color primary = Color(0xFF6750A4);
const Color onPrimary = Color(0xFFFFFFFF);
const Color primaryContainer = Color(0xFFEADDFF);
const Color onPrimaryContainer = Color(0xFF21005D);

typedef IconPainter = void Function(Canvas canvas, Size size);

/// Рисует значок Material Symbols по центру [center] размером [size].
void _symbol(
  Canvas c, {
  required IconData icon,
  required Offset center,
  required double size,
  required Color color,
  double fill = 1,
  BlendMode blendMode = BlendMode.srcOver,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        height: 1,
        fontVariations: [FontVariation('FILL', fill)],
        // Цвет через foreground: так доступен blendMode для выреза в
        // монохромном слое.
        foreground: Paint()
          ..color = color
          ..blendMode = blendMode,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(c, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}

/// 6. Печенька с шапкой выпускника.
void iconCookieCap(Canvas c, Size size) {
  _background(c, primary);
  final Rect rect = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawPath(
    _shapePath(MaterialShapes.cookie9Sided, rect),
    Paint()..color = onPrimary,
  );
  _symbol(
    c,
    icon: Symbols.school,
    center: rect.center,
    size: safe * 0.52,
    color: primary,
  );
}

/// 7. Крупная шапка на фоне, без подложки.
void iconCapPlain(Canvas c, Size size) {
  _background(c, primary);
  _symbol(
    c,
    icon: Symbols.school,
    center: const Offset(canvas / 2, canvas / 2),
    size: safe * 0.86,
    color: onPrimary,
  );
}

/// 8. Шапка над волной прогресса.
void iconCapWave(Canvas c, Size size) {
  _background(c, primary);
  const Offset center = Offset(canvas / 2, canvas / 2);
  _symbol(
    c,
    icon: Symbols.school,
    center: center - Offset(0, safe * 0.1),
    size: safe * 0.74,
    color: onPrimary,
  );

  final double width = safe * 0.62;
  final double amplitude = safe * 0.055;
  final double wavelength = width / 2;
  final double baseline = center.dy + safe * 0.32;
  final Path wave = Path();
  for (double x = 0; x <= width; x += 1) {
    final double y = math.sin(x / wavelength * 2 * math.pi) * amplitude;
    if (x == 0) {
      wave.moveTo(center.dx - width / 2, baseline + y);
    } else {
      wave.lineTo(center.dx - width / 2 + x, baseline + y);
    }
  }
  c.drawPath(
    wave,
    Paint()
      ..color = primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = safe * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// 9. Шапка на карточке.
void iconCardCap(Canvas c, Size size) {
  _background(c, primary);
  final Rect card = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(card, Radius.circular(safe * 0.28)),
    Paint()..color = onPrimary,
  );
  _symbol(
    c,
    icon: Symbols.school,
    center: card.center,
    size: safe * 0.56,
    color: primary,
  );
}

/// 10. Печенька с шапкой и часами: время и учёба вместе.
void iconCookieCapClock(Canvas c, Size size) {
  _background(c, primary);
  final Rect rect = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawPath(
    _shapePath(MaterialShapes.cookie9Sided, rect),
    Paint()..color = onPrimary,
  );
  _symbol(
    c,
    icon: Symbols.school,
    center: rect.center - Offset(0, safe * 0.06),
    size: safe * 0.46,
    color: primary,
  );

  // Маленькие часы в правом нижнем углу печеньки.
  final Offset clock = rect.center + Offset(safe * 0.2, safe * 0.2);
  final double radius = safe * 0.16;
  c.drawCircle(clock, radius, Paint()..color = primary);
  final Paint hand = Paint()
    ..color = onPrimary
    ..strokeWidth = radius * 0.22
    ..strokeCap = StrokeCap.round;
  c.drawLine(clock, clock + Offset(0, -radius * 0.55), hand);
  c.drawLine(clock, clock + Offset(radius * 0.4, 0), hand);
}

/// Фон адаптивной иконки — сплошной цвет.
void _background(Canvas c, Color color) {
  c.drawRect(const Rect.fromLTWH(0, 0, canvas, canvas), Paint()..color = color);
}

Path _shapePath(RoundedPolygon polygon, Rect rect) {
  final Path path = polygon.normalized().toPath();
  return path.transform(
    (Matrix4.translationValues(
      rect.left,
      rect.top,
      0,
    )..multiply(Matrix4.diagonal3Values(rect.width, rect.height, 1))).storage,
  );
}

/// 1. Печенька с часами: форма из библиотеки M3 + стрелки.
void iconCookieClock(Canvas c, Size size) {
  _background(c, primary);
  final Rect rect = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawPath(
    _shapePath(MaterialShapes.cookie9Sided, rect),
    Paint()..color = onPrimary,
  );

  final Offset center = rect.center;
  final Paint hand = Paint()
    ..color = primary
    ..strokeWidth = safe * 0.075
    ..strokeCap = StrokeCap.round;
  c.drawLine(center, center + Offset(0, -safe * 0.26), hand);
  c.drawLine(center, center + Offset(safe * 0.19, 0), hand);
}

/// 2. Карточка расписания: скруглённый квадрат и три столбца-пары разной
/// длины, как лента дней.
void iconScheduleCard(Canvas c, Size size) {
  _background(c, primary);
  final Rect card = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(card, Radius.circular(safe * 0.28)),
    Paint()..color = onPrimary,
  );

  final double barWidth = safe * 0.14;
  final double gap = safe * 0.09;
  final double left = card.left + safe * 0.2;
  final List<double> heights = [0.34, 0.52, 0.42];
  for (int i = 0; i < heights.length; i++) {
    final double height = safe * heights[i];
    final Rect bar = Rect.fromLTWH(
      left + i * (barWidth + gap),
      card.center.dy + safe * 0.2 - height,
      barWidth,
      height,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(barWidth / 2)),
      Paint()..color = i == 1 ? primary : primaryContainer,
    );
  }
}

/// 3. Печенька с волной: фирменная волнистая шкала прогресса пары.
void iconCookieWave(Canvas c, Size size) {
  _background(c, primary);
  final Rect rect = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawPath(
    _shapePath(MaterialShapes.cookie9Sided, rect),
    Paint()..color = onPrimary,
  );

  // Волна той же формы, что в карточке идущей пары.
  final double width = safe * 0.56;
  final double amplitude = safe * 0.09;
  final double wavelength = width / 2;
  final Path wave = Path();
  for (double x = 0; x <= width; x += 1) {
    final double y = math.sin(x / wavelength * 2 * math.pi) * amplitude;
    if (x == 0) {
      wave.moveTo(rect.center.dx - width / 2, rect.center.dy + y);
    } else {
      wave.lineTo(rect.center.dx - width / 2 + x, rect.center.dy + y);
    }
  }
  c.drawPath(
    wave,
    Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = safe * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// 4. Лента дней: три кнопки, средняя выбрана — как селектор дня.
void iconDayStrip(Canvas c, Size size) {
  _background(c, primary);
  const Offset center = Offset(canvas / 2, canvas / 2);
  final double pillWidth = safe * 0.26;
  final double gap = safe * 0.08;
  final double tall = safe * 0.78;
  final double short = safe * 0.58;

  for (int i = -1; i <= 1; i++) {
    final bool selected = i == 0;
    final double height = selected ? tall : short;
    final Rect pill = Rect.fromCenter(
      center: Offset(center.dx + i * (pillWidth + gap), center.dy),
      width: pillWidth,
      height: height,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        pill,
        Radius.circular(selected ? pillWidth * 0.42 : pillWidth / 2),
      ),
      Paint()..color = selected ? onPrimary : primaryContainer,
    );
  }
}

/// 5. Буква «Р» в печеньке — нарисована фигурами, без шрифта.
void iconLetter(Canvas c, Size size) {
  _background(c, primary);
  final Rect rect = Rect.fromCenter(
    center: const Offset(canvas / 2, canvas / 2),
    width: safe,
    height: safe,
  );
  c.drawPath(
    _shapePath(MaterialShapes.cookie9Sided, rect),
    Paint()..color = onPrimary,
  );

  final double height = safe * 0.5;
  final double stroke = height * 0.22;
  final Rect letter = Rect.fromCenter(
    center: rect.center,
    width: height * 0.72,
    height: height,
  );

  // Стойка и полукруглая чаша сверху.
  final Path path = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(letter.left, letter.top, stroke, letter.height),
        Radius.circular(stroke / 2),
      ),
    );
  final Rect bowl = Rect.fromLTWH(
    letter.left,
    letter.top,
    letter.width,
    height * 0.56,
  );
  final Path bowlPath = Path.combine(
    PathOperation.difference,
    Path()..addRRect(
      RRect.fromRectAndRadius(bowl, Radius.circular(bowl.height / 2)),
    ),
    Path()..addRRect(
      RRect.fromRectAndRadius(
        bowl.deflate(stroke),
        Radius.circular((bowl.height - 2 * stroke) / 2),
      ),
    ),
  );

  c.drawPath(
    Path.combine(PathOperation.union, path, bowlPath),
    Paint()..color = primary,
  );
}

/// Вариант логотипа: слой переднего плана и монохромный силуэт.
class Logo {
  const Logo({
    required this.name,
    required this.title,
    required this.foreground,
    required this.monochrome,
  });

  /// Суффикс ресурсов: `ic_launcher_<name>`; у варианта по умолчанию пусто.
  final String name;

  /// Подпись в настройках.
  final String title;

  final IconPainter foreground;
  final IconPainter monochrome;

  /// Иконка для Android ниже 26: фон и передний слой вместе, скруглённым
  /// квадратом — маски там нет.
  void legacy(Canvas c, Size size) {
    final Rect visibleRect = Rect.fromCenter(
      center: const Offset(canvas / 2, canvas / 2),
      width: visible,
      height: visible,
    );
    c.save();
    c.clipRRect(
      RRect.fromRectAndRadius(visibleRect, Radius.circular(visible * 0.28)),
    );
    _background(c, primary);
    foreground(c, size);
    c.restore();
  }

  /// Образец для настроек: фон и передний слой без маски.
  void preview(Canvas c, Size size) {
    _background(c, primary);
    foreground(c, size);
  }
}

Rect get _shapeRect => Rect.fromCenter(
  center: const Offset(canvas / 2, canvas / 2),
  width: safe,
  height: safe,
);

/// Рисует подложку варианта и вырезает из неё значок — монохромный слой.
void _cutout(
  Canvas c, {
  required IconPainter plate,
  required IconPainter glyph,
}) {
  c.saveLayer(const Rect.fromLTWH(0, 0, canvas, canvas), Paint());
  plate(c, const Size(canvas, canvas));
  glyph(c, const Size(canvas, canvas));
  c.restore();
}

void _cookiePlate(Canvas c, Size size) => c.drawPath(
  _shapePath(MaterialShapes.cookie9Sided, _shapeRect),
  Paint()..color = onPrimary,
);

void _cardPlate(Canvas c, Size size) => c.drawRRect(
  RRect.fromRectAndRadius(_shapeRect, Radius.circular(safe * 0.28)),
  Paint()..color = onPrimary,
);

void _cap(
  Canvas c, {
  required double size,
  required Color color,
  Offset offset = Offset.zero,
  BlendMode blendMode = BlendMode.srcOver,
}) => _symbol(
  c,
  icon: Symbols.school,
  center: _shapeRect.center + offset,
  size: size,
  color: color,
  blendMode: blendMode,
);

void _clockHands(
  Canvas c, {
  required Color color,
  BlendMode blendMode = BlendMode.srcOver,
}) {
  final Offset center = _shapeRect.center;
  final Paint hand = Paint()
    ..color = color
    ..blendMode = blendMode
    ..strokeWidth = safe * 0.075
    ..strokeCap = StrokeCap.round;
  c.drawLine(center, center + Offset(0, -safe * 0.26), hand);
  c.drawLine(center, center + Offset(safe * 0.19, 0), hand);
}

/// Варианты значка приложения; первый — по умолчанию.
final List<Logo> logos = [
  Logo(
    name: '',
    title: 'Печенька и шапка',
    foreground: (c, s) {
      _cookiePlate(c, s);
      _cap(c, size: safe * 0.52, color: primary);
    },
    monochrome: (c, s) => _cutout(
      c,
      plate: _cookiePlate,
      glyph: (c, s) => _cap(
        c,
        size: safe * 0.52,
        color: onPrimary,
        blendMode: BlendMode.dstOut,
      ),
    ),
  ),
  Logo(
    name: 'cap',
    title: 'Шапка',
    foreground: (c, s) => _cap(c, size: safe * 0.86, color: onPrimary),
    monochrome: (c, s) => _cap(c, size: safe * 0.86, color: onPrimary),
  ),
  Logo(
    name: 'clock',
    title: 'Печенька и часы',
    foreground: (c, s) {
      _cookiePlate(c, s);
      _clockHands(c, color: primary);
    },
    monochrome: (c, s) => _cutout(
      c,
      plate: _cookiePlate,
      glyph: (c, s) =>
          _clockHands(c, color: onPrimary, blendMode: BlendMode.dstOut),
    ),
  ),
  Logo(
    name: 'card',
    title: 'Карточка и шапка',
    foreground: (c, s) {
      _cardPlate(c, s);
      _cap(c, size: safe * 0.56, color: primary);
    },
    monochrome: (c, s) => _cutout(
      c,
      plate: _cardPlate,
      glyph: (c, s) => _cap(
        c,
        size: safe * 0.56,
        color: onPrimary,
        blendMode: BlendMode.dstOut,
      ),
    ),
  ),
];

const Map<String, IconPainter> icons = {
  '1-cookie-clock': iconCookieClock,
  '2-schedule-card': iconScheduleCard,
  '3-cookie-wave': iconCookieWave,
  '4-day-strip': iconDayStrip,
  '5-letter': iconLetter,
  '6-cookie-cap': iconCookieCap,
  '7-cap-plain': iconCapPlain,
  '8-cap-wave': iconCapWave,
  '9-card-cap': iconCardCap,
  '10-cookie-cap-clock': iconCookieCapClock,
};

Future<void> _writePng(
  String path,
  IconPainter painter,
  WidgetTester tester, {
  double size = canvas,
}) async {
  await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    c.scale(size / canvas);
    painter(c, const Size(canvas, canvas));
    final ui.Image image = await recorder.endRecording().toImage(
      size.round(),
      size.round(),
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    final File file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _write(String name, IconPainter painter, WidgetTester tester) =>
    _writePng('docs/icon/$name.png', painter, tester);

/// Плотности Android: mdpi… xxxhdpi.
const Map<String, double> densities = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

void main() {
  setUpAll(() async {
    // Значки Material Symbols лежат внутри пакета.
    final File config = File('.dart_tool/package_config.json');
    final Map<String, dynamic> json =
        jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
    for (final dynamic entry in json['packages'] as List<dynamic>) {
      final Map<String, dynamic> package = entry as Map<String, dynamic>;
      if (package['name'] != 'material_symbols_icons') continue;
      String rootPath = package['rootUri'] as String;
      if (!rootPath.endsWith('/')) rootPath = '$rootPath/';
      final Uri root = config.absolute.parent.uri.resolve(rootPath);
      final Uri lib = root.resolve(package['packageUri'] as String);
      for (final String face in ['Outlined', 'Rounded', 'Sharp']) {
        final File font = File.fromUri(
          lib.resolve('fonts/MaterialSymbols$face.ttf'),
        );
        if (!font.existsSync()) continue;
        final FontLoader loader = FontLoader(
          'packages/material_symbols_icons/MaterialSymbols$face',
        )..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
        await loader.load();
      }
    }
  });

  testWidgets('варианты иконки', (tester) async {
    for (final MapEntry<String, IconPainter> entry in icons.entries) {
      await _write(entry.key, entry.value, tester);
    }
    expect(Directory('docs/icon').listSync(), isNotEmpty);
  });

  testWidgets('ресурсы значков приложения', (tester) async {
    const String res = 'android/app/src/main/res';
    for (final Logo logo in logos) {
      final String suffix = logo.name.isEmpty ? '' : '_${logo.name}';
      for (final MapEntry<String, double> density in densities.entries) {
        final String dir = '$res/mipmap-${density.key}';
        // Слои адаптивной иконки — 108dp, обычная иконка — 48dp.
        await _writePng(
          '$dir/ic_launcher${suffix}_foreground.png',
          logo.foreground,
          tester,
          size: 108 * density.value,
        );
        await _writePng(
          '$dir/ic_launcher${suffix}_monochrome.png',
          logo.monochrome,
          tester,
          size: 108 * density.value,
        );
        await _writePng(
          '$dir/ic_launcher$suffix.png',
          logo.legacy,
          tester,
          size: 48 * density.value,
        );
      }
      // Образец для выбора значка в настройках.
      await _writePng(
        'assets/app_icons/${logo.name.isEmpty ? 'default' : logo.name}.png',
        logo.preview,
        tester,
        size: 192,
      );
    }
    // Для витрины и README.
    await _writePng(
      'docs/icon/logo.png',
      logos.first.preview,
      tester,
      size: 512,
    );

    expect(
      File('$res/mipmap-xxxhdpi/ic_launcher_foreground.png').existsSync(),
      isTrue,
    );
  });
}
