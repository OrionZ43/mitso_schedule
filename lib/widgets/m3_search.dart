import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_motion.dart';

/// Строка поиска M3 Expressive с раскрытием в полноэкранный поиск стиля
/// **contained** (рекомендован в Expressive, divided — «Not recommended»).
///
/// https://m3.material.io/components/search/guidelines
///
/// Порт Compose `SearchBar.kt`:
///   * свёрнутая строка — `SearchBarImpl` + `SearchBarDefaults.InputField`:
///     таблетка 56dp `surfaceContainerHigh` без тени, ширина 360..720dp
///     (`SearchBarTokens`, `SearchBarMinWidth` / `SearchBarMaxWidth`);
///   * открытый поиск — `ExpandedFullScreenContainedSearchBar` →
///     `FullScreenSearchBarLayout(isContained = true)`: подложка
///     `surfaceContainerLow` проявляется по прогрессу, строка остаётся
///     таблеткой и переезжает наверх (`insets.top + 4dp`), контент — на 8dp ниже;
///   * движение — `rememberContainedSearchBarState`: пружина `FastSpatial` в
///     обе стороны, контент проявляется через 50 мс за 100 мс
///     (`AnimationForContentFadeInSpec`) и гаснет за 100 мс
///     (`AnimationForContentFadeOutSpec`).
///
/// Поля строки от краёв экрана (24dp без фокуса,
/// `md.comp.search-bar.contained.leading-margin`) задаёт экран, в который
/// строку вставляют.
///
/// [contentBuilder] — обычный builder: он перестраивается при каждом
/// изменении запроса и при перестройке [M3SearchBar], поэтому
/// `ConsumerWidget` внутри обновляются сами. Изнутри контента доступен
/// [M3SearchScope]: закрыть поиск, подставить запрос, озвучить результаты.
class M3SearchBar extends StatefulWidget {
  const M3SearchBar({
    super.key,
    required this.hintText,
    required this.contentBuilder,
    this.controller,
    this.onSearch,
  });

  /// Подсказка в пустой строке и доступное имя поля
  /// (Search → Accessibility: «the search bar's hint text is its label»).
  final String hintText;

  /// Содержимое открытого поиска под строкой: подсказки, фильтры, результаты.
  final Widget Function(BuildContext context, String query) contentBuilder;

  /// Текст запроса. Общий для свёрнутой и открытой строки: после закрытия
  /// введённый текст остаётся виден (Guidelines → Search results).
  final TextEditingController? controller;

  /// Кнопка «Поиск» на клавиатуре (`onSearch` у `InputField`,
  /// `ImeAction.Search`). Клавиатура при этом скрывается, поиск остаётся открытым.
  final ValueChanged<String>? onSearch;

  /// `SearchBarTokens.ContainerHeight` — `SearchBarDefaults.InputFieldHeight`.
  static const double height = 56;

  /// `SearchBarMinWidth` / `SearchBarMaxWidth`.
  static const double minWidth = 360;
  static const double maxWidth = 720;

  /// Поля строки в фокусе: `md.comp.search-view.contained.leading-margin` /
  /// `trailing-margin` = space150. Compose берёт 8dp
  /// (`FullScreenExpandedHorizontalPadding`), токен и гайд — 12dp.
  static const double expandedHorizontalMargin = 12;

  /// `AppBarWithSearchVerticalPadding`: строка ниже верхнего inset.
  static const double expandedTopPadding = 4;

  /// `SearchBarVerticalPadding`: зазор между строкой и контентом.
  static const double contentGap = 8;

  /// `SearchBarIconOffsetX`: иконки сдвинуты на 4dp внутрь, чтобы от края
  /// таблетки до иконки было 16dp.
  static const double iconOffset = 4;

  /// `TextFieldPadding`: поле текста без замыкающей кнопки.
  static const double textEndPadding = 16;

  /// `SearchBarCornerRadius` = `InputFieldHeight / 2`.
  static const double cornerRadius = height / 2;

