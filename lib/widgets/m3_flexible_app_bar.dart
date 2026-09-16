import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';

// Константы `AppBar.kt` (Compose Material3).

/// `TopAppBarHorizontalPadding` = `md.comp.app-bar.leading-space` /
/// `trailing-space` (space50).
const double _kHorizontalPadding = 4;

/// `TopAppBarTitleInset` = 16 − 4: место под заголовок, если leading нет.
const double _kTitleInset = 16 - _kHorizontalPadding;

/// `TopTitleAlphaEasing` — прозрачность маленького заголовка верхнего ряда.
const Curve _kTopTitleAlphaEasing = Cubic(0.8, 0.0, 0.8, 0.15);

/// Medium flexible app bar Material 3 Expressive в виде pinned-сливера.
///
/// Порт Compose `MediumFlexibleTopAppBar` → `TwoRowsTopAppBar` (`AppBar.kt`)
/// с `TopAppBarDefaults.exitUntilCollapsedScrollBehavior()`: при прокрутке
/// бар сворачивается в small (64dp) и остаётся small до возврата к началу
/// страницы (https://m3.material.io/components/app-bars/guidelines →
/// Behavior → Scrolling).
///
/// Устройство, как в Compose:
///   * верхний ряд `MediumAppBarCollapsedHeight` = 64dp: leading, маленькие
///     title (`titleLarge`) и subtitle (`labelMedium`) с прозрачностью
///     `TopTitleAlphaEasing(fraction)`, actions;
///   * нижний ряд высотой `expandedHeight − collapsedHeight` (48 или 72dp):
///     крупные title (`headlineMedium`, до двух строк) и subtitle
///     (`labelLarge`) без кнопок, прозрачность `1 − fraction`, ряд обрезается
///     при сворачивании. Размер шрифта не интерполируется;
///   * `fraction` = `collapsedFraction`: сколько нижнего ряда уехало;
///   * фон `lerp(surface, surfaceContainer, FastOutLinearInEasing(fraction))`
///     (`TopAppBarColors.containerColor`) рисуется и под статус-баром
///     (`TopAppBarDefaults.windowInsets` применяются внутри фона);
///   * ряды растут, если текст в них не помещается (`TopAppBarMeasurePolicy`:
///     `max(height, titlePlaceable.height)`), поэтому при крупном шрифте
///     ничего не обрезается;
///   * роль заголовка — только у видимой копии: верхней, когда
///     `fraction ≥ 0.5`, иначе нижней (`hideTitleSemantics`).
///
/// Доводку к свёрнутому или развёрнутому состоянию после прокрутки делает
/// [M3AppBarSettle] над прокручиваемым списком.
class SliverMediumFlexibleAppBar extends StatefulWidget {
  const SliverMediumFlexibleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;

  /// Кнопка «Назад» или «Меню». Цвет по умолчанию — `onSurface`
  /// (`md.comp.app-bar.leading-icon.color`).
  final Widget? leading;

  /// До двух icon buttons. Цвет по умолчанию — `onSurfaceVariant`
  /// (`md.comp.app-bar.trailing-icon.color`).
  final List<Widget> actions;

  /// `TopAppBarDefaults.MediumAppBarCollapsedHeight` = `AppBarSmallTokens.ContainerHeight`.
  static const double collapsedHeight = 64;

  /// `AppBarMediumFlexibleTokens.ContainerHeight`.
  static const double expandedHeight = 112;

  /// `AppBarMediumFlexibleTokens.LargeContainerHeight`
  /// (`md.comp.app-bar.medium-flexible.with-subtitle.container.height`).
  static const double expandedHeightWithSubtitle = 136;

  /// `MediumTitleBottomPadding`: от последней базовой линии крупного блока до
  /// низа бара.
  static const double titleBottomPadding = 24;

  /// Цвет контейнера при данной доле сворачивания
  /// (`TopAppBarColors.containerColor(colorTransitionFraction)`).
  static Color containerColorFor(ColorScheme colors, double fraction) =>
      _lerpOklab(
        colors.surface,
        colors.surfaceContainer,
        Easing.legacyAccelerate.transform(fraction.clamp(0.0, 1.0)),
      );

  /// Прозрачность маленького заголовка верхнего ряда (`topTitleAlpha`).
  static double smallTitleAlphaFor(double fraction) =>
      _kTopTitleAlphaEasing.transform(fraction.clamp(0.0, 1.0));

  /// Прозрачность крупного заголовка нижнего ряда (`bottomTitleAlpha`).
  static double largeTitleAlphaFor(double fraction) =>
      1 - fraction.clamp(0.0, 1.0);

  @override
  State<SliverMediumFlexibleAppBar> createState() =>
      _SliverMediumFlexibleAppBarState();
}

