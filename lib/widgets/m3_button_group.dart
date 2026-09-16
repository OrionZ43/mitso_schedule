import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_motion.dart';
import 'm3_buttons.dart';

/// Значения по умолчанию standard button group — `ButtonGroupDefaults` и
/// токены `md.comp.button-group.standard.*`.
abstract final class M3ButtonGroupDefaults {
  /// `ButtonGroupDefaults.ExpandedRatio` = `pressed.item.width.multiplier` 15%.
  static const double expandedRatio = 0.15;

  /// Предел сжатия соседа по умолчанию: `EnlargeOnPressNode` берёт
  /// `ButtonDefaults.ContentPadding.calculateEndPadding` =
  /// `BaselineButtonTokens.TrailingSpace` = 24dp.
  static const double compressionLimit = 24;

  /// Прогресс, которого нажатие достигает до возврата
  /// (`waitUntil { pressedAnimatable.value > 0.75f }`).
  static const double releaseThreshold = 0.75;

  /// `MAX_WAIT_TIME_MILLIS`.
  static const Duration maxReleaseWait = Duration(milliseconds: 1000);

  /// `md.comp.button-group.standard.<size>.between-space`: XS 18, S 12
  /// (`ButtonGroupSmallTokens.BetweenSpace`), M/L/XL 8dp.
  static double spacingFor(M3ButtonSize size) => switch (size) {
    M3ButtonSize.extraSmall => 18,
    M3ButtonSize.small => 12,
    M3ButtonSize.medium || M3ButtonSize.large || M3ButtonSize.extraLarge => 8,
  };

  /// `md.comp.button-group.connected.<size>.between-space` = `space25` = 2dp.
  static const double connectedSpacing = 2;
}

/// Standard button group M3 Expressive — порт `ButtonGroup` (`ButtonGroup.kt`).
///
/// Раскладывает детей в строку с постоянным промежутком [spacing]. Ребёнок,
/// обёрнутый в [M3ButtonGroupItem], при нажатии расширяется на
/// [expandedRatio] своей ширины за счёт соседей (`ButtonGroupMeasurePolicy`),
/// общая ширина группы не меняется. Ширина ребёнка — по `weight`, иначе по
/// `maxIntrinsicWidth`.
///
/// Не портировано: overflow-меню (`overflowIndicator`) — MDC запрещает его
/// для toggle-групп, а в приложении групп с действиями нет. Если дети не
/// помещаются, группа занимает доступную ширину, а дети выходят за край.
class M3ButtonGroup extends MultiChildRenderObjectWidget {
  const M3ButtonGroup({
    super.key,
    this.expandedRatio = M3ButtonGroupDefaults.expandedRatio,
    this.spacing = 12,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.children,
  }) : assert(expandedRatio >= 0),
       assert(
         crossAxisAlignment == CrossAxisAlignment.start ||
             crossAxisAlignment == CrossAxisAlignment.center ||
             crossAxisAlignment == CrossAxisAlignment.end,
       );

  final double expandedRatio;

  /// Промежуток между детьми — [M3ButtonGroupDefaults.spacingFor].
  final double spacing;

  /// `verticalAlignment`; в Compose по умолчанию `Alignment.Top`.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  RenderM3ButtonGroup createRenderObject(BuildContext context) =>
      RenderM3ButtonGroup(
        expandedRatio: expandedRatio,
        spacing: spacing,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderM3ButtonGroup renderObject,
  ) {
    renderObject
      ..expandedRatio = expandedRatio
      ..spacing = spacing
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = Directionality.of(context);
  }

