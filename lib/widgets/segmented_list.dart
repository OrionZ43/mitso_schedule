import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_state_layer.dart';
import '../theme/app_typography.dart';

/// Segmented-список из M3 Expressive: каждый пункт в своём контейнере.
///
/// Compose `samples/ListSamples.kt` → `SegmentedListItems`: столбец
/// `SegmentedListItem` с `Arrangement.spacedBy(ListItemDefaults.SegmentedGap)`
/// и `shapes = ListItemDefaults.segmentedShapes(index, count)`.
///
/// Позицию каждого ребёнка (`index` / `count`) список отдаёт через
/// [SegmentedListPosition], поэтому [M3ListItem] сам выбирает форму
/// (`segmentedShapes`). Прочие виджеты (`ListTile`, `SwitchListTile`)
/// по-прежнему работают: их список кладёт в статичный контейнер той же формы.
///
/// Цвет контейнера — `surfaceContainer`, как в примерах Compose
/// (`ListItemDefaults.colors(containerColor = colorScheme.surfaceContainer)`):
/// по токену `md.comp.list.list-item.segmented.container.color` = `surface`
/// пункты сливались бы с фоном вкладок.
class SegmentedList extends StatelessWidget {
  const SegmentedList({super.key, required this.children});

  /// Пункты списка. [M3ListItem] должен быть прямым ребёнком: обёртка вокруг
  /// него (например, `Semantics`) получит статичный контейнер, и морфинг
  /// формы спрячется под ним. Для своей метки есть [M3ListItem.semanticsLabel].
  final List<Widget> children;

  /// `ListTokens.SegmentedGap` = `md.comp.list.segmented.gap` (space25).
  static const double gap = 2;

  /// `ListTokens.ContainerShape` = `corner.large`: наружные углы крайних пунктов.
  static const double outerCorner = AppShapes.large;

  /// `ListTokens.ItemContainerExpressiveShape` = `corner.extra-small`: стыки.
  static const double innerCorner = AppShapes.extraSmall;

  /// Форма пункта по позиции — `ListItemDefaults.segmentedShapes`:
  /// одиночному все углы `ContainerShape`, первому — верхние, последнему —
  /// нижние, средним — базовая форма `ItemContainerExpressiveShape`.
  static BorderRadius shapeFor(int index, int count) {
    const Radius outer = Radius.circular(outerCorner);
    const Radius inner = Radius.circular(innerCorner);
    if (count == 1) return const BorderRadius.all(outer);
    return BorderRadius.vertical(
      top: index == 0 ? outer : inner,
      bottom: index == count - 1 ? outer : inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int count = children.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          SegmentedListPosition(
            index: i,
            count: count,
            child: children[i] is M3ListItem
                ? children[i]
                : _StaticSegment(child: children[i]),
          ),
        ],
      ],
    );
  }
}

/// Позиция пункта в segmented-списке: аналог аргументов
/// `ListItemDefaults.segmentedShapes(index, count)`.
///
/// [SegmentedList] ставит её сам; в `ListView.builder` / `SliverList` её
/// можно обернуть вокруг [M3ListItem] вручную.
class SegmentedListPosition extends InheritedWidget {
  const SegmentedListPosition({
    super.key,
    required this.index,
    required this.count,
    required super.child,
  }) : assert(index >= 0 && index < count);

  final int index;
  final int count;

  static SegmentedListPosition? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SegmentedListPosition>();

  @override
  bool updateShouldNotify(SegmentedListPosition oldWidget) =>
      index != oldWidget.index || count != oldWidget.count;
}

/// Статичный контейнер для детей, которые не [M3ListItem].
///
/// `Material`, а не `Container`: `ListTile` рисует фон и ripple на ближайшем
/// Material-предке.
class _StaticSegment extends StatelessWidget {
  const _StaticSegment({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SegmentedListPosition position = SegmentedListPosition.maybeOf(
      context,
    )!;
    return Material(
      color: context.colors.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: SegmentedList.shapeFor(position.index, position.count),
      ),
      child: child,
    );
  }
}