class _SliverMediumFlexibleAppBarState extends State<SliverMediumFlexibleAppBar>
    implements _SettleTarget {
  final _CollapseMetrics _metrics = _CollapseMetrics();
  _M3AppBarSettleState? _settle;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _M3AppBarSettleState? settle = context
        .dependOnInheritedWidgetOfExactType<_M3AppBarSettleScope>()
        ?.state;
    if (settle != _settle) {
      _settle?._targets.remove(this);
      _settle = settle?.._targets.add(this);
    }
    _position = Scrollable.maybeOf(context)?.position;
  }

  @override
  void dispose() {
    _settle?._targets.remove(this);
    super.dispose();
  }

  /// `settleAppBar`: если бар остался между состояниями, довести его к
  /// ближайшему пружиной `TopAppBarDefaults.snapAnimationSpec`
  /// (= `MotionSchemeKeyTokens.DefaultEffects`).
  ///
  /// Инерцию (`flingAnimationSpec`) отдельно гасить не нужно: во Flutter
  /// сворачивание — часть прокрутки, и бросок уже отыгран физикой списка.
  @override
  void settle({required bool reduceMotion}) {
    final ScrollPosition? position = _position;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions ||
        position.isScrollingNotifier.value) {
      return;
    }
    final double range = _metrics.collapseRange;
    if (range <= 0) return;
    final double shrinkOffset = clampDouble(
      position.pixels - _metrics.leadingScrollOffset,
      0,
      range,
    );
    final double fraction = shrinkOffset / range;
    // «Check if the app bar is completely collapsed/expanded».
    if (fraction < 0.01 || fraction == 1) return;

    final double target = clampDouble(
      position.pixels + (fraction < 0.5 ? -shrinkOffset : range - shrinkOffset),
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < precisionErrorTolerance) return;
    if (reduceMotion) {
      position.jumpTo(target);
    } else {
      // Пружина DefaultEffects (damping 1) из покоя: `AppMotion.defaultEffects.curve`
      // — это сама симуляция, нормированная на время успокоения.
      position.animateTo(
        target,
        duration: AppMotion.defaultEffects.duration,
        curve: AppMotion.defaultEffects.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final bool hasSubtitle = widget.subtitle != null;

    // `AppBarMediumFlexibleTokens.TitleFont` / `SubtitleFont`;
    // цвета `AppBarTokens.TitleColor` / `SubtitleColor`.
    final TextStyle largeTitleStyle = text.headlineMedium!.copyWith(
      color: colors.onSurface,
    );
    final TextStyle largeSubtitleStyle = text.labelLarge!.copyWith(
      color: colors.onSurfaceVariant,
    );

    return _SliverTwoRowsTopAppBar(
      metrics: _metrics,
      padding: EdgeInsets.only(
        left: padding.left,
        top: padding.top,
        right: padding.right,
      ),
      collapsedHeight: SliverMediumFlexibleAppBar.collapsedHeight,
      expandedHeight: hasSubtitle
          ? SliverMediumFlexibleAppBar.expandedHeightWithSubtitle
          : SliverMediumFlexibleAppBar.expandedHeight,
      titleBottomPadding: SliverMediumFlexibleAppBar.titleBottomPadding,
      largeTitleLastLineDescent: _lastLineDescent(
        context,
        hasSubtitle ? largeSubtitleStyle : largeTitleStyle,
      ),
      colors: colors,
      textDirection: Directionality.of(context),
      navigationIcon: _NavigationIconSlot(
        leading: widget.leading,
        inkCanvas: true,
      ),
      smallTitle: _TitleBlock(
        title: widget.title,
        subtitle: widget.subtitle,
        // `AppBarSmallTokens.TitleFont` / `SubtitleFont`.
        titleStyle: text.titleLarge!.copyWith(color: colors.onSurface),
        subtitleStyle: text.labelMedium!.copyWith(
          color: colors.onSurfaceVariant,
        ),
        // В small app bar текст не переносится (Guidelines → Headline:
        // «Don't wrap text in a small app bar»).
        titleMaxLines: 1,
        subtitleMaxLines: 1,
      ),
      actions: _ActionsSlot(actions: widget.actions, inkCanvas: true),
      largeTitle: _TitleBlock(
        title: widget.title,
        subtitle: widget.subtitle,
        titleStyle: largeTitleStyle,
        subtitleStyle: largeSubtitleStyle,
        // «wrap the headline to two lines maximum».
        titleMaxLines: 2,
        subtitleMaxLines: null,
      ),
    );
  }
}

/// Доводка flexible app bar после прокрутки.
///
/// Оборачивает `CustomScrollView` или `NestedScrollView`, внутри которого
/// стоит [SliverMediumFlexibleAppBar]. Когда прокрутка по вертикали
/// закончилась (палец отпущен и бросок отыгран — как `onPostFling` в
/// `ExitUntilCollapsedScrollBehavior`) и бар остался между состояниями,
/// список докручивается: при `collapsedFraction < 0.5` бар разворачивается,
/// иначе сворачивается (`settleAppBar`). Новое касание прерывает доводку.
///
/// Бары внутри регистрируются сами, настраивать ничего не нужно.
class M3AppBarSettle extends StatefulWidget {
  const M3AppBarSettle({super.key, required this.child});

  final Widget child;

  @override
  State<M3AppBarSettle> createState() => _M3AppBarSettleState();
}

class _M3AppBarSettleState extends State<M3AppBarSettle> {
  final Set<_SettleTarget> _targets = <_SettleTarget>{};
  bool _scheduled = false;

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_targets.isEmpty || _scheduled) return false;
    // Уведомление приходит изнутри `ScrollPosition.beginActivity`, пока старая
    // активность ещё не заменена. Запускать новую анимацию прокрутки прямо
    // здесь нельзя — её сразу же уничтожат, поэтому доводка идёт микрозадачей.
    _scheduled = true;
    scheduleMicrotask(_settleAll);
    return false;
  }

  void _settleAll() {
    _scheduled = false;
    if (!mounted) return;
    final bool reduceMotion = reduceMotionOf(context);
    for (final _SettleTarget target in _targets.toList()) {
      target.settle(reduceMotion: reduceMotion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _M3AppBarSettleScope(
      state: this,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _handleScrollEnd,
        child: widget.child,
      ),
    );
  }
}