  /// Расширение нажатых детей — цикл из `ButtonGroupMeasurePolicy.measure`.
  ///
  /// Для каждого ребёнка с прогрессом `p ≠ 0` по порядку (ширины уже
  /// изменены предыдущими):
  ///  * первый: рост `p · min(ratio · w₀, limit₁)`, сжимается правый сосед;
  ///  * последний: зеркально, за счёт левого;
  ///  * средний: `g = p · min(ratio · wᵢ / 2, limitᵢ₋₁, limitᵢ₊₁)`, каждый
  ///    сосед теряет `min(g, w)`, сам получает сумму.
  ///
  /// Compose округляет прирост до целых пикселей (`roundToInt`) — это
  /// артефакт целочисленной раскладки; во Flutter раскладка в логических
  /// пикселях с дробной частью, поэтому округления нет.
  static List<double> expandPressed({
    required List<double> widths,
    required List<double> progress,
    required List<double> compressionLimits,
    double expandedRatio = M3ButtonGroupDefaults.expandedRatio,
  }) {
    assert(widths.length == progress.length);
    assert(widths.length == compressionLimits.length);
    final List<double> w = [...widths];
    final int lastItem = w.length;
    if (lastItem <= 1) return w;
    for (int index = 0; index < lastItem; index++) {
      final double p = progress[index];
      if (p == 0) continue;
      final double actualGrowth;
      if (index >= 1 && index < lastItem - 1) {
        final double targetGrowth =
            p *
            math.min(
              expandedRatio * w[index] / 2,
              math.min(
                compressionLimits[index - 1],
                compressionLimits[index + 1],
              ),
            );
        final double growthLeft = math.min(targetGrowth, w[index - 1]);
        final double growthRight = math.min(targetGrowth, w[index + 1]);
        w[index - 1] -= growthLeft;
        w[index + 1] -= growthRight;
        actualGrowth = growthLeft + growthRight;
      } else if (index == 0) {
        final double targetGrowth =
            p *
            math.min(expandedRatio * w[index], compressionLimits[index + 1]);
        final double growthRight = math.min(targetGrowth, w[index + 1]);
        w[index + 1] -= growthRight;
        actualGrowth = growthRight;
      } else {
        final double targetGrowth =
            p *
            math.min(expandedRatio * w[index], compressionLimits[index - 1]);
        final double growthLeft = math.min(targetGrowth, w[index - 1]);
        w[index - 1] -= growthLeft;
        actualGrowth = growthLeft;
      }
      w[index] += actualGrowth;
    }
    return w;
  }
}

/// Данные ребёнка группы — порт `ButtonGroupParentData`.
class M3ButtonGroupParentData extends ContainerBoxParentData<RenderBox> {
  /// `weight`; `null` — ширина по содержимому.
  double? weight;

  /// `pressedAnimatable`; `null` — ребёнок не реагирует на нажатие.
  Animation<double>? pressProgress;

  /// `compressionLimit`; без [M3ButtonGroupItem] — 0, как в Compose.
  double compressionLimit = 0;
}

/// Раскладка [M3ButtonGroup].
class RenderM3ButtonGroup extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, M3ButtonGroupParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, M3ButtonGroupParentData> {
  RenderM3ButtonGroup({
    required this._expandedRatio,
    required this._spacing,
    required this._crossAxisAlignment,
    required this._textDirection,
  });