/// Пункт списка M3 Expressive — порт Compose `SegmentedListItem` /
/// `InteractiveListItem` (`ListItem.kt`, `ListItemDefaults.kt`).
///
/// Слоты как в Compose: [leading], [overline], [headline] (`content`),
/// [supporting], [trailing]. Раскладка — `InteractiveListItemMeasurePolicy`:
/// поля 16 по бокам и 10 сверху и снизу (`ListItemDefaults.ContentPadding`),
/// 12 между слотами (`InteractiveListInternalSpacing`), минимальная высота
/// 56 / 72 / 88 по числу строк (`ListTokens.Item*LineContainerHeight`),
/// выравнивание по центру, у высоких пунктов — по верху
/// (`ListItemDefaults.verticalAlignment()`).
///
/// Внутри [SegmentedList] (или под [SegmentedListPosition]) форма — позиционная
/// (`segmentedShapes`), без позиции — базовая 4dp (`ListItemDefaults.shapes()`).
/// Нажатие и фокус скругляют все углы до 16dp, наведение — до 12dp, выбранный
/// пункт держит 16dp (`ListItemShapes.shapeForInteraction`); морфинг — пружина
/// `FastSpatial` (`AnimatedShapeState`). Цвета контейнера и слотов — пружина
/// `DefaultEffects` (`updateTransition` + `animateColor`).
class M3ListItem extends StatefulWidget {
  const M3ListItem({
    super.key,
    required this.headline,
    this.leading,
    this.overline,
    this.supporting,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.containerColor,
    this.semanticsLabel,
  });

  /// Основной текст (`content`): `ItemLabelTextFont` = `bodyLarge`,
  /// `ItemLabelTextColor` = `onSurface`.
  final Widget headline;

  /// Иконка, аватар или контрол выбора в начале: цвет `ItemLeadingIconColor`
  /// = `onSurfaceVariant`, текст `ItemLeadingAvatarLabelFont` = `titleMedium`.
  final Widget? leading;

  /// Строка над основным текстом: `ItemOverlineFont` = `labelSmall`,
  /// `onSurfaceVariant`.
  final Widget? overline;

  /// Строка под основным текстом: `ItemSupportingTextFont` = `bodyMedium`,
  /// `onSurfaceVariant`.
  final Widget? supporting;

  /// Иконка, переключатель или текст в конце: цвет `ItemTrailingIconColor`
  /// = `onSurfaceVariant`, текст `ItemTrailingSupportingTextFont` = `labelSmall`.
  final Widget? trailing;

  /// Нажатие на весь пункт. Без [onTap] и [onLongPress] пункт
  /// неинтерактивный: без ripple и морфинга по нажатию.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Выбранный пункт: `secondaryContainer` / `onSecondaryContainer`
  /// (`ListTokens.ItemSelected*`), форма 16dp.
  ///
  /// Выбор нельзя показывать только цветом (Lists → Accessibility): добавьте
  /// второй признак — radio, checkbox или иконку.
  final bool selected;

  /// Отключённый пункт: текст и иконки `onSurface` 38%
  /// (`ListTokens.ItemDisabled*Opacity`), без взаимодействия.
  final bool enabled;

  /// Цвет контейнера. По умолчанию `surfaceContainer`, как в примерах
  /// Compose; для результатов поиска — `Colors.transparent`
  /// (`SearchBarSamples.kt` → `SampleSearchResults`).
  final Color? containerColor;

  /// Своя метка для TalkBack вместо текста слотов (Compose объединяет
  /// семантику пункта через `semantics(mergeDescendants = true)`).
  final String? semanticsLabel;

  /// `ListTokens.ItemLeadingSpace` / `ItemTrailingSpace` (space200).
  static const double horizontalPadding = 16;

  /// `ListTokens.ItemTopSpace` / `ItemBottomSpace` (space125).
  static const double verticalPadding = 10;

  /// `ListTokens.ItemBetweenSpace` (space150) — `InteractiveListInternalSpacing`.
  static const double betweenSpace = 12;

  /// `ListTokens.ItemOneLineContainerHeight` / `TwoLine` / `ThreeLine`.
  static const double oneLineHeight = 56;
  static const double twoLineHeight = 72;
  static const double threeLineHeight = 88;

  /// `InteractiveListVerticalAlignmentBreakpoint`: середина между 72 и 88dp
  /// за вычетом вертикальных полей. Пункт выше — выравнивание по верху.
  static const double verticalAlignmentBreakpoint =
      (threeLineHeight + twoLineHeight) / 2 - 2 * verticalPadding;