class _M3AppBarSettleScope extends InheritedWidget {
  const _M3AppBarSettleScope({required this.state, required super.child});

  final _M3AppBarSettleState state;

  @override
  bool updateShouldNotify(_M3AppBarSettleScope oldWidget) =>
      state != oldWidget.state;
}

abstract interface class _SettleTarget {
  void settle({required bool reduceMotion});
}

/// Размеры сворачивания, которые сливер сообщает доводке при раскладке.
class _CollapseMetrics {
  /// `-heightOffsetLimit`: полная высота нижнего ряда.
  double collapseRange = 0;

  /// Смещение прокрутки, с которого начинается бар.
  double leadingScrollOffset = 0;
}

/// Small app bar Material 3 Expressive.
///
/// Порт Compose `TopAppBar(title, subtitle, …)` → `SingleRowTopAppBar`
/// (`AppBar.kt`) с `TopAppBarDefaults.pinnedScrollBehavior()`:
///   * высота `AppBarSmallTokens.ContainerHeight` = 64dp плюс статус-бар, фон
///     рисуется и под ним;
///   * leading с отступом 4dp; заголовок начинается сразу после него —
///     `max(12, ширина leading)` + 4dp, то есть 56dp после кнопки 48dp и
///     16dp без leading; actions с отступом 4dp от края;
///   * title `titleLarge` (`onSurface`), subtitle `labelMedium`
///     (`onSurfaceVariant`), по одной строке;
///   * как только содержимое уходит под бар (`overlappedFraction > 0.01`),
///     контейнер меняет цвет `surface` → `surfaceContainer` пружиной
///     `MotionSchemeKeyTokens.DefaultEffects` и обратно.
///
/// Прокрутку слушает через [ScrollNotificationObserver] — его даёт
/// [Scaffold], как и для `AppBar` Flutter. Учитываются списки глубины 0.
class M3SmallAppBar extends StatefulWidget implements PreferredSizeWidget {
  const M3SmallAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// `TopAppBarDefaults.TopAppBarExpandedHeight` = `AppBarSmallTokens.ContainerHeight`.
  static const double height = 64;

  /// Бар растёт по тексту (`max(height, titlePlaceable.height)`), но
  /// [Scaffold] ограничивает `appBar` высотой [preferredSize]. Чтобы при
  /// крупном шрифте с подзаголовком текст не обрезался, в `Scaffold.appBar`
  /// кладут `PreferredSize(preferredSize: Size.fromHeight(
  /// M3SmallAppBar.preferredHeightOf(context, withSubtitle: true)), …)`.
  @override
  Size get preferredSize => const Size.fromHeight(height);

  /// Высота бара без статус-бара при текущем масштабе шрифта.
  static double preferredHeightOf(
    BuildContext context, {
    bool withSubtitle = false,
  }) {
    final TextTheme text = Theme.of(context).textTheme;
    double block = _lineHeight(context, text.titleLarge!);
    if (withSubtitle) block += _lineHeight(context, text.labelMedium!);
    return math.max(height, block);
  }

  /// Цвет контейнера при прогрессе анимации 0 (`containerColor`) … 1
  /// (`scrolledContainerColor`); как `animateColorAsState`, в Oklab.
  static Color containerColorFor(ColorScheme colors, double progress) =>
      _lerpOklab(
        colors.surface,
        colors.surfaceContainer,
        progress.clamp(0.0, 1.0),
      );

  @override
  State<M3SmallAppBar> createState() => _M3SmallAppBarState();
}