  /// `DurationShort1` / `DurationShort2`.
  static const Duration contentFadeDelay = Duration(milliseconds: 50);
  static const Duration contentFadeDuration = Duration(milliseconds: 100);

  /// `SearchBarState.currentValue`: при прогрессе не больше 0.02 поиск
  /// считается свёрнутым, и Compose убирает диалог.
  static const double collapsedThreshold = 0.02;

  /// `SearchBarPredictiveBackMinScale`, `SearchBarPredictiveBackMinMargin`,
  /// `SearchBarPredictiveBackMaxOffsetY`.
  static const double predictiveBackMinScale = 0.9;
  static const double predictiveBackMinMargin = 8;
  static const double predictiveBackMaxOffsetY = 24;

  @override
  State<M3SearchBar> createState() => _M3SearchBarState();
}

class _M3SearchBarState extends State<M3SearchBar> {
  final GlobalKey _barKey = GlobalKey();
  TextEditingController? _ownController;
  _M3SearchRoute? _route;

  /// Compose `AppBarWithSearch` прячет свёрнутую строку, пока открытый поиск
  /// сворачивается поверх неё (`isVisible`).
  final ValueNotifier<bool> _hideCollapsed = ValueNotifier<bool>(false);

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void didUpdateWidget(M3SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _M3SearchRoute? route = _route;
    if (route == null) return;
    // Новый contentBuilder — перестроить открытый поиск. Во время build
    // чужое поддерево помечать нельзя, поэтому — после кадра.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.changedExternalState();
    });
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _hideCollapsed.dispose();
    super.dispose();
  }

  /// Прямоугольник свёрнутой строки в глобальных координатах —
  /// `SearchBarState.collapsedBounds`.
  Rect? _collapsedRect() {
    final RenderObject? box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _open() async {
    if (_route != null) return;
    final Rect? rect = _collapsedRect();
    if (rect == null) return;
    // Compose показывает открытый поиск в отдельном полноэкранном окне
    // (`BasicEdgeToEdgeDialog`), поэтому — корневой навигатор.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final _M3SearchRoute route = _M3SearchRoute(
      owner: this,
      lastCollapsedRect: rect,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    );
    _route = route;
    await navigator.push(route);
    if (!mounted) return;
    _route = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hideCollapsed,
      builder: (context, hide, child) =>
          Opacity(opacity: hide ? 0 : 1, child: child),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: M3SearchBar.minWidth,
          maxWidth: M3SearchBar.maxWidth,
          minHeight: M3SearchBar.height,
          maxHeight: M3SearchBar.height,
        ),
        child: KeyedSubtree(
          key: _barKey,
          child: _SearchFieldContainer(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _CollapsedField(
                hintText: widget.hintText,
                query: _controller.text,
                onOpen: _open,
                onClear: _controller.clear,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Таблетка поля: `surfaceContainerHigh`, `corner.full`, без тени
/// (`SearchBarDefaults.containedColors` → `inputFieldColors`,
/// `SearchBarDefaults.ShadowElevation` = Level0).
class _SearchFieldContainer extends StatelessWidget {
  const _SearchFieldContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Ячейка иконки: зона 48dp (`minimumInteractiveComponentSize`), сдвинутая
/// на 4dp внутрь таблетки (`SearchBarIconOffsetX`).
class _IconSlot extends StatelessWidget {
  const _IconSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: 48, child: Center(child: child));
}

/// Кнопка «Очистить» — замыкающая иконка `onSurfaceVariant`
/// (`SearchBarTokens.TrailingIconColor`).
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _IconSlot(
      child: IconButton(
        tooltip: 'Очистить',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        icon: const Icon(Symbols.close),
        onPressed: onPressed,
      ),
    );
  }
}

/// Свёрнутая строка. В Compose это то же `InputField`, что и в открытом
/// поиске, только без фокуса: касание фокусирует поле и раскрывает поиск.
class _CollapsedField extends StatelessWidget {
  const _CollapsedField({
    required this.hintText,
    required this.query,
    required this.onOpen,
    required this.onClear,
  });

  final String hintText;
  final String query;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style = Theme.of(context).textTheme.bodyLarge!;
    final bool empty = query.isEmpty;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            textField: true,
            label: hintText,
            value: query,
            onTap: onOpen,
            excludeSemantics: true,
            child: InkWell(
              onTap: onOpen,
              // У текстового поля нет ripple.
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Row(
                children: [
                  const SizedBox(width: M3SearchBar.iconOffset),
                  _IconSlot(
                    child: Icon(Symbols.search, color: scheme.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      empty ? hintText : query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: empty
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (empty) const SizedBox(width: M3SearchBar.textEndPadding),
                ],
              ),
            ),
          ),
        ),
        if (!empty) ...[
          _ClearButton(onPressed: onClear),
          const SizedBox(width: M3SearchBar.iconOffset),
        ],
      ],
    );
  }
}