  /// `ListTokens.ItemContainerExpressiveShape` = `corner.extra-small`.
  static const double shapeCorner = AppShapes.extraSmall;

  /// `ItemPressedContainerExpressiveShape`, `ItemSelectedContainerExpressiveShape`,
  /// `ItemFocusedContainerExpressiveShape` = `corner.large`.
  static const double pressedCorner = AppShapes.large;

  /// `ItemHoveredContainerExpressiveShape` = `corner.medium`.
  static const double hoveredCorner = AppShapes.medium;

  /// `ListTokens.ItemDisabledLabelTextOpacity` и остальные `ItemDisabled*Opacity`.
  static const double disabledContentOpacity = 0.38;

  @override
  State<M3ListItem> createState() => _M3ListItemState();
}

/// Цвета пункта в одном состоянии — срез `ListItemColors`.
@immutable
class _ItemColors {
  const _ItemColors({
    required this.container,
    required this.content,
    required this.leading,
    required this.trailing,
    required this.overline,
    required this.supporting,
  });

  final Color container;
  final Color content;
  final Color leading;
  final Color trailing;
  final Color overline;
  final Color supporting;

  static _ItemColors lerp(_ItemColors a, _ItemColors b, double t) =>
      _ItemColors(
        container: Color.lerp(a.container, b.container, t)!,
        content: Color.lerp(a.content, b.content, t)!,
        leading: Color.lerp(a.leading, b.leading, t)!,
        trailing: Color.lerp(a.trailing, b.trailing, t)!,
        overline: Color.lerp(a.overline, b.overline, t)!,
        supporting: Color.lerp(a.supporting, b.supporting, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is _ItemColors &&
      other.container == container &&
      other.content == content &&
      other.leading == leading &&
      other.trailing == trailing &&
      other.overline == overline &&
      other.supporting == supporting;

  @override
  int get hashCode =>
      Object.hash(container, content, leading, trailing, overline, supporting);
}

class _M3ListItemState extends State<M3ListItem> with TickerProviderStateMixin {
  final WidgetStatesController _states = WidgetStatesController();

  /// Прогресс морфинга от [_shapeStart] к [_shapeTarget] — `AnimatedShapeState.progress`.
  late final AnimationController _shapeProgress = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  BorderRadius? _shapeStart;
  BorderRadius? _shapeTarget;

  /// Прогресс смены цветов от [_colorsStart] к [_colorsTarget].
  late final AnimationController _colorProgress = AnimationController(
    vsync: this,
    value: 1,
  );
  _ItemColors? _colorsStart;
  _ItemColors? _colorsTarget;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  // Зависимости из дерева кешируются в didChangeDependencies: слушатель
  // состояний срабатывает и при деактивации InkWell, когда искать предков
  // уже нельзя.
  ColorScheme? _scheme;
  bool _reduceMotion = false;
  BorderRadius _base = const BorderRadius.all(
    Radius.circular(M3ListItem.shapeCorner),
  );

  @override
  void initState() {
    super.initState();
    _states.addListener(_updateTargets);
    _shapeProgress.addStatusListener(_snapShapeOnComplete);
    _colorProgress.addStatusListener(_snapColorsOnComplete);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = Theme.of(context).colorScheme;
    _reduceMotion = reduceMotionOf(context);
    final SegmentedListPosition? position = SegmentedListPosition.maybeOf(
      context,
    );
    final BorderRadius base = position == null
        ? const BorderRadius.all(Radius.circular(M3ListItem.shapeCorner))
        : SegmentedList.shapeFor(position.index, position.count);
    if (base != _base) {
      _base = base;
      // Compose пересоздаёт анимированную форму при смене `ListItemShapes`
      // (`key(this) { rememberAnimatedShape(...) }`): новая позиция — без морфинга.
      _shapeTarget = null;
    }
    _updateTargets();
  }

  @override
  void didUpdateWidget(M3ListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive || !widget.enabled) {
      // InkWell исчезает вместе с обработчиками и не успевает снять состояния.
      _states.value = <WidgetState>{};
    }
    _updateTargets();
  }

  @override
  void dispose() {
    _states.removeListener(_updateTargets);
    _states.dispose();
    _shapeProgress.dispose();
    _colorProgress.dispose();
    super.dispose();
  }

  // Симуляция пружины завершается в пределах допуска, а не ровно в 1.
  void _snapShapeOnComplete(AnimationStatus status) {
    if (status.isCompleted && _shapeProgress.value != 1) {
      _shapeProgress.value = 1;
    }
  }

  void _snapColorsOnComplete(AnimationStatus status) {
    if (status.isCompleted && _colorProgress.value != 1) {
      _colorProgress.value = 1;
    }
  }

  /// `ListItemShapes.shapeForInteraction`: порядок проверки состояний.
  BorderRadius _resolveShape() {
    final Set<WidgetState> states = _states.value;
    const BorderRadius large = BorderRadius.all(
      Radius.circular(M3ListItem.pressedCorner),
    );
    if (states.contains(WidgetState.pressed)) return large;
    if (widget.selected) return large;
    if (states.contains(WidgetState.focused)) return large;
    if (states.contains(WidgetState.hovered)) {
      return const BorderRadius.all(Radius.circular(M3ListItem.hoveredCorner));
    }
    return _base;
  }

  /// `ListItemColors.containerColor(enabled, selected, dragged)` и соседние
  /// функции: сначала disabled, потом selected, потом обычные цвета.
  _ItemColors _resolveColors(ColorScheme scheme) {
    final Color container = widget.containerColor ?? scheme.surfaceContainer;
    if (!widget.enabled) {
      final Color disabled = scheme.onSurface.withValues(
        alpha: M3ListItem.disabledContentOpacity,
      );
      return _ItemColors(
        container: container,
        content: disabled,
        leading: disabled,
        trailing: disabled,
        overline: disabled,
        supporting: disabled,
      );
    }
    if (widget.selected) {
      final Color on = scheme.onSecondaryContainer;
      return _ItemColors(
        container: scheme.secondaryContainer,
        content: on,
        leading: on,
        trailing: on,
        overline: on,
        supporting: on,
      );
    }
    return _ItemColors(
      container: container,
      content: scheme.onSurface,
      leading: scheme.onSurfaceVariant,
      trailing: scheme.onSurfaceVariant,
      overline: scheme.onSurfaceVariant,
      supporting: scheme.onSurfaceVariant,
    );
  }

  void _updateTargets() {
    final ColorScheme? scheme = _scheme;
    if (scheme == null) return;
    _morphShapeTo(_resolveShape());
    _animateColorsTo(_resolveColors(scheme));
  }

  /// Порт `AnimatedShapeState.animateToShape`.
  void _morphShapeTo(BorderRadius target) {
    if (_shapeTarget == null || _reduceMotion) {
      if (_shapeTarget == target && _shapeProgress.value == 1) return;
      _shapeStart = _shapeTarget = target;
      _shapeProgress.value = 1;
      return;
    }
    if (_shapeTarget == target) return;

    if (target == _shapeStart) {
      // Действие отменили до конца анимации: разворачиваем прогресс и
      // скорость, чтобы сохранить инерцию.
      final double progress = _shapeProgress.value;
      final double velocity = _shapeProgress.velocity;
      _shapeStart = _shapeTarget;
      _shapeTarget = target;
      _shapeProgress.value = 1 - progress;
      _shapeProgress.animateWith(
        AppMotion.fastSpatial.simulate(
          from: 1 - progress,
          to: 1,
          velocity: -velocity,
        ),
      );
    } else {
      // Новая цель: замораживаем видимую форму и морфим от неё.
      final double progress = _shapeProgress.value;
      _shapeStart = switch (progress) {
        1 => _shapeTarget,
        0 => _shapeStart,
        _ => BorderRadius.lerp(_shapeStart, _shapeTarget, progress),
      };
      _shapeTarget = target;
      _shapeProgress.value = 0;
      _shapeProgress.animateWith(AppMotion.fastSpatial.simulate());
    }
  }

  /// Цвета — `updateTransition` + `animateColor(DefaultEffects)`.
  void _animateColorsTo(_ItemColors target) {
    if (_colorsTarget == target) return;
    if (_colorsTarget == null || _reduceMotion) {
      _colorsStart = _colorsTarget = target;
      _colorProgress.value = 1;
      return;
    }
    _colorsStart = _currentColors;
    _colorsTarget = target;
    _colorProgress.value = 0;
    _colorProgress.animateWith(AppMotion.defaultEffects.simulate());
  }

  BorderRadius get _currentRadius {
    final BorderRadius radius = BorderRadius.lerp(
      _shapeStart,
      _shapeTarget,
      _shapeProgress.value,
    )!;
    // Перелёт FastSpatial не должен уводить радиус в минус.
    Radius clamp(Radius r) =>
        Radius.elliptical(math.max(0, r.x), math.max(0, r.y));
    return BorderRadius.only(
      topLeft: clamp(radius.topLeft),
      topRight: clamp(radius.topRight),
      bottomLeft: clamp(radius.bottomLeft),
      bottomRight: clamp(radius.bottomRight),
    );
  }

  _ItemColors get _currentColors =>
      _ItemColors.lerp(_colorsStart!, _colorsTarget!, _colorProgress.value);

  Widget? _slot(
    Widget? child,
    Color color,
    TextStyle style, {
    EdgeInsetsDirectional padding = EdgeInsetsDirectional.zero,
  }) {
    if (child == null) return null;
    return Padding(
      padding: padding,
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: DefaultTextStyle(
          style: style.copyWith(color: color),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool interactive = _interactive;

    // Цвета меняются редко (выбор, отключение) — тогда перестраивается
    // содержимое. Морфинг формы при нажатии меняет только контейнер:
    // содержимое и InkWell передаются в него готовыми.
    final Widget item = AnimatedBuilder(
      animation: _colorProgress,
      builder: (context, _) {
        final _ItemColors colors = _currentColors;

        Widget content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: M3ListItem.horizontalPadding,
            vertical: M3ListItem.verticalPadding,
          ),
          child: _ListItemLayout(
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            leading: _slot(
              widget.leading,
              colors.leading,
              text.titleMedium!,
              padding: const EdgeInsetsDirectional.only(
                end: M3ListItem.betweenSpace,
              ),
            ),
            overline: _slot(widget.overline, colors.overline, text.labelSmall!),
            headline: _slot(widget.headline, colors.content, text.bodyLarge!)!,
            supporting: _slot(
              widget.supporting,
              colors.supporting,
              text.bodyMedium!,
            ),
            trailing: _slot(
              widget.trailing,
              colors.trailing,
              text.labelSmall!,
              padding: const EdgeInsetsDirectional.only(
                start: M3ListItem.betweenSpace,
              ),
            ),
          ),
        );

        if (interactive) {
          // Ripple обрезается формой контейнера (clipBehavior у Material).
          content = InkWell(
            statesController: _states,
            onTap: widget.enabled ? widget.onTap : null,
            onLongPress: widget.enabled ? widget.onLongPress : null,
            // Ripple цветом содержимого: `ripple()` берёт LocalContentColor.
            overlayColor: AppStateLayer.overlay(colors.content),
            child: content,
          );
        }

        return AnimatedBuilder(
          animation: _shapeProgress,
          builder: (context, content) => Material(
            color: colors.container,
            shape: RoundedRectangleBorder(borderRadius: _currentRadius),
            clipBehavior: Clip.antiAlias,
            // Форма уже анимирована пружиной — без неявного твина Material.
            animationDuration: Duration.zero,
            child: content,
          ),
          child: content,
        );
      },
    );

    final String? label = widget.semanticsLabel;
    return MergeSemantics(
      child: Semantics(
        button: interactive ? true : null,
        enabled: interactive ? widget.enabled : null,
        selected: widget.selected ? true : null,
        label: label,
        onTap: label != null && interactive && widget.enabled
            ? widget.onTap
            : null,
        onLongPress: label != null && interactive && widget.enabled
            ? widget.onLongPress
            : null,
        excludeSemantics: label != null,
        child: item,
      ),
    );
  }
}

enum _ListItemSlot { leading, overline, headline, supporting, trailing }

/// Раскладка слотов — `InteractiveListItemMeasurePolicy` из `ListItem.kt`.
class _ListItemLayout
    extends SlottedMultiChildRenderObjectWidget<_ListItemSlot, RenderBox> {
  const _ListItemLayout({
    required this.textDirection,
    required this.textScaler,
    required this.headline,
    this.leading,
    this.overline,
    this.supporting,
    this.trailing,
  });

  final TextDirection textDirection;
  final TextScaler textScaler;
  final Widget? leading;
  final Widget? overline;
  final Widget headline;
  final Widget? supporting;
  final Widget? trailing;

  @override
  Iterable<_ListItemSlot> get slots => _ListItemSlot.values;

  @override
  Widget? childForSlot(_ListItemSlot slot) => switch (slot) {
    _ListItemSlot.leading => leading,
    _ListItemSlot.overline => overline,
    _ListItemSlot.headline => headline,
    _ListItemSlot.supporting => supporting,
    _ListItemSlot.trailing => trailing,
  };

  @override
  _RenderListItem createRenderObject(BuildContext context) =>
      _RenderListItem(textDirection: textDirection, textScaler: textScaler);

  @override
  void updateRenderObject(BuildContext context, _RenderListItem renderObject) {
    renderObject
      ..textDirection = textDirection
      ..textScaler = textScaler;
  }
}

class _RenderListItem extends RenderBox
    with SlottedContainerRenderObjectMixin<_ListItemSlot, RenderBox> {
  _RenderListItem({required this._textDirection, required this._textScaler});

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_ListItemSlot.leading);
  RenderBox? get _overline => childForSlot(_ListItemSlot.overline);
  RenderBox? get _headline => childForSlot(_ListItemSlot.headline);
  RenderBox? get _supporting => childForSlot(_ListItemSlot.supporting);
  RenderBox? get _trailing => childForSlot(_ListItemSlot.trailing);