class _M3SmallAppBarState extends State<M3SmallAppBar>
    with SingleTickerProviderStateMixin {
  /// 0 — `containerColor`, 1 — `scrolledContainerColor`.
  late final AnimationController _scrolled = AnimationController.unbounded(
    vsync: this,
  );
  ScrollNotificationObserverState? _observer;
  bool _overlapped = false;

  /// `overlappedFraction > 0.01f` при `heightOffsetLimit` = −64dp.
  static const double _overlapThreshold = 0.01 * M3SmallAppBar.height;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_handleScrollNotification);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_handleScrollNotification);
  }

  @override
  void dispose() {
    _observer?.removeListener(_handleScrollNotification);
    _scrolled.dispose();
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return;
    }
    final ScrollMetrics metrics = notification.metrics;
    final bool overlapped;
    switch (metrics.axisDirection) {
      case AxisDirection.down:
        overlapped = metrics.extentBefore > _overlapThreshold;
      case AxisDirection.up:
        overlapped = metrics.extentAfter > _overlapThreshold;
      case AxisDirection.left:
      case AxisDirection.right:
        return;
    }
    if (overlapped == _overlapped) return;
    _overlapped = overlapped;
    final double target = overlapped ? 1 : 0;
    if (reduceMotionOf(context)) {
      _scrolled.value = target;
    } else {
      // `animateColorAsState(MotionSchemeKeyTokens.DefaultEffects)`.
      _scrolled.springTo(AppMotion.defaultEffects, target).then((_) {
        // `Animatable` в Compose заканчивает ровно на цели.
        if (mounted) _scrolled.value = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final EdgeInsets padding = MediaQuery.paddingOf(context);

    final Widget content = Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.only(
          left: padding.left,
          top: padding.top,
          right: padding.right,
        ),
        // «clip after padding so we don't show the title over the inset area».
        child: ClipRect(
          child: _TopAppBarRow(
            height: M3SmallAppBar.height,
            textDirection: Directionality.of(context),
            navigationIcon: _NavigationIconSlot(
              leading: widget.leading,
              inkCanvas: false,
            ),
            title: _TitleBlock(
              title: widget.title,
              subtitle: widget.subtitle,
              titleStyle: text.titleLarge!.copyWith(color: colors.onSurface),
              subtitleStyle: text.labelMedium!.copyWith(
                color: colors.onSurfaceVariant,
              ),
              titleMaxLines: 1,
              subtitleMaxLines: 1,
            ),
            actions: _ActionsSlot(actions: widget.actions, inkCanvas: false),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _scrolled,
      child: content,
      builder: (context, child) {
        final Color color = M3SmallAppBar.containerColorFor(
          colors,
          _scrolled.value,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemOverlayStyleFor(color),
          // Material — холст для ripple кнопок поверх фона бара. Тени нет
          // (`AppBarTokens.ContainerElevation` = level0).
          child: Material(color: color, child: child),
        );
      },
    );
  }
}

/// Интерполяция цвета, как `lerp(Color, Color, Float)` из Compose
/// `ui-graphics` (`Color.kt`): через Oklab, а не покомпонентно в sRGB, как
/// `Color.lerp` Flutter. Тем же пространством пользуется
/// `Color.VectorConverter`, то есть и `animateColorAsState`.
///
/// Матрицы — из описания Oklab (Björn Ottosson, «A perceptual color space for
/// image processing»).
Color _lerpOklab(Color start, Color stop, double t) {
  if (t <= 0) return start;
  if (t >= 1) return stop;

  double toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double fromLinear(double c) => c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
  double cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

  List<double> toOklab(Color color) {
    final double r = toLinear(color.r);
    final double g = toLinear(color.g);
    final double b = toLinear(color.b);
    final double l = cbrt(
      0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    );
    final double m = cbrt(
      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    );
    final double s = cbrt(
      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    );
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  final List<double> a = toOklab(start);
  final List<double> b = toOklab(stop);
  double mix(double x, double y) => x + (y - x) * t;
  final double lightness = mix(a[0], b[0]);
  final double green = mix(a[1], b[1]);
  final double blue = mix(a[2], b[2]);

  double cube(double x) => x * x * x;
  final double l = cube(lightness + 0.3963377774 * green + 0.2158037573 * blue);
  final double m = cube(lightness - 0.1055613458 * green - 0.0638541728 * blue);
  final double s = cube(lightness - 0.0894841775 * green - 1.2914855480 * blue);
  return Color.from(
    alpha: mix(start.a, stop.a),
    red: fromLinear(
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    ).clamp(0.0, 1.0),
    green: fromLinear(
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    ).clamp(0.0, 1.0),
    blue: fromLinear(
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ).clamp(0.0, 1.0),
  );
}

/// Стиль статус-бара под цвет контейнера — как у `AppBar` Flutter
/// (`_systemOverlayStyleForBrightness`): бар рисуется под статус-баром.
SystemUiOverlayStyle _systemOverlayStyleFor(Color background) {
  final SystemUiOverlayStyle style =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarBrightness: style.statusBarBrightness,
    statusBarIconBrightness: style.statusBarIconBrightness,
    systemStatusBarContrastEnforced: style.systemStatusBarContrastEnforced,
  );
}

/// Стиль [Text] с учётом [DefaultTextStyle] и системного жирного шрифта.
TextStyle _effectiveTextStyle(BuildContext context, TextStyle style) {
  TextStyle effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  return effective;
}

TextPainter _singleLinePainter(BuildContext context, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: ' ', style: _effectiveTextStyle(context, style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    textHeightBehavior:
        DefaultTextStyle.of(context).textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
}

double _lineHeight(BuildContext context, TextStyle style) {
  final TextPainter painter = _singleLinePainter(context, style);
  final double height = painter.height;
  painter.dispose();
  return height;
}

/// Расстояние от базовой линии строки до её низа.
///
/// В Compose нижний отступ крупного заголовка отсчитывается от `LastBaseline`
/// блока «заголовок + подзаголовок». У `RenderBox` Flutter есть только первая
/// базовая линия, но у строк одного стиля метрики одинаковы, поэтому
/// `lastBaseline = высота блока − descent последней строки`.
double _lastLineDescent(BuildContext context, TextStyle style) {
  final TextPainter painter = _singleLinePainter(context, style);
  final double descent =
      painter.height -
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  painter.dispose();
  return descent;
}

/// Заголовок и подзаголовок одним блоком: `Column` из `TopAppBarLayout` с
/// отступами 4dp по бокам.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.titleMaxLines,
    required this.subtitleMaxLines,
  });

  final String title;
  final String? subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final int titleMaxLines;
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accessibility → Labeling elements: у заголовка роль «Title».
          Semantics(
            header: true,
            child: Text(
              title,
              style: titleStyle,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: subtitleStyle,
              maxLines: subtitleMaxLines,
              overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// `Box(Modifier.padding(start = TopAppBarHorizontalPadding))` с
/// `LocalContentColor = navigationIconContentColor` (`onSurface`).
class _NavigationIconSlot extends StatelessWidget {
  const _NavigationIconSlot({required this.leading, required this.inkCanvas});

  final Widget? leading;

  /// Сливер рисует фон сам, поэтому ripple нужен свой прозрачный Material.
  final bool inkCanvas;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = this.leading;
    Widget? child;
    if (leading != null) {
      final Color color = Theme.of(context).colorScheme.onSurface;
      child = IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: color,
          ).merge(IconButtonTheme.of(context).style),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: color),
          child: leading,
        ),
      );
      if (inkCanvas) {
        child = Material(type: MaterialType.transparency, child: child);
      }
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kHorizontalPadding),
      child: child,
    );
  }
}

