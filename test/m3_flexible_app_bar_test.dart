import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/theme/app_motion.dart';
import 'package:mitso_schedule/widgets/m3_flexible_app_bar.dart';

final ThemeData _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
);
final ColorScheme _colors = _theme.colorScheme;

const double _inset = 24;
const String _title = 'Профиль';

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _app({required Widget home, double textScale = 1}) {
  return MaterialApp(
    theme: _theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: _inset),
        viewPadding: const EdgeInsets.only(top: _inset),
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  );
}

/// Экран с medium flexible app bar и длинным списком под [M3AppBarSettle].
Future<ScrollController> _pumpFlexible(
  WidgetTester tester, {
  String? subtitle,
  double textScale = 1,
}) async {
  _usePhone(tester);
  final ScrollController controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _app(
      textScale: textScale,
      home: Scaffold(
        body: M3AppBarSettle(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverMediumFlexibleAppBar(
                title: _title,
                subtitle: subtitle,
                leading: IconButton(
                  onPressed: () {},
                  tooltip: 'Назад',
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Группа',
                    icon: const Icon(Icons.groups),
                  ),
                ],
              ),
              SliverList.builder(
                itemCount: 60,
                itemBuilder: (_, i) =>
                    SizedBox(height: 56, child: Text('Строка $i')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return controller;
}

RenderSliver _sliver(WidgetTester tester) =>
    tester.renderObject<RenderSliver>(find.byType(SliverMediumFlexibleAppBar));

/// Текст с данным размером шрифта: у бара две копии заголовка.
Finder _textWithSize(String text, double fontSize) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == text &&
      widget.style?.fontSize == fontSize,
);

final Finder _smallTitle = _textWithSize(_title, 22);
final Finder _largeTitle = _textWithSize(_title, 28);

/// Кнопка целиком (зона нажатия 48dp), а не её подсказка.
Finder _iconButton(IconData icon) =>
    find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton));

/// Прозрачности слоёв внутри бара: сливер кладёт всё содержимое в
/// `AnnotatedRegionLayer` шириной экрана.
List<int> _opacityAlphas(WidgetTester tester) {
  final Layer bar = tester.layers.firstWhere(
    (layer) =>
        layer is AnnotatedRegionLayer<SystemUiOverlayStyle> &&
        layer.size?.width == 412,
  );
  final List<int> alphas = [];
  void visit(Layer layer) {
    if (layer is OpacityLayer) alphas.add(layer.alpha!);
    if (layer is ContainerLayer) {
      for (
        Layer? child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        visit(child);
      }
    }
  }

  visit(bar);
  return alphas;
}

List<SemanticsNode> _headers(WidgetTester tester, String label) {
  final List<SemanticsNode> found = [];
  void visit(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    if (data.flagsCollection.isHeader && data.label == label) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found;
}

/// Протягивает список вверх на [distance] медленно и отпускает без броска.
Future<double> _dragAndRelease(WidgetTester tester, double distance) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.text('Строка 6')),
  );
  const double step = 5;
  for (double moved = 0; moved < distance; moved += step) {
    await gesture.moveBy(const Offset(0, -step));
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Палец замер: скорость броска нулевая.
  await tester.pump(const Duration(milliseconds: 200));
  final double released = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position
      .pixels;
  await gesture.up();
  return released;
}

