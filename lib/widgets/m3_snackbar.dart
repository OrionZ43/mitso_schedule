import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Снекбар M3 и его хост — порт Compose `SnackbarHost` / `Snackbar`.
///
/// https://m3.material.io/components/snackbar — одно сообщение за раз, новое
/// сразу заменяет старое, без стопки. `SnackBar` Flutter раскрывается по
/// высоте, а Compose (`SnackbarHost.kt`, `FadeInFadeOutWithScale`) делает
/// прозрачность пружиной FastEffects и масштаб 0.8 ↔ 1 пружиной FastSpatial.
class M3SnackbarHost extends StatefulWidget {
  const M3SnackbarHost({
    super.key,
    required this.child,
    this.bottomPadding = 0,
  });

  /// Экран, поверх которого внизу показываются снекбары.
  final Widget child;

  /// Подъём над FAB (`Scaffold.kt`: снекбар стоит над FAB, если он есть).
  final double bottomPadding;

  static M3SnackbarHostState of(BuildContext context) =>
      context.findAncestorStateOfType<M3SnackbarHostState>()!;

  @override
  State<M3SnackbarHost> createState() => M3SnackbarHostState();
}

@immutable
class _SnackbarData {
  const _SnackbarData(this.message, this.actionLabel, this.onAction);

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class M3SnackbarHostState extends State<M3SnackbarHost> {
  /// `SnackbarDuration.Short`.
  static const Duration shortDuration = Duration(milliseconds: 4000);

  final List<_SnackbarData> _items = [];
  _SnackbarData? _current;
  Timer? _timer;

  /// Показать сообщение. Без действия — 4 с (`SnackbarDuration.Short`),
  /// с действием — пока пользователь не нажмёт или не закроет
  /// (`showSnackbar`: Indefinite при `actionLabel`).
  void show(String message, {String? actionLabel, VoidCallback? onAction}) {
    final _SnackbarData data = _SnackbarData(message, actionLabel, onAction);
    _timer?.cancel();
    setState(() {
      _current = data;
      _items.add(data);
    });
    if (actionLabel == null) {
      _timer = Timer(shortDuration, () => _dismiss(data));
    }
  }

  /// Скрыть текущее сообщение.
  void dismiss() => _dismiss(_current);

  void _dismiss(_SnackbarData? data) {
    if (data == null || data != _current) return;
    _timer?.cancel();
    if (mounted) setState(() => _current = null);
  }

  void _removeHidden(_SnackbarData data) {
    if (data == _current || !mounted) return;
    setState(() => _items.remove(data));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: AppMotion.defaultSpatial.duration,
          curve: AppMotion.defaultSpatial.curve,
          left: 0,
          right: 0,
          bottom: widget.bottomPadding,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                for (final _SnackbarData data in _items)
                  _FadeInFadeOutWithScale(
                    key: ObjectKey(data),
                    visible: data == _current,
                    onHidden: () => _removeHidden(data),
                    child: _M3Snackbar(
                      data: data,
                      onAction: () {
                        data.onAction?.call();
                        _dismiss(data);
                      },
                      onDismiss: () => _dismiss(data),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FadeInFadeOutWithScale extends StatefulWidget {
  const _FadeInFadeOutWithScale({
    super.key,
    required this.visible,
    required this.onHidden,
    required this.child,
  });

  final bool visible;
  final VoidCallback onHidden;
  final Widget child;

  @override
  State<_FadeInFadeOutWithScale> createState() =>
      _FadeInFadeOutWithScaleState();
}

class _FadeInFadeOutWithScaleState extends State<_FadeInFadeOutWithScale>
    with TickerProviderStateMixin {
  // `animatedOpacity` / `animatedScale` в `SnackbarHost.kt`: старт 0 и 0.8.
  late final AnimationController _opacity = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 0.8,
  );

  @override
  void initState() {
    super.initState();
    _animate();
  }

  @override
  void didUpdateWidget(_FadeInFadeOutWithScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _animate();
  }

  void _animate() {
    final bool visible = widget.visible;
    _opacity.springTo(AppMotion.fastEffects, visible ? 1 : 0).whenComplete(() {
      if (!widget.visible) widget.onHidden();
    });
    _scale.springTo(AppMotion.fastSpatial, visible ? 1 : 0.8);
  }

  @override
  void dispose() {
    _opacity.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = reduceMotionOf(context);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: Listenable.merge([_opacity, _scale]),
        builder: (context, child) => Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: reduce ? 1 : _scale.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Снекбар: `SnackbarTokens` — inverseSurface, 4dp, level3, текст bodyMedium
/// inverseOnSurface, действие labelLarge inversePrimary; `Snackbar.kt` —
/// ширина до 600dp, поля 16dp / 8dp у кнопки, текст 14dp сверху и снизу.
class _M3Snackbar extends StatelessWidget {
  const _M3Snackbar({
    required this.data,
    required this.onAction,
    required this.onDismiss,
  });

  final _SnackbarData data;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  /// `SnackbarHost`: поле вокруг снекбара.
  static const double margin = 12;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Semantics(
      container: true,
      liveRegion: true,
      onDismiss: onDismiss,
      child: Padding(
        padding: const EdgeInsets.all(margin),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, minHeight: 48),
          child: Material(
            color: colors.inverseSurface,
            elevation: 6,
            shape: AppShapes.rounded(AppShapes.extraSmall),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: 16,
                end: data.actionLabel == null ? 16 : 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        data.message,
                        maxLines: 2,
                        style: context.text.bodyMedium!.copyWith(
                          color: colors.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                  if (data.actionLabel != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.inversePrimary,
                        textStyle: context.text.labelLarge,
                      ),
                      child: Text(data.actionLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