  @override
  Iterable<RenderBox> get children => <RenderBox>[
    ?_leading,
    ?_overline,
    ?_headline,
    ?_supporting,
    ?_trailing,
  ];

  /// `ListItemType`: три строки при overline + supporting или многострочном
  /// supporting, две — при одном из них.
  static double _minHeightFor({
    required bool hasOverline,
    required bool hasSupporting,
    required bool supportingMultiline,
  }) {
    if ((hasOverline && hasSupporting) || supportingMultiline) {
      return M3ListItem.threeLineHeight;
    }
    if (hasOverline || hasSupporting) return M3ListItem.twoLineHeight;
    return M3ListItem.oneLineHeight;
  }

  /// Многострочный supporting. Compose сравнивает первую и последнюю базовую
  /// линию; у `RenderBox` есть только первая, поэтому — эвристика Compose из
  /// intrinsic-замера `isSupportingMultilineHeuristic`: выше 30sp.
  bool _isMultiline(double supportingHeight) =>
      supportingHeight > textScaler.scale(30);

  _ItemLayout _computeLayout(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final double maxWidth = constraints.maxWidth;
    BoxConstraints loose(double usedWidth) => BoxConstraints(
      maxWidth: math.max(0, maxWidth - usedWidth),
      maxHeight: constraints.maxHeight,
    );

    final Size leading = _leading == null
        ? Size.zero
        : layoutChild(_leading!, loose(0));
    final Size trailing = _trailing == null
        ? Size.zero
        : layoutChild(_trailing!, loose(leading.width));
    final double used = leading.width + trailing.width;
    final Size overline = _overline == null
        ? Size.zero
        : layoutChild(_overline!, loose(used));
    final Size headline = _headline == null
        ? Size.zero
        : layoutChild(_headline!, loose(used));
    final Size supporting = _supporting == null
        ? Size.zero
        : layoutChild(_supporting!, loose(used));

    final double width = constraints.hasBoundedWidth
        ? maxWidth
        : leading.width +
              math.max(
                headline.width,
                math.max(overline.width, supporting.width),
              ) +
              trailing.width;

    final double mainHeight =
        overline.height + headline.height + supporting.height;
    final double calculated = math.max(
      leading.height,
      math.max(mainHeight, trailing.height),
    );
    final double typeHeight = _minHeightFor(
      hasOverline: _overline != null,
      hasSupporting: _supporting != null,
      supportingMultiline:
          _supporting != null && _isMultiline(supporting.height),
    );
    final double minHeight = constraints.minHeight == 0
        ? (typeHeight - 2 * M3ListItem.verticalPadding).clamp(
            0,
            constraints.maxHeight,
          )
        : constraints.minHeight;
    final double height = constraints
        .copyWith(minHeight: minHeight)
        .constrainHeight(calculated);

    // `ListItemDefaults.verticalAlignment()`.
    final bool top = height >= M3ListItem.verticalAlignmentBreakpoint;
    double align(double childHeight) =>
        top ? 0 : ((height - childHeight) / 2).roundToDouble();

    double x(double left, double childWidth) =>
        textDirection == TextDirection.ltr ? left : width - left - childWidth;

    final double mainY = align(mainHeight);
    return _ItemLayout(
      size: Size(width, height),
      leading: Offset(x(0, leading.width), align(leading.height)),
      overline: Offset(x(leading.width, overline.width), mainY),
      headline: Offset(
        x(leading.width, headline.width),
        mainY + overline.height,
      ),
      supporting: Offset(
        x(leading.width, supporting.width),
        mainY + overline.height + headline.height,
      ),
      trailing: Offset(
        x(width - trailing.width, trailing.width),
        align(trailing.height),
      ),
    );
  }