/// Возможности открытого поиска для его контента.
///
/// ```dart
/// M3SearchScope.of(context).announce('Найдено $count');
/// M3SearchScope.of(context).close();
/// ```
class M3SearchScope extends InheritedWidget {
  const M3SearchScope._({
    required this.query,
    required this._state,
    required super.child,
  });

  /// Текущий запрос.
  final String query;

  final _SearchOverlayState _state;

  static M3SearchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<M3SearchScope>();

  static M3SearchScope of(BuildContext context) {
    final M3SearchScope? scope = maybeOf(context);
    assert(scope != null, 'M3SearchScope есть только внутри M3SearchBar');
    return scope!;
  }

  /// Свернуть поиск с анимацией (как кнопка «Назад»).
  void close() => _state.close();

  /// Подставить запрос, например из подсказки.
  void setQuery(String query) => _state.setQuery(query);

  /// Озвучить появление подсказок или результатов (Search → Accessibility:
  /// «announce when suggestions or results appear»).
  Future<void> announce(String message) => _state.announce(message);

  @override
  bool updateShouldNotify(M3SearchScope oldWidget) => query != oldWidget.query;
}

class _M3SearchRoute extends PopupRoute<void> {
  _M3SearchRoute({
    required this.owner,
    required this.lastCollapsedRect,
    required this.capturedThemes,
  });

  final _M3SearchBarState owner;
  final CapturedThemes capturedThemes;

  /// Последний известный прямоугольник свёрнутой строки.
  Rect lastCollapsedRect;

  // Анимацию рисуют свои пружины (_SearchOverlayState); маршрут только
  // держит оверлей, пока они идут.
  @override
  Duration get transitionDuration => AppMotion.fastSpatial.duration;

  @override
  Duration get reverseTransitionDuration => AppMotion.fastSpatial.duration;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// Обновить [lastCollapsedRect]. Compose читает `collapsedBounds` на каждом
  /// проходе раскладки; во Flutter чужой размер во время раскладки читать
  /// нельзя, поэтому — на тике анимации, до раскладки кадра.
  void refreshCollapsedRect() {
    final Rect? rect = owner.mounted ? owner._collapsedRect() : null;
    if (rect != null) lastCollapsedRect = rect;
  }

  /// Убрать маршрут без его собственной анимации: пружина уже свернула поиск.
  void popWithoutTransition() {
    final NavigatorState? navigator = this.navigator;
    if (navigator == null || !isActive) return;
    controller?.reverseDuration = Duration.zero;
    if (isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(this);
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return capturedThemes.wrap(_SearchOverlay(route: this));
  }
}

class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({required this.route});

  final _M3SearchRoute route;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

/// Состояние жеста predictive back: первое и последнее событие
/// (`firstInProgressValue` / `lastInProgressValue` в `FullScreenSearchBarLayout`).
class _BackGesture extends ChangeNotifier {
  PredictiveBackEvent? first;
  PredictiveBackEvent? last;

  /// `PredictiveBack.transform`: `CubicBezierEasing(0.1, 0.1, 0, 1)`.
  static const Curve _easing = Cubic(0.1, 0.1, 0, 1);

