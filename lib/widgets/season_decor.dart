import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_motion.dart';
import '../theme/status_colors.dart';
import '../theme/seasons.dart';

/// Сезонное украшение над расписанием: фигуры медленно падают сверху.
///
/// Фигуры — из библиотеки M3 (https://m3.material.io/styles/shape:
/// абстрактные формы уместны «on imagery and decorative UI»), цвета — роли
/// темы, так что украшение живёт в любой палитре и в обеих темах. Слой
/// неинтерактивный и не читается screen reader'ом.
///
/// При системной настройке «Удалить анимации» фигуры стоят на месте:
/// https://m3.material.io/styles/motion/transitions — «Disable decorative
/// effects like parallax».
class SeasonDecor extends StatefulWidget {
  const SeasonDecor({super.key, required this.season, this.height = 340});

  final Season season;

  /// Высота полосы, по которой падают фигуры: дальше они растворяются.
  final double height;

  /// Сколько фигур в кадре. Больше — пестрит, меньше — не замечаешь.
  static const int count = 9;

  @override
  State<SeasonDecor> createState() => _SeasonDecorState();
}

class _SeasonDecorState extends State<SeasonDecor>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);

  /// Параметры фигур: раскладка постоянная, чтобы листья не прыгали при
  /// каждой перестройке.
  late final List<_Flake> _flakes = _buildFlakes(widget.season);

  bool _reduceMotion = false;

  static List<_Flake> _buildFlakes(Season season) {
    // Зерно от сезона: раскладка у каждого своя, но между запусками одна.
    final math.Random random = math.Random(season.id.hashCode);
    return [
      for (int i = 0; i < SeasonDecor.count; i++)
        _Flake(
          polygon: season.decorShapes[i % season.decorShapes.length],
          x: (i + 0.5) / SeasonDecor.count + (random.nextDouble() - 0.5) * 0.06,
          size: 18 + random.nextDouble() * 26,
          fall: Duration(milliseconds: 9000 + random.nextInt(9000)),
          phase: random.nextDouble(),
          sway: 10 + random.nextDouble() * 18,
          turn: Duration(milliseconds: 6000 + random.nextInt(9000)),
          clockwise: random.nextBool(),
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) => _elapsed.value = elapsed;

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // Тёплые дополнительные цвета темы (они гармонизированы с primary) дают
    // осеннюю смесь в любой схеме; tertiary в сезонных схемах уходит в синий
    // и превращает листья в серые пятна.
    final StatusColors status = StatusColors.of(context);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _DecorPainter(
                elapsed: _elapsed,
                flakes: _flakes,
                reduceMotion: _reduceMotion,
                colors: [
                  status.exam,
                  colors.primary.withValues(alpha: 0.2),
                  status.pending,
                  colors.primaryContainer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Одна падающая фигура.
@immutable
class _Flake {
  const _Flake({
    required this.polygon,
    required this.x,
    required this.size,
    required this.fall,
    required this.phase,
    required this.sway,
    required this.turn,
    required this.clockwise,
  });

  final RoundedPolygon polygon;

  /// Доля ширины, вокруг которой фигура падает.
  final double x;

  final double size;

  /// За сколько проходит всю полосу.
  final Duration fall;

  /// Сдвиг начала, чтобы фигуры не падали строем.
  final double phase;

  /// Размах покачивания по горизонтали.
  final double sway;

  /// Период полного оборота.
  final Duration turn;
  final bool clockwise;
}

class _DecorPainter extends CustomPainter {
  _DecorPainter({
    required this.elapsed,
    required this.flakes,
    required this.reduceMotion,
    required this.colors,
  }) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final List<_Flake> flakes;
  final bool reduceMotion;
  final List<Color> colors;

  /// Прозрачность задаётся самими цветами: контейнерные роли идут
  /// плотными, акцентные — полупрозрачными силуэтами. Ниже по полосе всё
  /// растворяется, чтобы не лезть в текст.

  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final double seconds = elapsed.value.inMilliseconds / 1000;

    for (int i = 0; i < flakes.length; i++) {
      final _Flake flake = flakes[i];
      final double period = flake.fall.inMilliseconds / 1000;
      final double progress = reduceMotion
          // Без движения — просто разложены по полосе.
          ? flake.phase
          : (seconds / period + flake.phase) % 1;

      final double y = progress * (size.height + flake.size) - flake.size;
      final double swing = reduceMotion
          ? 0
          : math.sin((seconds / period + flake.phase) * 2 * math.pi) *
                flake.sway;
      final double left = flake.x * size.width + swing - flake.size / 2;

      // Ближе к низу полосы фигуры растворяются, чтобы не упираться в текст.
      final double fade = (1 - progress).clamp(0.0, 1.0);
      final Color source = colors[i % colors.length];
      final Color color = source.withValues(alpha: source.a * fade);

      final double rotation = reduceMotion
          ? flake.phase * 2 * math.pi
          : (seconds / (flake.turn.inMilliseconds / 1000)) *
                2 *
                math.pi *
                (flake.clockwise ? 1 : -1);

      _path.reset();
      final Path shape = flake.polygon.normalized().toPath(path: _path);
      final Rect rect = Rect.fromLTWH(left, y, flake.size, flake.size);

      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(rotation);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawPath(
        shape.transform(
          (Matrix4.translationValues(rect.left, rect.top, 0)
                ..multiply(Matrix4.diagonal3Values(rect.width, rect.height, 1)))
              .storage,
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) =>
      old.reduceMotion != reduceMotion ||
      !listEquals(old.colors, colors) ||
      old.flakes != flakes;
}