/// `Box(Modifier.padding(end = TopAppBarHorizontalPadding))` с рядом кнопок и
/// `LocalContentColor = actionIconContentColor` (`onSurfaceVariant`).
class _ActionsSlot extends StatelessWidget {
  const _ActionsSlot({required this.actions, required this.inkCanvas});

  final List<Widget> actions;
  final bool inkCanvas;

  @override
  Widget build(BuildContext context) {
    Widget? child;
    if (actions.isNotEmpty) {
      child = IconTheme.merge(
        data: IconThemeData(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
      if (inkCanvas) {
        child = Material(type: MaterialType.transparency, child: child);
      }
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kHorizontalPadding),
      child: child,
    );
  }
}

/// Начало заголовка в ряду `TopAppBarLayout`
/// (`TopAppBarMeasurePolicy.placeTopAppBar`): `max(TopAppBarTitleInset,
/// ширина navigationIcon)`.
double _titleStartFor(double navigationIconWidth) =>
    math.max(_kTitleInset, navigationIconWidth);

/// x считается «слева направо»; в RTL ряд зеркалится, как `placeRelative`.
double _mirrored(
  double x,
  double childWidth,
  double rowWidth,
  TextDirection textDirection,
) => textDirection == TextDirection.rtl ? rowWidth - x - childWidth : x;

// ---------------------------------------------------------------------------
// Medium flexible: сливер с двумя рядами.

enum _TwoRowsSlot { navigationIcon, smallTitle, actions, largeTitle }

class _SliverTwoRowsTopAppBar
    extends SlottedMultiChildRenderObjectWidget<_TwoRowsSlot, RenderBox> {
  const _SliverTwoRowsTopAppBar({
    required this.metrics,
    required this.padding,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.titleBottomPadding,
    required this.largeTitleLastLineDescent,
    required this.colors,
    required this.textDirection,
    required this.navigationIcon,
    required this.smallTitle,
    required this.actions,
    required this.largeTitle,
  });

  final _CollapseMetrics metrics;
  final EdgeInsets padding;
  final double collapsedHeight;
  final double expandedHeight;
  final double titleBottomPadding;
  final double largeTitleLastLineDescent;
  final ColorScheme colors;
  final TextDirection textDirection;
  final Widget navigationIcon;
  final Widget smallTitle;
  final Widget actions;
  final Widget largeTitle;

  @override
  Iterable<_TwoRowsSlot> get slots => _TwoRowsSlot.values;

  @override
  Widget childForSlot(_TwoRowsSlot slot) => switch (slot) {
    _TwoRowsSlot.navigationIcon => navigationIcon,
    _TwoRowsSlot.smallTitle => smallTitle,
    _TwoRowsSlot.actions => actions,
    _TwoRowsSlot.largeTitle => largeTitle,
  };

  @override
  _RenderSliverTwoRowsTopAppBar createRenderObject(BuildContext context) {
    return _RenderSliverTwoRowsTopAppBar(
      metrics: metrics,
      padding: padding,
      collapsedHeight: collapsedHeight,
      expandedHeight: expandedHeight,
      titleBottomPadding: titleBottomPadding,
      largeTitleLastLineDescent: largeTitleLastLineDescent,
      containerColor: colors.surface,
      scrolledContainerColor: colors.surfaceContainer,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverTwoRowsTopAppBar renderObject,
  ) {
    renderObject
      ..metrics = metrics
      ..padding = padding
      ..collapsedHeight = collapsedHeight
      ..expandedHeight = expandedHeight
      ..titleBottomPadding = titleBottomPadding
      ..largeTitleLastLineDescent = largeTitleLastLineDescent
      ..containerColor = colors.surface
      ..scrolledContainerColor = colors.surfaceContainer
      ..textDirection = textDirection;
  }
}

/// Раскладка и отрисовка `TwoRowsTopAppBar` в виде pinned-сливера.
///
/// Экстенты не задаются заранее, как у [SliverPersistentHeader], а берутся из
/// раскладки рядов: верхний — `max(64, маленький блок)`, нижний —
/// `max(expanded − collapsed, крупный блок)`. Прокрутка не перестраивает
/// виджеты: прозрачность, цвет и семантика меняются при раскладке и
/// отрисовке.
class _RenderSliverTwoRowsTopAppBar extends RenderSliver
    with
        SlottedContainerRenderObjectMixin<_TwoRowsSlot, RenderBox>,
        RenderSliverHelpers {
  _RenderSliverTwoRowsTopAppBar({
    required this._metrics,
    required this._padding,
    required this._collapsedHeight,
    required this._expandedHeight,
    required this._titleBottomPadding,
    required this._largeTitleLastLineDescent,
    required this._containerColor,
    required this._scrolledContainerColor,
    required this._textDirection,
  });

  _CollapseMetrics _metrics;
  set metrics(_CollapseMetrics value) {
    if (identical(value, _metrics)) return;
    _metrics = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  double _collapsedHeight;
  set collapsedHeight(double value) {
    if (value == _collapsedHeight) return;
    _collapsedHeight = value;
    markNeedsLayout();
  }

  double _expandedHeight;
  set expandedHeight(double value) {
    if (value == _expandedHeight) return;
    _expandedHeight = value;
    markNeedsLayout();
  }

  double _titleBottomPadding;
  set titleBottomPadding(double value) {
    if (value == _titleBottomPadding) return;
    _titleBottomPadding = value;
    markNeedsLayout();
  }

  double _largeTitleLastLineDescent;
  set largeTitleLastLineDescent(double value) {
    if (value == _largeTitleLastLineDescent) return;
    _largeTitleLastLineDescent = value;
    markNeedsLayout();
  }

  Color _containerColor;
  set containerColor(Color value) {
    if (value == _containerColor) return;
    _containerColor = value;
    markNeedsPaint();
  }

  Color _scrolledContainerColor;
  set scrolledContainerColor(Color value) {
    if (value == _scrolledContainerColor) return;
    _scrolledContainerColor = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _navigationIcon => childForSlot(_TwoRowsSlot.navigationIcon)!;
  RenderBox get _smallTitle => childForSlot(_TwoRowsSlot.smallTitle)!;
  RenderBox get _actions => childForSlot(_TwoRowsSlot.actions)!;
  RenderBox get _largeTitle => childForSlot(_TwoRowsSlot.largeTitle)!;

  // Результаты последней раскладки.
  double _extent = 0;
  double _collapsedFraction = 0;
  Rect _topRow = Rect.zero;
  Rect _bottomRow = Rect.zero;
  bool _topTitleSemanticsHidden = true;

  final LayerHandle<ClipRectLayer> _topClip = LayerHandle<ClipRectLayer>();
  final LayerHandle<ClipRectLayer> _bottomClip = LayerHandle<ClipRectLayer>();
  final LayerHandle<OpacityLayer> _smallTitleOpacity =
      LayerHandle<OpacityLayer>();
  final LayerHandle<OpacityLayer> _largeTitleOpacity =
      LayerHandle<OpacityLayer>();

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  /// Стиль статус-бара кладётся слоем [AnnotatedRegionLayer].
  @override
  bool get alwaysNeedsCompositing => true;

  Offset _offsetOf(RenderBox child) =>
      (child.parentData! as BoxParentData).offset;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    assert(
      constraints.axis == Axis.vertical,
      'SliverMediumFlexibleAppBar работает только в вертикальном списке.',
    );
    final double width = constraints.crossAxisExtent;
    // `windowInsetsPadding(windowInsets)`: по бокам и сверху.
    final double rowWidth = math.max(0.0, width - _padding.horizontal);
    final BoxConstraints loose = BoxConstraints(maxWidth: rowWidth);

    // Верхний ряд: `TopAppBarLayout(height = collapsedHeight,
    // titleVerticalArrangement = Arrangement.Center)`.
    final RenderBox navigationIcon = _navigationIcon;
    final RenderBox actions = _actions;
    final RenderBox smallTitle = _smallTitle;
    navigationIcon.layout(loose, parentUsesSize: true);
    actions.layout(loose, parentUsesSize: true);
    final double titleStart = _titleStartFor(navigationIcon.size.width);
    smallTitle.layout(
      BoxConstraints(
        maxWidth: math.max(0.0, rowWidth - titleStart - actions.size.width),
      ),
      parentUsesSize: true,
    );
    final double topRowHeight = math.max(
      _collapsedHeight,
      smallTitle.size.height,
    );

    // Нижний ряд: `navigationIcon = {}` и `actions = {}` — остаются только
    // отступы 4dp, поэтому заголовок стоит на `max(12, 4)` и справа
    // резервируется 4dp.
    final RenderBox largeTitle = _largeTitle;
    const double largeTitleStart = _kTitleInset;
    largeTitle.layout(
      BoxConstraints(
        maxWidth: math.max(
          0.0,
          rowWidth - largeTitleStart - _kHorizontalPadding,
        ),
      ),
      parentUsesSize: true,
    );
    final double bottomRowMaxHeight = math.max(
      _expandedHeight - _collapsedHeight,
      largeTitle.size.height,
    );

    final double minExtent = _padding.top + topRowHeight;
    final double maxExtent = minExtent + bottomRowMaxHeight;

    // `heightOffset` ∈ [heightOffsetLimit, 0], `heightOffsetLimit` = −высота
    // нижнего ряда (`adjustHeightOffsetLimit`).
    final double shrinkOffset = clampDouble(
      constraints.scrollOffset,
      0.0,
      bottomRowMaxHeight,
    );
    final double bottomRowHeight = bottomRowMaxHeight - shrinkOffset;
    _collapsedFraction = bottomRowMaxHeight > 0
        ? shrinkOffset / bottomRowMaxHeight
        : 0.0;
    _extent = minExtent + bottomRowHeight;
    _topRow = Rect.fromLTWH(
      _padding.left,
      _padding.top,
      rowWidth,
      topRowHeight,
    );
    _bottomRow = Rect.fromLTWH(
      _padding.left,
      _padding.top + topRowHeight,
      rowWidth,
      bottomRowHeight,
    );

    // «Hide the top row title semantics when its alpha value goes below 0.5
    // threshold».
    final bool hideTop = _collapsedFraction < 0.5;
    if (hideTop != _topTitleSemanticsHidden) {
      _topTitleSemanticsHidden = hideTop;
      markNeedsSemanticsUpdate();
    }

    void place(RenderBox child, double x, double y) {
      (child.parentData! as BoxParentData).offset = Offset(
        _padding.left +
            _mirrored(x, child.size.width, rowWidth, _textDirection),
        y,
      );
    }

    final double topY = _padding.top;
    place(
      navigationIcon,
      0,
      topY + (topRowHeight - navigationIcon.size.height) / 2,
    );
    place(
      smallTitle,
      titleStart,
      topY + (topRowHeight - smallTitle.size.height) / 2,
    );
    place(
      actions,
      rowWidth - actions.size.width,
      topY + (topRowHeight - actions.size.height) / 2,
    );

    // `Arrangement.Bottom` с `titleBottomPadding`: отступ считается от
    // последней базовой линии и уменьшается, если блоку не хватает места.
    final double titleHeight = largeTitle.size.height;
    final double lastBaseline = titleHeight - _largeTitleLastLineDescent;
    final double paddingFromBottom =
        _titleBottomPadding - (titleHeight - lastBaseline);
    final double heightWithPadding = paddingFromBottom + titleHeight;
    final double adjustedBottomPadding = heightWithPadding > bottomRowMaxHeight
        ? paddingFromBottom - (heightWithPadding - bottomRowMaxHeight)
        : paddingFromBottom;
    place(
      largeTitle,
      largeTitleStart,
      topY +
          topRowHeight +
          bottomRowHeight -
          titleHeight -
          math.max(0.0, adjustedBottomPadding),
    );

    _metrics
      ..collapseRange = bottomRowMaxHeight
      ..leadingScrollOffset = constraints.precedingScrollExtent;

    // Геометрия — как у `RenderSliverPinnedPersistentHeader`.
    final double effectiveRemainingPaintExtent = math.max(
      0.0,
      constraints.remainingPaintExtent - constraints.overlap,
    );
    final double layoutExtent = clampDouble(
      maxExtent - constraints.scrollOffset,
      0.0,
      effectiveRemainingPaintExtent,
    );
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: constraints.overlap,
      paintExtent: math.min(_extent, effectiveRemainingPaintExtent),
      layoutExtent: layoutExtent,
      maxPaintExtent: maxExtent,
      maxScrollObstructionExtent: minExtent,
      cacheExtent: layoutExtent > 0.0
          ? -constraints.cacheOrigin + layoutExtent
          : layoutExtent,
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    final Size size = Size(constraints.crossAxisExtent, _extent);
    // `TopAppBarColors.containerColor(collapsedFraction)` — повторяет
    // прокрутку без собственной анимации.
    final Color background = _lerpOklab(
      _containerColor,
      _scrolledContainerColor,
      Easing.legacyAccelerate.transform(_collapsedFraction),
    );
    context.pushLayer(
      AnnotatedRegionLayer<SystemUiOverlayStyle>(
        _systemOverlayStyleFor(background),
        size: size,
        offset: offset,
      ),
      (context, offset) => _paintContents(context, offset, size, background),
      offset,
    );
  }

  void _paintContents(
    PaintingContext context,
    Offset offset,
    Size size,
    Color background,
  ) {
    context.canvas.drawRect(offset & size, Paint()..color = background);

    _topClip.layer = context.pushClipRect(needsCompositing, offset, _topRow, (
      context,
      offset,
    ) {
      context.paintChild(_navigationIcon, offset + _offsetOf(_navigationIcon));
      _smallTitleOpacity.layer = _paintWithAlpha(
        context,
        offset,
        _smallTitle,
        SliverMediumFlexibleAppBar.smallTitleAlphaFor(_collapsedFraction),
        _smallTitleOpacity.layer,
      );
      context.paintChild(_actions, offset + _offsetOf(_actions));
    }, oldLayer: _topClip.layer);

    if (_bottomRow.height > 0) {
      _bottomClip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        _bottomRow,
        (context, offset) {
          _largeTitleOpacity.layer = _paintWithAlpha(
            context,
            offset,
            _largeTitle,
            SliverMediumFlexibleAppBar.largeTitleAlphaFor(_collapsedFraction),
            _largeTitleOpacity.layer,
          );
        },
        oldLayer: _bottomClip.layer,
      );
    } else {
      _bottomClip.layer = null;
      _largeTitleOpacity.layer = null;
    }
  }

  /// `graphicsLayer { alpha = … }`.
  OpacityLayer? _paintWithAlpha(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    double alpha,
    OpacityLayer? oldLayer,
  ) {
    final int value = Color.getAlphaFromOpacity(alpha);
    if (value == 0) return null;
    return context.pushOpacity(
      offset,
      value,
      (context, offset) => context.paintChild(child, offset + _offsetOf(child)),
      oldLayer: oldLayer,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) => _offsetOf(child).dy;

  @override
  double childCrossAxisPosition(RenderBox child) => _offsetOf(child).dx;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    applyPaintTransformForBoxChild(child as RenderBox, transform);
  }

  /// Бар не пропускает нажатия к содержимому, уехавшему под него
  /// (`pointerInput(Unit) {}` в Compose).
  @override
  bool hitTestSelf({
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) => true;

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final BoxHitTestResult boxResult = BoxHitTestResult.wrap(result);
    final Offset position = Offset(crossAxisPosition, mainAxisPosition);
    final List<RenderBox> candidates = _topRow.contains(position)
        ? [_actions, _smallTitle, _navigationIcon]
        : _bottomRow.contains(position)
        ? [_largeTitle]
        : const [];
    for (final RenderBox child in candidates) {
      if (hitTestBoxChild(
        boxResult,
        child,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      identical(child, _largeTitle) ? _bottomRow : _topRow;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_navigationIcon);
    if (!_topTitleSemanticsHidden) visitor(_smallTitle);
    visitor(_actions);
    if (_topTitleSemanticsHidden) visitor(_largeTitle);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.addTagForChildren(RenderViewport.excludeFromScrolling);
  }

  @override
  void dispose() {
    _topClip.layer = null;
    _bottomClip.layer = null;
    _smallTitleOpacity.layer = null;
    _largeTitleOpacity.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('collapsedFraction', _collapsedFraction));
    properties.add(DoubleProperty('extent', _extent));
  }
}

// ---------------------------------------------------------------------------
// Small: один ряд `TopAppBarLayout`.

enum _RowSlot { navigationIcon, title, actions }

class _TopAppBarRow
    extends SlottedMultiChildRenderObjectWidget<_RowSlot, RenderBox> {
  const _TopAppBarRow({
    required this.height,
    required this.textDirection,
    required this.navigationIcon,
    required this.title,
    required this.actions,
  });

  final double height;
  final TextDirection textDirection;
  final Widget navigationIcon;
  final Widget title;
  final Widget actions;

  @override
  Iterable<_RowSlot> get slots => _RowSlot.values;

  @override
  Widget childForSlot(_RowSlot slot) => switch (slot) {
    _RowSlot.navigationIcon => navigationIcon,
    _RowSlot.title => title,
    _RowSlot.actions => actions,
  };

  @override
  _RenderTopAppBarRow createRenderObject(BuildContext context) =>
      _RenderTopAppBarRow(height: height, textDirection: textDirection);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTopAppBarRow renderObject,
  ) {
    renderObject
      ..height = height
      ..textDirection = textDirection;
  }
}

/// `TopAppBarMeasurePolicy` с `Arrangement.Center` и нулевым смещением
/// прокрутки.
class _RenderTopAppBarRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_RowSlot, RenderBox> {
  _RenderTopAppBarRow({required this._height, required this._textDirection});

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _navigationIcon => childForSlot(_RowSlot.navigationIcon)!;
  RenderBox get _title => childForSlot(_RowSlot.title)!;
  RenderBox get _actions => childForSlot(_RowSlot.actions)!;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  ({Size navigationIcon, Size title, Size actions, Size size}) _measure(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final double maxWidth = constraints.maxWidth;
    final BoxConstraints loose = BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: constraints.maxHeight,
    );
    final Size navigationIcon = layoutChild(_navigationIcon, loose);
    final Size actions = layoutChild(_actions, loose);
    final double titleStart = _titleStartFor(navigationIcon.width);
    final Size title = layoutChild(
      _title,
      BoxConstraints(
        maxWidth: maxWidth.isFinite
            ? math.max(0.0, maxWidth - titleStart - actions.width)
            : double.infinity,
        maxHeight: constraints.maxHeight,
      ),
    );
    final double width = maxWidth.isFinite
        ? maxWidth
        : titleStart + title.width + actions.width;
    return (
      navigationIcon: navigationIcon,
      title: title,
      actions: actions,
      size: constraints.constrain(Size(width, math.max(_height, title.height))),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _measure(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(_height, _title.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(_height, _title.getMaxIntrinsicHeight(width));

  @override
  double computeMinIntrinsicWidth(double height) =>
      _navigationIcon.getMinIntrinsicWidth(height) +
      _title.getMinIntrinsicWidth(height) +
      _actions.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _navigationIcon.getMaxIntrinsicWidth(height) +
      _title.getMaxIntrinsicWidth(height) +
      _actions.getMaxIntrinsicWidth(height);

  @override
  void performLayout() {
    final measured = _measure(constraints, ChildLayoutHelper.layoutChild);
    size = measured.size;
    final double rowWidth = size.width;
    final double contentHeight = size.height;

    void place(RenderBox child, double x) {
      (child.parentData! as BoxParentData).offset = Offset(
        _mirrored(x, child.size.width, rowWidth, _textDirection),
        (contentHeight - child.size.height) / 2,
      );
    }

    place(_navigationIcon, 0);
    place(_title, _titleStartFor(_navigationIcon.size.width));
    place(_actions, rowWidth - _actions.size.width);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final RenderBox child in [_navigationIcon, _title, _actions]) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in [_actions, _title, _navigationIcon]) {
      final Offset childOffset = (child.parentData! as BoxParentData).offset;
      final bool hit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