void main() {
  group('SliverMediumFlexibleAppBar', () {
    testWidgets('высота 112dp без подзаголовка плюс статус-бар', (
      tester,
    ) async {
      await _pumpFlexible(tester);
      final SliverGeometry geometry = _sliver(tester).geometry!;
      expect(geometry.scrollExtent, _inset + 112);
      expect(geometry.paintExtent, _inset + 112);
      expect(geometry.maxScrollObstructionExtent, _inset + 64);

      // Верхний ряд: leading с отступом 4dp, заголовок на 56dp, actions с
      // отступом 4dp — по центру ряда 64dp под статус-баром.
      expect(tester.getRect(_iconButton(Icons.arrow_back)).left, 4);
      expect(tester.getCenter(_iconButton(Icons.arrow_back)).dy, _inset + 32);
      expect(tester.getRect(_smallTitle).left, 56);
      expect(tester.getRect(_iconButton(Icons.groups)).right, 412 - 4);

      // Нижний ряд: крупный заголовок на 16dp.
      expect(tester.getRect(_largeTitle).left, 16);
    });

    testWidgets('высота 136dp с подзаголовком плюс статус-бар', (tester) async {
      await _pumpFlexible(tester, subtitle: 'Синхронизировано');
      final SliverGeometry geometry = _sliver(tester).geometry!;
      expect(geometry.scrollExtent, _inset + 136);
      expect(geometry.maxScrollObstructionExtent, _inset + 64);
    });

    testWidgets('крупный блок: 24dp от последней базовой линии', (
      tester,
    ) async {
      for (final String? subtitle in [null, 'Синхронизировано']) {
        await _pumpFlexible(tester, subtitle: subtitle);
        final double rowTop = _inset + 64;
        final double rowHeight = subtitle == null ? 48 : 72;

        // Последняя строка блока — подзаголовок, если он есть.
        final Finder lastText = subtitle == null
            ? _largeTitle
            : _textWithSize(subtitle, 14);
        final RenderParagraph last = tester.renderObject(lastText);
        final TextPainter line = TextPainter(
          text: last.text,
          textDirection: TextDirection.ltr,
          textScaler: last.textScaler,
          maxLines: 1,
        )..layout();
        final double descent =
            line.height -
            line.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        line.dispose();
        final Rect title = tester.getRect(_largeTitle);
        final double blockHeight = tester.getRect(lastText).bottom - title.top;

        // `placeTopAppBar`, Arrangement.Bottom.
        final double paddingFromBottom = 24 - descent;
        final double adjusted = paddingFromBottom + blockHeight > rowHeight
            ? paddingFromBottom - (paddingFromBottom + blockHeight - rowHeight)
            : paddingFromBottom;
        expect(
          title.top,
          closeTo(
            rowTop + rowHeight - blockHeight - math.max(0, adjusted),
            0.01,
          ),
        );
      }
    });

    testWidgets('доля сворачивания → цвет, прозрачность и семантика', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ScrollController controller = await _pumpFlexible(tester);

      for (final double offset in [0.0, 6, 12, 23, 24, 36, 47, 48, 300]) {
        controller.jumpTo(offset);
        await tester.pump();
        final double fraction = math.min(offset, 48) / 48;
        final RenderSliver sliver = _sliver(tester);

        expect(
          sliver.geometry!.paintExtent,
          _inset + 64 + 48 - math.min(offset, 48),
          reason: 'смещение $offset',
        );
        expect(
          sliver,
          paints..rect(
            color: SliverMediumFlexibleAppBar.containerColorFor(
              _colors,
              fraction,
            ),
          ),
          reason: 'смещение $offset',
        );

        final int small = Color.getAlphaFromOpacity(
          const Cubic(0.8, 0.0, 0.8, 0.15).transform(fraction),
        );
        final int large = Color.getAlphaFromOpacity(1 - fraction);
        expect(_opacityAlphas(tester), [
          if (small > 0) small,
          if (large > 0) large,
        ], reason: 'смещение $offset');

        // Роль заголовка — только у одной копии.
        final List<SemanticsNode> headers = _headers(tester, _title);
        expect(headers, hasLength(1), reason: 'смещение $offset');
        final Finder visible = fraction < 0.5 ? _largeTitle : _smallTitle;
        expect(
          tester
              .getSemantics(visible)
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
          reason: 'смещение $offset',
        );
      }

      // Интерполяция в Oklab, как `lerp(Color, Color)` в Compose: середина
      // между чёрным и белым — L = 0.5, то есть sRGB ≈ 0.39, а не 0.5.
      final ColorScheme blackToWhite = const ColorScheme.light().copyWith(
        surface: const Color(0xFF000000),
        surfaceContainer: const Color(0xFFFFFFFF),
      );
      final Color middle = M3SmallAppBar.containerColorFor(blackToWhite, 0.5);
      expect(middle.r, closeTo(0.3885, 0.002));
      expect(middle.g, closeTo(middle.r, 1e-4));

      // Крайние значения: surface без прокрутки, surfaceContainer в small.
      expect(
        SliverMediumFlexibleAppBar.containerColorFor(_colors, 0),
        _colors.surface,
      );
      expect(
        SliverMediumFlexibleAppBar.containerColorFor(_colors, 1),
        _colors.surfaceContainer,
      );
      handle.dispose();
    });

    testWidgets('свёрнутый бар — small 64dp, крупный ряд обрезан целиком', (
      tester,
    ) async {
      final ScrollController controller = await _pumpFlexible(tester);
      controller.jumpTo(400);
      await tester.pump();

      final RenderSliver sliver = _sliver(tester);
      expect(sliver.geometry!.paintExtent, _inset + 64);
      expect(_opacityAlphas(tester), [255]);
      final Rect small = tester.getRect(_smallTitle);
      expect(small.center.dy, closeTo(_inset + 32, 0.01));

      // Содержимое под баром не получает нажатий.
      final Offset underBar = Offset(200, _inset + 40);
      expect(
        tester
            .hitTestOnBinding(underBar)
            .path
            .any((entry) => entry.target == sliver),
        isTrue,
      );
    });

    testWidgets('шрифт 2×: ряды растут, текст не обрезан и не переполнен', (
      tester,
    ) async {
      final ScrollController controller = await _pumpFlexible(
        tester,
        subtitle: 'Синхронизировано',
        textScale: 2,
      );
      expect(tester.takeException(), isNull);

      final SliverGeometry geometry = _sliver(tester).geometry!;
      final double topRow = geometry.maxScrollObstructionExtent - _inset;
      final double bottomRow = geometry.scrollExtent - _inset - topRow;
      expect(topRow, greaterThan(64));
      expect(bottomRow, greaterThan(72));

      // Маленький блок целиком в верхнем ряду.
      final Rect smallBlock = tester
          .getRect(_smallTitle)
          .expandToInclude(
            tester.getRect(_textWithSize('Синхронизировано', 12)),
          );
      expect(smallBlock.top, greaterThanOrEqualTo(_inset));
      expect(smallBlock.bottom, lessThanOrEqualTo(_inset + topRow));

      // Крупный блок целиком в нижнем ряду.
      final Rect largeBlock = tester
          .getRect(_largeTitle)
          .expandToInclude(
            tester.getRect(_textWithSize('Синхронизировано', 14)),
          );
      expect(largeBlock.top, greaterThanOrEqualTo(_inset + topRow));
      expect(largeBlock.bottom, lessThanOrEqualTo(geometry.scrollExtent));

      controller.jumpTo(bottomRow);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_sliver(tester).geometry!.paintExtent, _inset + topRow);
    });

    testWidgets('доводка: меньше половины — разворачивается пружиной', (
      tester,
    ) async {
      final ScrollController controller = await _pumpFlexible(tester);
      final double released = await _dragAndRelease(tester, 15);
      expect(released, inExclusiveRange(0.5, 24));

      await tester.pump();
      final Duration duration = AppMotion.defaultEffects.duration;
      const Duration frame = Duration(milliseconds: 50);
      for (Duration t = frame; t < duration; t += frame) {
        await tester.pump(frame);
        final double progress = AppMotion.defaultEffects.curve.transform(
          t.inMicroseconds / duration.inMicroseconds,
        );
        expect(
          controller.offset,
          closeTo(released * (1 - progress), 0.05),
          reason: '$t',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 0);
    });

    testWidgets('доводка: больше половины — сворачивается', (tester) async {
      final ScrollController controller = await _pumpFlexible(tester);
      final double released = await _dragAndRelease(tester, 40);
      expect(released, inExclusiveRange(24, 47.5));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, inExclusiveRange(released, 48));
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.offset, 48);
      expect(_sliver(tester).geometry!.paintExtent, _inset + 64);
    });

    testWidgets('доводка работает и в NestedScrollView', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: M3AppBarSettle(
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => const [
                  SliverMediumFlexibleAppBar(title: _title),
                ],
                body: ListView.builder(
                  itemCount: 60,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 56, child: Text('Строка $i')),
                ),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Строка 6')),
      );
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 200));
      final double extent = _sliver(tester).geometry!.paintExtent;
      expect(extent, inExclusiveRange(_inset + 64, _inset + 88));
      await gesture.up();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sliver(tester).geometry!.paintExtent, _inset + 64);
    });

    testWidgets('без M3AppBarSettle бар остаётся там, где отпустили', (
      tester,
    ) async {
      _usePhone(tester);
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverMediumFlexibleAppBar(title: _title),
                SliverList.builder(
                  itemCount: 60,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 56, child: Text('Строка $i')),
                ),
              ],
            ),
          ),
        ),
      );
      final double released = await _dragAndRelease(tester, 30);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.offset, released);
    });
  });

  group('M3SmallAppBar', () {
    Future<ScrollController> pumpSmall(
      WidgetTester tester, {
      Widget? leading,
    }) async {
      _usePhone(tester);
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            appBar: M3SmallAppBar(
              title: 'Высшая математика',
              subtitle: '17 сентября',
              leading: leading,
              actions: [
                IconButton(
                  onPressed: () {},
                  tooltip: 'Карта',
                  icon: const Icon(Icons.map),
                ),
              ],
            ),
            body: ListView.builder(
              controller: controller,
              itemCount: 60,
              itemBuilder: (_, i) =>
                  SizedBox(height: 56, child: Text('Строка $i')),
            ),
          ),
        ),
      );
      return controller;
    }

    Color barColor(WidgetTester tester) => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(M3SmallAppBar),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    testWidgets('64dp, заголовок на 56dp после leading и на 16dp без него', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        leading: IconButton(
          onPressed: () {},
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
        ),
      );
      expect(tester.getSize(find.byType(M3SmallAppBar)).height, _inset + 64);
      expect(tester.getRect(_iconButton(Icons.arrow_back)).left, 4);
      expect(tester.getRect(find.text('Высшая математика')).left, 56);
      expect(tester.getRect(_iconButton(Icons.map)).right, 412 - 4);
      expect(barColor(tester), _colors.surface);

      await pumpSmall(tester);
      expect(tester.getRect(find.text('Высшая математика')).left, 16);
    });

    testWidgets(
      'содержимое под баром — surfaceContainer пружиной DefaultEffects',
      (tester) async {
        final ScrollController controller = await pumpSmall(tester);

        // `overlappedFraction > 0.01`: меньше 0.64dp цвет не меняется.
        controller.jumpTo(0.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(barColor(tester), _colors.surface);

        controller.jumpTo(100);
        await tester.pump();
        final spring = AppMotion.defaultEffects.simulate(from: 0, to: 1);
        await tester.pump(const Duration(milliseconds: 48));
        final Color expected = M3SmallAppBar.containerColorFor(
          _colors,
          spring.x(0.048),
        );
        final Color actual = barColor(tester);
        expect(actual.r, closeTo(expected.r, 1e-6));
        expect(actual.g, closeTo(expected.g, 1e-6));
        expect(actual.b, closeTo(expected.b, 1e-6));
        expect(spring.x(0.048), inExclusiveRange(0.1, 0.9));

        await tester.pump(const Duration(milliseconds: 600));
        expect(barColor(tester), _colors.surfaceContainer);

        controller.jumpTo(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(barColor(tester), _colors.surface);
      },
    );

    testWidgets('preferredHeightOf растёт с масштабом шрифта', (tester) async {
      _usePhone(tester);
      late double plain;
      late double scaled;
      await tester.pumpWidget(
        _app(
          textScale: 2,
          home: Builder(
            builder: (context) {
              plain = M3SmallAppBar.preferredHeightOf(context);
              scaled = M3SmallAppBar.preferredHeightOf(
                context,
                withSubtitle: true,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      // titleLarge 28dp × 2 = 56 < 64; с labelMedium 16dp × 2 = 88.
      expect(plain, 64);
      expect(scaled, 88);
    });
  });
}