  @override
  void performLayout() {
    final _ItemLayout layout = _computeLayout(
      constraints,
      ChildLayoutHelper.layoutChild,
    );
    size = constraints.constrain(layout.size);
    void place(RenderBox? child, Offset offset) {
      if (child != null) (child.parentData! as BoxParentData).offset = offset;
    }

    place(_leading, layout.leading);
    place(_overline, layout.overline);
    place(_headline, layout.headline);
    place(_supporting, layout.supporting);
    place(_trailing, layout.trailing);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(
        _computeLayout(constraints, ChildLayoutHelper.dryLayoutChild).size,
      );

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final RenderBox? headline = _headline;
    if (headline == null) return null;
    final _ItemLayout layout = _computeLayout(
      constraints,
      ChildLayoutHelper.dryLayoutChild,
    );
    final double? childBaseline = headline.getDryBaseline(
      BoxConstraints(maxWidth: constraints.maxWidth),
      baseline,
    );
    return childBaseline == null ? null : childBaseline + layout.headline.dy;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final RenderBox? headline = _headline;
    if (headline == null) return null;
    final double? childBaseline = headline.getDistanceToActualBaseline(
      baseline,
    );
    if (childBaseline == null) return null;
    return childBaseline + (headline.parentData! as BoxParentData).offset.dy;
  }