  double get expandedRatio => _expandedRatio;
  double _expandedRatio;
  set expandedRatio(double value) {
    if (_expandedRatio == value) return;
    _expandedRatio = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment == value) return;
    _crossAxisAlignment = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Прогрессы нажатия, на которые подписана раскладка.
  final Set<Animation<double>> _listened = {};

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! M3ButtonGroupParentData) {
      child.parentData = M3ButtonGroupParentData();
    }
  }

  void _syncListeners() {
    final Set<Animation<double>> current = {
      for (
        RenderBox? child = firstChild;
        child != null;
        child = childAfter(child)
      )
        ?(child.parentData! as M3ButtonGroupParentData).pressProgress,
    };
    for (final Animation<double> old in _listened.difference(current)) {
      old.removeListener(markNeedsLayout);
    }
    for (final Animation<double> added in current.difference(_listened)) {
      added.addListener(markNeedsLayout);
    }
    _listened
      ..clear()
      ..addAll(current);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncListeners();
  }

  @override
  void detach() {
    for (final Animation<double> animation in _listened) {
      animation.removeListener(markNeedsLayout);
    }
    _listened.clear();
    super.detach();
  }

  List<RenderBox> get _children => [
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    )
      child,
  ];

  static M3ButtonGroupParentData _data(RenderBox child) =>
      child.parentData! as M3ButtonGroupParentData;

  /// Базовые ширины: сначала дети без веса по `maxIntrinsicWidth`, затем
  /// оставшееся место делится по весам — первая половина
  /// `ButtonGroupMeasurePolicy.measure`.
  (List<double> widths, double mainSpace) _baseWidths(
    List<RenderBox> children,
    BoxConstraints constraints,
  ) {
    final int size = children.length;
    final List<double> widths = List<double>.filled(size, 0);
    double totalWeight = 0;
    int weightChildrenCount = 0;
    double fixedSpace = 0;
    double spaceAfterLastNoWeight = 0;
    final double mainAxisMax = constraints.maxWidth;

    for (int i = 0; i < size; i++) {
      final double? weight = _data(children[i]).weight;
      if (weight != null && weight > 0) {
        totalWeight += weight;
        weightChildrenCount++;
      } else {
        final double remaining = mainAxisMax - fixedSpace;
        final double desiredWidth = children[i].getMaxIntrinsicWidth(
          constraints.maxHeight,
        );
        widths[i] = desiredWidth;
        spaceAfterLastNoWeight = math.min(
          spacing,
          math.max(remaining - desiredWidth, 0),
        );
        fixedSpace += desiredWidth + spaceAfterLastNoWeight;
      }
    }

    if (weightChildrenCount == 0) {
      fixedSpace -= spaceAfterLastNoWeight;
    } else {
      final double targetSpace = mainAxisMax.isFinite
          ? mainAxisMax
          : constraints.minWidth;
      final double spacingTotal = spacing * (weightChildrenCount - 1);
      final double remainingToTarget = math.max(
        targetSpace - fixedSpace - spacingTotal,
        0,
      );
      final double weightUnitSpace = remainingToTarget / totalWeight;
      for (int i = 0; i < size; i++) {
        final double? weight = _data(children[i]).weight;
        if (weight != null && weight > 0) {
          widths[i] = math.max(0, weightUnitSpace * weight);
        }
      }
    }

    // `desiredWidth = widths.sum() + arrangementSpacingInt * (size - 1)`.
    final double mainSpace =
        widths.fold<double>(0, (sum, w) => sum + w) +
        spacing * math.max(size - 1, 0);
    return (widths, mainSpace);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final List<RenderBox> children = _children;
    return children.fold<double>(
          0,
          (sum, child) => sum + child.getMinIntrinsicWidth(height),
        ) +
        spacing * math.max(children.length - 1, 0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final List<RenderBox> children = _children;
    return children.fold<double>(
          0,
          (sum, child) => sum + child.getMaxIntrinsicWidth(height),
        ) +
        spacing * math.max(children.length - 1, 0);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _children.fold<double>(
    0,
    (h, child) => math.max(h, child.getMinIntrinsicHeight(double.infinity)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _children.fold<double>(
    0,
    (h, child) => math.max(h, child.getMaxIntrinsicHeight(double.infinity)),
  );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final List<RenderBox> children = _children;
    if (children.isEmpty) return constraints.smallest;
    final (List<double> widths, double mainSpace) = _baseWidths(
      children,
      constraints,
    );
    double height = 0;
    for (int i = 0; i < children.length; i++) {
      height = math.max(
        height,
        children[i]
            .getDryLayout(
              constraints.copyWith(minWidth: widths[i], maxWidth: widths[i]),
            )
            .height,
      );
    }
    return constraints.constrain(
      Size(math.max(mainSpace, constraints.minWidth), height),
    );
  }

  @override
  void performLayout() {
    _syncListeners();
    final BoxConstraints constraints = this.constraints;
    final List<RenderBox> children = _children;
    if (children.isEmpty) {
      size = constraints.smallest;
      return;
    }

    final (List<double> baseWidths, double mainSpace) = _baseWidths(
      children,
      constraints,
    );
    final List<double> widths = M3ButtonGroup.expandPressed(
      widths: baseWidths,
      progress: [
        for (final RenderBox child in children)
          _data(child).pressProgress?.value ?? 0,
      ],
      compressionLimits: [
        for (final RenderBox child in children) _data(child).compressionLimit,
      ],
      expandedRatio: expandedRatio,
    );

    double height = 0;
    for (int i = 0; i < children.length; i++) {
      children[i].layout(
        constraints.copyWith(minWidth: widths[i], maxWidth: widths[i]),
        parentUsesSize: true,
      );
      height = math.max(height, children[i].size.height);
    }

    size = constraints.constrain(
      Size(math.max(mainSpace, constraints.minWidth), height),
    );

    // `Arrangement.spacedBy(space)`: от начала строки с учётом направления.
    double x = 0;
    for (int i = 0; i < children.length; i++) {
      final RenderBox child = children[i];
      final double y = switch (crossAxisAlignment) {
        CrossAxisAlignment.center => (size.height - child.size.height) / 2,
        CrossAxisAlignment.end => size.height - child.size.height,
        _ => 0,
      };
      final double left = textDirection == TextDirection.ltr
          ? x
          : size.width - x - child.size.width;
      _data(child).offset = Offset(left, y);
      x += widths[i] + spacing;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Элемент standard button group, реагирующий на нажатие — порт
/// `Modifier.animateWidth(interactionSource, compressionLimit)` и
/// `EnlargeOnPressNode`.
///
/// Прогресс нажатия (`pressedAnimatable`): пока кнопка нажата — пружина
/// `FastSpatial` к 1. Когда нажатий не осталось, сначала ждём, пока прогресс
/// превысит 0.75 (не дольше 1000 мс, проверка раз в кадр), и только потом —
/// пружина к 0. Поэтому даже короткий тап заметно расширяет кнопку. Новое
/// нажатие отменяет ожидание (`collectLatest`).
///
/// [builder] получает [WidgetStatesController], который нужно передать
/// кнопке (аналог общего `interactionSource`).
class M3ButtonGroupItem extends StatefulWidget {
  const M3ButtonGroupItem({
    super.key,
    this.statesController,
    this.compressionLimit = M3ButtonGroupDefaults.compressionLimit,
    this.weight,
    required this.builder,
  });

  /// Внешний контроллер; `null` — элемент создаёт свой.
  final WidgetStatesController? statesController;

  /// На сколько соседи могут сжать этот элемент — его внутренний отступ.
  final double compressionLimit;

  /// `Modifier.weight`; `null` — ширина по содержимому.
  final double? weight;

  final Widget Function(
    BuildContext context,
    WidgetStatesController statesController,
  )
  builder;

  @override
  State<M3ButtonGroupItem> createState() => _M3ButtonGroupItemState();
}

class _M3ButtonGroupItemState extends State<M3ButtonGroupItem>
    with TickerProviderStateMixin {
  WidgetStatesController? _internalStates;
  WidgetStatesController get _states =>
      widget.statesController ?? _internalStates!;

  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
  );

  /// Кадровое ожидание `waitUntil`.
  Ticker? _waitTicker;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.statesController == null) {
      _internalStates = WidgetStatesController();
    }
    _states.addListener(_handleStatesChanged);
    _pressed = _states.value.contains(WidgetState.pressed);
  }

  @override
  void didUpdateWidget(M3ButtonGroupItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      (oldWidget.statesController ?? _internalStates)?.removeListener(
        _handleStatesChanged,
      );
      if (widget.statesController != null) {
        _internalStates?.dispose();
        _internalStates = null;
      } else {
        _internalStates ??= WidgetStatesController();
      }
      _states.addListener(_handleStatesChanged);
      _handleStatesChanged();
    }
  }

  @override
  void dispose() {
    _states.removeListener(_handleStatesChanged);
    _internalStates?.dispose();
    _waitTicker?.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _handleStatesChanged() {
    if (!mounted) return;
    final bool pressed = _states.value.contains(WidgetState.pressed);
    // `distinctUntilChanged()`.
    if (pressed == _pressed) return;
    _pressed = pressed;
    _cancelWait();

    if (reduceMotionOf(context)) {
      // Расширение — чисто двигательный эффект, состояние оно не передаёт;
      // при «Удалить анимации» кнопка остаётся своей ширины.
      _progress.value = 0;
      return;
    }
    if (pressed) {
      m3SpringTo(_progress, AppMotion.fastSpatial, 1);
    } else {
      _startWait();
    }
  }

  void _startWait() {
    _waitTicker ??= createTicker(_onWaitTick);
    _waitTicker!.start();
  }

  void _onWaitTick(Duration elapsed) {
    if (_progress.value > M3ButtonGroupDefaults.releaseThreshold ||
        elapsed > M3ButtonGroupDefaults.maxReleaseWait) {
      _cancelWait();
      m3SpringTo(_progress, AppMotion.fastSpatial, 0);
    }
  }

  void _cancelWait() {
    if (_waitTicker?.isActive ?? false) _waitTicker!.stop();
  }

  @override
  Widget build(BuildContext context) {
    return _M3ButtonGroupItemData(
      pressProgress: _progress,
      compressionLimit: widget.compressionLimit,
      weight: widget.weight,
      child: widget.builder(context, _states),
    );
  }
}

class _M3ButtonGroupItemData extends ParentDataWidget<M3ButtonGroupParentData> {
  const _M3ButtonGroupItemData({
    required this.pressProgress,
    required this.compressionLimit,
    required this.weight,
    required super.child,
  });

  final Animation<double> pressProgress;
  final double compressionLimit;
  final double? weight;

  @override
  void applyParentData(RenderObject renderObject) {
    final M3ButtonGroupParentData data =
        renderObject.parentData! as M3ButtonGroupParentData;
    bool needsLayout = false;
    if (data.pressProgress != pressProgress) {
      data.pressProgress = pressProgress;
      needsLayout = true;
    }
    if (data.compressionLimit != compressionLimit) {
      data.compressionLimit = compressionLimit;
      needsLayout = true;
    }
    if (data.weight != weight) {
      data.weight = weight;
      needsLayout = true;
    }
    if (needsLayout) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => M3ButtonGroup;
}
