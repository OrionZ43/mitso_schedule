import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import 'm3_loading_indicator.dart';

/// Pull-to-refresh, показывающий [M3LoadingIndicator].
///
/// Штатный [RefreshIndicator] рисует собственную круговую шкалу и не даёт её
/// заменить, а гайдлайн прямо называет pull-to-refresh сценарием для loading
/// indicator: https://m3.material.io/components/loading-indicator/guidelines
/// Поэтому протяжка обрабатывается здесь: копится overscroll у верхней кромки,
/// после порога запускается [onRefresh].
class M3PullToRefresh extends StatefulWidget {
  const M3PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 24,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Отступ сверху, на котором индикатор замирает во время обновления.
  final double displacement;

  /// Протяжка, после которой обновление срабатывает.
  static const double triggerDistance = 96;

  @override
  State<M3PullToRefresh> createState() => _M3PullToRefreshState();
}

enum _RefreshMode { idle, dragging, refreshing }

class _M3PullToRefreshState extends State<M3PullToRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: AppMotion.defaultSpatial.duration,
  )..addListener(() => setState(() {}));

  double _dragOffset = 0;
  _RefreshMode _mode = _RefreshMode.idle;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// Доля протяжки, 0..1.
  double get _fraction =>
      (_dragOffset / M3PullToRefresh.triggerDistance).clamp(0.0, 1.0);

  bool _handleNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_mode == _RefreshMode.refreshing) return false;

    if (notification is OverscrollNotification) {
      // overscroll < 0 — тянут вниз, находясь у самого верха.
      if (notification.overscroll < 0 &&
          notification.metrics.extentBefore == 0) {
        setState(() {
          _mode = _RefreshMode.dragging;
          _dragOffset = math.min(
            _dragOffset - notification.overscroll,
            M3PullToRefresh.triggerDistance * 1.5,
          );
        });
      }
    } else if (notification is ScrollUpdateNotification) {
      // Пользователь ведёт палец обратно вверх — отпускаем индикатор.
      if (_dragOffset > 0 && notification.scrollDelta != null) {
        setState(() {
          _dragOffset = math.max(0, _dragOffset - notification.scrollDelta!);
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset >= M3PullToRefresh.triggerDistance) {
        _startRefresh();
      } else if (_dragOffset > 0) {
        _reset();
      }
    }
    return false;
  }

  Future<void> _startRefresh() async {
    setState(() {
      _mode = _RefreshMode.refreshing;
      _dragOffset = M3PullToRefresh.triggerDistance;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) _reset();
    }
  }

  void _reset() {
    final double from = _dragOffset;
    _settle
      ..stop()
      ..value = 0;
    _mode = _RefreshMode.idle;
    _settle.animateWith(AppMotion.defaultSpatial.simulate()).whenComplete(() {
      if (mounted) setState(() => _dragOffset = 0);
    });
    // Во время отката смещение считается от точки отпускания.
    setState(() => _dragOffset = from);
  }

  @override
  Widget build(BuildContext context) {
    final double settleBack = _mode == _RefreshMode.idle && _settle.isAnimating
        ? 1 - _settle.value
        : 1.0;
    final double fraction = _fraction * settleBack;
    final double top = lerpDouble(-48, widget.displacement, fraction);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Stack(
        children: [
          widget.child,
          if (fraction > 0.01)
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Center(
                child: M3LoadingIndicator(
                  scale: Curves.easeOut.transform(fraction),
                  semanticsLabel: 'Обновление расписания',
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
