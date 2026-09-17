import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_motion.dart';

/// Физика и анимации pager'а по Compose Foundation (`pager/Pager.kt`,
/// `pager/PagerState.kt`) — основа паттерна **lateral**:
/// https://m3.material.io/styles/motion/transitions — равноправные страницы
/// едут вместе и следуют за пальцем, без затухания.
abstract final class M3Pager {
  /// `PagerDefaults.flingBehavior(snapAnimationSpec = spring(stiffness =
  /// Spring.StiffnessMediumLow))`: докатка к странице после жеста —
  /// пружина без перелёта (DampingRatioNoBouncy = 1), жёсткость 400.
  static final SpringDescription snapSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);

  /// `MaxPagesForAnimateScroll`: дальше трёх страниц Compose сначала прыгает
  /// поближе и анимирует только остаток.
  static const int maxPagesForAnimateScroll = 3;

  /// Переход к [page] как `animateScrollToPage`.
  static Future<void> animateToPage(
    PageController controller,
    int page, {
    bool reduceMotion = false,
  }) async {
    if (!controller.hasClients) return;
    final double current = controller.page ?? page.toDouble();
    if (reduceMotion) {
      controller.jumpToPage(page);
      return;
    }
    if ((page - current).abs() > maxPagesForAnimateScroll) {
      controller.jumpToPage(
        page > current
            ? page - maxPagesForAnimateScroll
            : page + maxPagesForAnimateScroll,
      );
    }
    // `PagerState.animateScrollToPage(animationSpec = spring())`. Критически
    // задемпфированная пружина из покоя подобна себе при любом расстоянии,
    // поэтому нормированная кривая точна для любого числа страниц.
    await controller.animateToPage(
      page,
      duration: AppMotion.composeDefault.duration,
      curve: AppMotion.composeDefault.curve,
    );
  }
}

/// `PageScrollPhysics` с пружиной докатки Compose.
class M3PageScrollPhysics extends PageScrollPhysics {
  const M3PageScrollPhysics({super.parent});

  @override
  M3PageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      M3PageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => M3Pager.snapSpring;
}

/// Горизонтальный pager, высота которого следует за высотой страниц.
///
/// `PageView` требует ограниченной высоты, а страницы дня внутри общего
/// вертикального списка разной длины. Каждая страница меряется в полный рост,
/// высота pager'а плавно переходит между соседними по мере сдвига — как
/// содержимое, которое едет вместе с пальцем.
class ExpandablePageView extends StatefulWidget {
  const ExpandablePageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.minHeight = 0,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  /// Нижняя граница, пока страница ещё не измерена.
  final double minHeight;

  @override
  State<ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<ExpandablePageView> {
  final Map<int, double> _heights = {};

  /// Растёт, когда измерена новая высота страницы.
  final ValueNotifier<int> _heightsVersion = ValueNotifier(0);

  @override
  void didUpdateWidget(ExpandablePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) _heights.clear();
  }

  @override
  void dispose() {
    _heightsVersion.dispose();
    super.dispose();
  }

  double get _height {
    final PageController c = widget.controller;
    final double page = c.hasClients && c.position.hasContentDimensions
        ? (c.page ?? c.initialPage.toDouble())
        : c.initialPage.toDouble();
    final int lower = page.floor().clamp(0, math.max(0, widget.itemCount - 1));
    final int upper = page.ceil().clamp(0, math.max(0, widget.itemCount - 1));
    final double? a = _heights[lower];
    final double? b = _heights[upper];
    final double t = page - page.floorToDouble();
    final double height = a != null && b != null
        ? a + (b - a) * t
        : (a ?? b ?? widget.minHeight);
    return math.max(height, widget.minHeight);
  }

  void _report(int index, double height) {
    if (_heights[index] == height) return;
    // Размер известен только после раскладки — обновляемся в следующем кадре.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _heights[index] != height) {
        _heights[index] = height;
        _heightsVersion.value++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // На каждом кадре перелистывания меняется только высота: страницы
    // передаются в builder готовыми и не перестраиваются.
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _heightsVersion]),
      builder: (context, pages) => SizedBox(height: _height, child: pages),
      child: PageView.builder(
        controller: widget.controller,
        physics: const M3PageScrollPhysics(),
        // Соседние страницы строятся заранее: при перелистывании видно обе.
        allowImplicitScrolling: true,
        itemCount: widget.itemCount,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) => OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: _MeasureHeight(
            onHeight: (h) => _report(index, h),
            // Высота pager'а меняется на каждом кадре перелистывания, и
            // OverflowBox перерисовывается — страница остаётся в своём слое.
            child: RepaintBoundary(child: widget.itemBuilder(context, index)),
          ),
        ),
      ),
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
