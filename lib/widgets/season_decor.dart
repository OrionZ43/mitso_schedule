import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seasons.dart';

/// Картина сезона на весь фон вкладки: у расписания, заметок и профиля
/// свои сцены ([Season.backdrops]).
///
/// Иллюстрация растянута на экран (`BoxFit.cover`) и приглушена, чтобы
/// читаться фоном, а не картинкой: карточки и текст остаются главными. В
/// светлой теме часть цветов подменяется ([Season.backdropDayColors]) — ночная
/// картина днём иначе серая. Слой статичный, неинтерактивный, скрыт от
/// screen reader и рисуется в своём [RepaintBoundary].
class SeasonBackdrop extends StatelessWidget {
  const SeasonBackdrop({super.key, required this.season, required this.page});

  final Season season;

  /// Чья картина: расписания, заметок или профиля.
  final SeasonPage page;

  /// Прозрачность картины по теме. Фон тёмной темы почти чёрный, поэтому
  /// меньшая прозрачность там темнее; в светлой — наоборот, гуще цвета.
  static const double opacityDark = 0.35;
  static const double opacityLight = 0.8;

  /// Разобранный текст SVG на (файл, тема) — файл читается один раз.
  static final Map<String, Future<String>> _cache = {};

  static Future<String> _load(Season season, String asset, bool dark) {
    // `loadString` большие файлы декодирует в изоляте — в тестах такой
    // Future не завершается, поэтому байты и `utf8.decode` напрямую.
    return _cache['$asset|$dark'] ??= rootBundle.load(asset).then((
      ByteData data,
    ) {
      String svg = utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (dark) return svg;
      for (final MapEntry<String, String> swap
          in season.backdropDayColors.entries) {
        svg = svg.replaceAll(swap.key, swap.value);
      }
      return svg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? asset = season.backdrops[page];
    if (asset == null) return const SizedBox.shrink();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Opacity(
            opacity: dark ? opacityDark : opacityLight,
            child: FutureBuilder<String>(
              future: _load(season, asset, dark),
              builder: (context, snapshot) {
                final String? svg = snapshot.data;
                if (svg == null) return const SizedBox.expand();
                return SvgPicture.string(
                  svg,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