  double _intrinsicWidth(double height, bool max) {
    double measure(RenderBox? child) => child == null
        ? 0
        : (max
              ? child.getMaxIntrinsicWidth(height)
              : child.getMinIntrinsicWidth(height));
    return measure(_leading) +
        math.max(
          measure(_headline),
          math.max(measure(_overline), measure(_supporting)),
        ) +
        measure(_trailing);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(height, false);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(height, true);

  double _intrinsicHeight(double width, bool max) {
    double remaining = width;
    double measure(RenderBox? child) => child == null
        ? 0
        : (max
              ? child.getMaxIntrinsicHeight(remaining)
              : child.getMinIntrinsicHeight(remaining));
    final double leading = measure(_leading);
    if (_leading != null) {
      remaining = math.max(
        0,
        remaining - _leading!.getMaxIntrinsicWidth(double.infinity),
      );
    }
    final double trailing = measure(_trailing);
    if (_trailing != null) {
      remaining = math.max(
        0,
        remaining - _trailing!.getMaxIntrinsicWidth(double.infinity),
      );
    }
    final double overline = measure(_overline);
    final double supporting = measure(_supporting);
    final double headline = measure(_headline);
    final double typeHeight = _minHeightFor(
      hasOverline: overline > 0,
      hasSupporting: supporting > 0,
      supportingMultiline: _isMultiline(supporting),
    );
    return math.max(
      typeHeight - 2 * M3ListItem.verticalPadding,
      math.max(leading, math.max(overline + headline + supporting, trailing)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, false);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, true);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final RenderBox child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in children.toList().reversed) {
      final Offset offset = (child.parentData! as BoxParentData).offset;
      final bool hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}

@immutable
class _ItemLayout {
  const _ItemLayout({
    required this.size,
    required this.leading,
    required this.overline,
    required this.headline,
    required this.supporting,
    required this.trailing,
  });

  final Size size;
  final Offset leading;
  final Offset overline;
  final Offset headline;
  final Offset supporting;
  final Offset trailing;
}