  double get progress => last == null ? 0 : _easing.transform(last!.progress);

  void start(PredictiveBackEvent event) {
    first = last = event;
    notifyListeners();
  }

  void update(PredictiveBackEvent event) {
    last = event;
    notifyListeners();
  }

  void cancel() {
    first = last = null;
    notifyListeners();
  }
}

class _SearchOverlayState extends State<_SearchOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// `SearchBarState.animatable`: без ограничения 0..1 — у FastSpatial перелёт.
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
  );

  /// `SearchBarState.contentAnimatable`.
  late final AnimationController _content = AnimationController(vsync: this);

  final _BackGesture _back = _BackGesture();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<String> _query = ValueNotifier<String>('');

  bool _started = false;
  bool _closing = false;
  bool _finished = false;

  _M3SearchRoute get _route => widget.route;
  _M3SearchBarState get _owner => _route.owner;
  TextEditingController get _controller => _owner._controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _query.value = _controller.text;
    _controller.addListener(_syncQuery);
    _progress.addListener(_handleProgressTick);
    _progress.addStatusListener(_snapProgressOnComplete);
    _route.animation!.addStatusListener(_handleRouteStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _expand();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _route.animation?.removeStatusListener(_handleRouteStatus);
    _controller.removeListener(_syncQuery);
    if (_owner._hideCollapsed.value) {
      // Дерево сейчас заблокировано — вернуть свёрнутую строку после кадра.
      final _M3SearchBarState owner = _owner;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (owner.mounted) owner._hideCollapsed.value = false;
      });
    }
    _progress.dispose();
    _content.dispose();
    _back.dispose();
    _focusNode.dispose();
    _query.dispose();
    super.dispose();
  }

  void _syncQuery() => _query.value = _controller.text;

  /// `SearchBarState.animateToExpanded`.
  void _expand() {
    if (reduceMotionOf(context)) {
      _progress.value = 1;
      _content.value = 1;
      return;
    }
    _progress.springTo(AppMotion.fastSpatial, 1);
    final Duration total =
        M3SearchBar.contentFadeDelay + M3SearchBar.contentFadeDuration;
    _content.animateTo(
      1,
      duration: total,
      curve: Interval(
        M3SearchBar.contentFadeDelay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Easing.standardAccelerate,
      ),
    );
  }

  /// `SearchBarState.animateToCollapsed`; клавиатура прячется сразу
  /// (`ExpandedFullScreenSearchBarImpl`).
  void close() {
    if (_closing || !mounted) return;
    _closing = true;
    if (_owner.mounted) _owner._hideCollapsed.value = true;
    _focusNode.unfocus();
    if (reduceMotionOf(context)) {
      _progress.value = 0;
      _content.value = 0;
    } else {
      _content.animateBack(
        0,
        duration: M3SearchBar.contentFadeDuration,
        curve: Easing.standardDecelerate,
      );
      _progress.springTo(AppMotion.fastSpatial, 0);
    }
    _checkCollapsed();
  }

  // Пружина завершается в пределах допуска, а не ровно в цели.
  void _snapProgressOnComplete(AnimationStatus status) {
    if (!status.isCompleted) return;
    final double target = _closing ? 0 : 1;
    if (_progress.value != target) _progress.value = target;
  }

  void _handleProgressTick() {
    _route.refreshCollapsedRect();
    _checkCollapsed();
  }

  void _checkCollapsed() {
    if (!_closing || _finished) return;
    if (_progress.value > M3SearchBar.collapsedThreshold) return;
    _finished = true;
    _progress.stop();
    if (_owner.mounted) _owner._hideCollapsed.value = false;
    if (mounted) setState(() {});
    if (_route.animation!.status != AnimationStatus.reverse) {
      _route.popWithoutTransition();
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    // Маршрут закрыли снаружи (Navigator.pop из контента) — сворачиваемся.
    if (status == AnimationStatus.reverse) close();
  }

  void setQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  Future<void> announce(String message) {
    return SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  // Predictive back (Compose `PredictiveBackStateHandler`).

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || _closing || !_route.isCurrent) return false;
    _back.start(backEvent);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_closing) _back.update(backEvent);
  }

  @override
  void handleCommitBackGesture() {
    // `BackEventProgress.Completed`: геометрия жеста сохраняется на время
    // сворачивания.
    close();
  }

  @override
  void handleCancelBackGesture() => _back.cancel();

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();

    final MediaQueryData media = MediaQuery.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EdgeInsets padding = media.padding;
    final double bottomInset = math.max(
      media.viewPadding.bottom,
      media.viewInsets.bottom,
    );

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: CustomMultiChildLayout(
          delegate: _SearchLayoutDelegate(
            progress: _progress,
            back: _back,
            collapsedRect: () => _route.lastCollapsedRect,
            topInset: padding.top,
          ),
          children: [
            LayoutId(
              id: _SearchSlot.surface,
              child: AnimatedBuilder(
                animation: Listenable.merge([_progress, _back]),
                builder: (context, _) {
                  final double progress = _progress.value.clamp(0.0, 1.0);
                  final double radius =
                      M3SearchBar.cornerRadius *
                      math.max(1 - progress, _back.progress);
                  // `fullScreenContainedSearchBarColor` = surfaceContainerLow,
                  // прозрачность = `state.progress`.
                  return Opacity(
                    opacity: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  );
                },
              ),
            ),
            LayoutId(
              id: _SearchSlot.content,
              child: FadeTransition(
                opacity: _content,
                child: Padding(
                  // `nonTopInsets`: горизонтальные и нижний (с клавиатурой).
                  padding: EdgeInsets.only(
                    left: padding.left,
                    right: padding.right,
                    bottom: bottomInset,
                  ),
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      removeLeft: true,
                      removeRight: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: ValueListenableBuilder<String>(
                          valueListenable: _query,
                          builder: (context, query, _) => M3SearchScope._(
                            query: query,
                            state: this,
                            child: Builder(
                              builder: (context) =>
                                  _owner.widget.contentBuilder(context, query),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: _SearchSlot.field,
              child: _SearchFieldContainer(
                child: _ExpandedField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: _owner.widget.hintText,
                  onBack: close,
                  onSubmitted: (value) => _owner.widget.onSearch?.call(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Поле в открытом поиске: ведущая иконка — кнопка «Назад»
/// (`SampleLeadingIcon`), замыкающая — «Очистить», пока запрос не пуст.
class _ExpandedField extends StatelessWidget {
  const _ExpandedField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onBack,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style = Theme.of(context).textTheme.bodyLarge!;

    return Row(
      children: [
        const SizedBox(width: M3SearchBar.iconOffset),
        _IconSlot(
          child: IconButton(
            tooltip: 'Назад',
            color: scheme.onSurface,
            icon: const Icon(Symbols.arrow_back),
            onPressed: onBack,
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            // `LaunchedEffect(Unit) { focusRequester.requestFocus() }`.
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            maxLines: 1,
            style: style.copyWith(color: scheme.onSurface),
            cursorColor: scheme.primary,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: style.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox(width: M3SearchBar.textEndPadding)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ClearButton(
                      onPressed: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    ),
                    const SizedBox(width: M3SearchBar.iconOffset),
                  ],
                ),
        ),
      ],
    );
  }
}

enum _SearchSlot { surface, field, content }

/// Порт measure/place из `FullScreenSearchBarLayout` при `isContained = true`.
class _SearchLayoutDelegate extends MultiChildLayoutDelegate {
  _SearchLayoutDelegate({
    required this.progress,
    required this.back,
    required this.collapsedRect,
    required this.topInset,
  }) : super(relayout: Listenable.merge([progress, back]));

  final AnimationController progress;
  final _BackGesture back;
  final Rect Function() collapsedRect;
  final double topInset;

  static double _lerp(double a, double b, double t) => lerpDouble(a, b, t)!;

  @override
  void performLayout(Size size) {
    final double maxWidth = size.width;
    final double maxHeight = size.height;
    final double value = progress.value;
    final double clamped = value.clamp(0.0, 1.0);
    final double backProgress = back.progress;
    final Rect collapsed = collapsedRect();

    // Размер подложки: весь экран, при predictive back — до 90%.
    final double backEndWidth = math.max(
      maxWidth * M3SearchBar.predictiveBackMinScale,
      collapsed.width,
    );
    final double backEndHeight = math.max(
      maxHeight * M3SearchBar.predictiveBackMinScale,
      collapsed.height,
    );
    final double width = _lerp(maxWidth, backEndWidth, backProgress);
    final double height = _lerp(maxHeight, backEndHeight, backProgress);
    layoutChild(_SearchSlot.surface, BoxConstraints.tight(Size(width, height)));

    // Ширина поля — по неограниченному прогрессу (`state.animatable.value`).
    final double fieldWidth = math.max(
      0,
      _lerp(
        collapsed.width,
        width - 2 * M3SearchBar.expandedHorizontalMargin,
        value,
      ),
    );
    layoutChild(
      _SearchSlot.field,
      BoxConstraints.tight(Size(fieldWidth, collapsed.height)),
    );

    final double topPadding = topInset + M3SearchBar.expandedTopPadding;
    final double animatedTopPadding = _lerp(
      0,
      topPadding,
      math.min(clamped, 1 - backProgress),
    );
    const double bottomPadding = M3SearchBar.contentGap;
    final double paddedFieldHeight =
        collapsed.height + animatedTopPadding + bottomPadding;
    layoutChild(
      _SearchSlot.content,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, height - paddedFieldHeight),
      ),
    );

    final PredictiveBackEvent? last = back.last;
    final PredictiveBackEvent? first = back.first;

    double endOffsetX(PredictiveBackEvent event) {
      double x = event.swipeEdge == SwipeEdge.left
          ? maxWidth - M3SearchBar.predictiveBackMinMargin - backEndWidth
          : M3SearchBar.predictiveBackMinMargin;
      x = math.max(x, collapsed.right - backEndWidth);
      return math.min(x, collapsed.left);
    }

    double endOffsetY(PredictiveBackEvent event) {
      final Offset? start = first?.touchOffset;
      final Offset? touch = event.touchOffset;
      if (start == null || touch == null) return 0;
      final double deltaY = touch.dy - start.dy;
      final double relativeDeltaY = deltaY.abs() / maxHeight;
      final double available = math.max(
        0,
        (maxHeight - backEndHeight) / 2 - M3SearchBar.predictiveBackMinMargin,
      );
      final double total = math.min(
        available,
        M3SearchBar.predictiveBackMaxOffsetY,
      );
      final double interpolated = _lerp(0, total, relativeDeltaY);
      return math.min(interpolated * deltaY.sign + topPadding, collapsed.top);
    }

    final double offsetX = _lerp(
      0,
      last == null ? 0 : endOffsetX(last),
      backProgress,
    );
    final double centerX = _lerp(
      collapsed.center.dx,
      offsetX + width / 2,
      value,
    );
    final double offsetY = _lerp(
      0,
      last == null ? 0 : endOffsetY(last),
      backProgress,
    );
    final double animatedOffsetY = _lerp(collapsed.top, offsetY, clamped);

    positionChild(_SearchSlot.surface, Offset(offsetX, offsetY));
    positionChild(
      _SearchSlot.field,
      Offset(centerX - fieldWidth / 2, animatedOffsetY + animatedTopPadding),
    );
    positionChild(
      _SearchSlot.content,
      Offset(
        offsetX,
        animatedOffsetY + animatedTopPadding + collapsed.height + bottomPadding,
      ),
    );
  }

  @override
  bool shouldRelayout(_SearchLayoutDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      progress != oldDelegate.progress ||
      back != oldDelegate.back;
}
