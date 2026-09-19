import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_state_layer.dart';

/// Пункт [M3NavigationBar]: иконка Material Symbols и подпись.
///
/// Активный пункт рисует иконку заполненной (`fill: 1`), неактивные —
/// контурной: https://m3.material.io/components/navigation-bar/guidelines
/// (Anatomy → Icons).
@immutable
class M3NavigationDestination {
  const M3NavigationDestination({
    required this.icon,
    required this.label,
    this.badgeLabel,
  });

  final IconData icon;

  /// Подпись 1–2 слова. Она же — метка для screen reader.
  final String label;

  /// Текст для screen reader, если на иконке точка непрочитанного (small
  /// badge); `null` — точки нет. На выбранном пункте точка не показывается
  /// (badges → Guidelines → With other components).
  final String? badgeLabel;
}

/// Flexible navigation bar Material 3 Expressive с вертикальными пунктами.
///
/// Порт Compose `ShortNavigationBar` (`ShortNavigationBar.kt`) с
/// `ShortNavigationBarArrangement.EqualWeight` и `ShortNavigationBarItem` с
/// `NavigationItemIconPosition.Top` (`NavigationItem.kt`).
///
/// Отличия от `NavigationBar` Flutter, ради которых виджет написан заново:
///   * индикатор раскрывается по ширине 0 → 56dp от центра иконки и
///     проявляется одной пружиной `DefaultSpatial` с сохранением скорости
///     (`animateIndicatorProgressAsState`), а не масштабом 0.4 → 1 по кривой;
///   * высота растёт вместе с подписью при крупном шрифте
///     (`EqualWeightContentMeasurePolicy` берёт `maxIntrinsicHeight` пунктов);
///   * повторное нажатие на активный пункт — отдельный колбэк
///     [onReselected] (Guidelines → Behavior → Navigation: «Re-selecting the
///     currently active destination should reset the scroll position»).
class M3NavigationBar extends StatelessWidget {
  const M3NavigationBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    this.onReselected,
  }) : assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final List<M3NavigationDestination> destinations;

  /// Нажат неактивный пункт.
  final ValueChanged<int> onSelected;

  /// Нажат уже активный пункт: экран раздела прокручивают к началу.
  final ValueChanged<int>? onReselected;

  /// `NavigationBarTokens.ContainerHeight` — минимальная высота
  /// (`defaultMinSize(minHeight)`).
  static const double containerHeight = 64;

  /// `NavigationBarVerticalItemTokens.ActiveIndicatorWidth`.
  static const double indicatorWidth = 56;

  /// `NavigationBarVerticalItemTokens.ActiveIndicatorHeight`.
  static const double indicatorHeight = 32;

  /// `NavigationBarVerticalItemTokens.IconSize`.
  static const double iconSize = 24;

  /// `TopIconItemVerticalPadding` = `NavigationBarVerticalItemTokens.ContainerBetweenSpace`.
  static const double itemVerticalPadding = 6;

  /// `TopIconIndicatorToLabelPadding`.
  static const double indicatorToLabelPadding = 4;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    // `Surface(color = NavigationBarTokens.ContainerColor)`: без тени и
    // тонального наложения. Material нужен и как холст для ripple пунктов.
    return Material(
      color: colors.surfaceContainer,
      // `ShortNavigationBarDefaults.windowInsets` — системные панели снизу и
      // по бокам.
      child: SafeArea(
        top: false,
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          explicitChildNodes: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: containerHeight),
            // EqualWeight: одинаковая ширина у всех пунктов, высота — по самому
            // высокому (`maxIntrinsicHeight(itemWidth)`), но не меньше 64dp.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _M3NavigationItem(
                        destination: destinations[i],
                        index: i,
                        count: destinations.length,
                        selected: i == selectedIndex,
                        onTap: () {
                          if (i == selectedIndex) {
                            onReselected?.call(i);
                          } else {
                            onSelected(i);
                          }
                        },
                      ),
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

/// `NavigationItem` + `TopIconOrIconOnlyMeasurePolicy` с подписью.
class _M3NavigationItem extends StatefulWidget {
  const _M3NavigationItem({
    required this.destination,
    required this.index,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final M3NavigationDestination destination;
  final int index;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_M3NavigationItem> createState() => _M3NavigationItemState();
}

class _M3NavigationItemState extends State<_M3NavigationItem>
    with SingleTickerProviderStateMixin {
  /// Прогресс индикатора. Без границ: пружина `DefaultSpatial` перелетает 1,
  /// и этот перелёт виден в ширине, как в Compose.
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(_M3NavigationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final double target = widget.selected ? 1 : 0;
    if (reduceMotionOf(context)) {
      _progress.value = target;
    } else {
      // `animateFloatAsState(MotionSchemeKeyTokens.DefaultSpatial)`: при смене
      // цели посреди движения скорость сохраняется.
      _progress.springTo(AppMotion.defaultSpatial, target).then((_) {
        // `Animatable` в Compose завершает анимацию ровно на цели, а
        // `SpringSimulation` останавливается в пределах допуска.
        if (mounted) _progress.value = target;
      });
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool selected = widget.selected;
    final String? badgeLabel = widget.destination.badgeLabel;

    // Иконка и подпись меняются без анимации: `NavigationItem` передаёт цвет
    // сразу, `StyledLabel(animateColor = false)`.
    final Color iconColor = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final Color labelColor = selected
        ? colors.secondary
        : colors.onSurfaceVariant;

    final Widget content = Column(
      children: [
        const SizedBox(height: M3NavigationBar.itemVerticalPadding),
        SizedBox(
          height: M3NavigationBar.indicatorHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _Indicator(progress: _progress, color: colors.secondaryContainer),
              // Small badge: `Badge` без подписи сажает точку 6dp так, что её
              // нижний начальный угол отстоит от верхнего конечного угла
              // иконки на 6×6dp, — как в спеке, потому что обёрнута сама
              // иконка 24dp, а не зона нажатия.
              Badge(
                isLabelVisible: badgeLabel != null && !selected,
                child: Icon(
                  widget.destination.icon,
                  size: M3NavigationBar.iconSize,
                  fill: selected ? 1 : 0,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: M3NavigationBar.indicatorToLabelPadding),
        // Подпись по ширине пункта; при крупном шрифте переносится, и панель
        // растёт (Accessibility → Text scaling and truncation).
        Text(
          widget.destination.label,
          textAlign: TextAlign.center,
          style: text.labelMedium!.copyWith(color: labelColor),
        ),
        // `selectable(role = Role.Tab)` внутри `selectableGroup()`: TalkBack
        // называет позицию вкладки. Роль Flutter на Android не озвучивается,
        // поэтому позиция добавлена к метке, как в `NavigationBar` Flutter.
        Semantics(
          label: MaterialLocalizations.of(
            context,
          ).tabLabel(tabIndex: widget.index + 1, tabCount: widget.count),
        ),
        // Бейдж озвучивается после названия пункта (badges → Accessibility).
        if (badgeLabel != null && !selected) Semantics(label: badgeLabel),
        const SizedBox(height: M3NavigationBar.itemVerticalPadding),
      ],
    );

    // Зона нажатия — весь пункт (не меньше 48×48dp: ширина — доля панели,
    // высота — не меньше 64dp).
    return MergeSemantics(
      child: Semantics(
        role: SemanticsRole.tab,
        selected: selected,
        child: _IndicatorInkResponse(
          onTap: widget.onTap,
          overlayColor: AppStateLayer.overlay(colors.onSecondaryContainer),
          child: content,
        ),
      ),
    );
  }
}

/// `Indicator`: пилюля `secondaryContainer` шириной `56 * progress` по центру
/// иконки и прозрачностью `progress` (`graphicsLayer { alpha = progress }`).
/// Высота 32dp постоянна — анимация идёт по одной оси (Guidelines → Behavior →
/// Selection).
class _Indicator extends StatelessWidget {
  const _Indicator({required this.progress, required this.color});

  final Animation<double> progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        // `indicatorAnimationProgress.value.coerceAtLeast(0f)`.
        final double value = progress.value < 0 ? 0 : progress.value;
        if (value == 0) return const SizedBox.shrink();
        // Stack ограничивает ширину шириной пункта, поэтому перелёт шире 56dp,
        // как и `looseConstraints.constrain` в Compose, за пункт не выходит.
        return SizedBox(
          key: const ValueKey<String>('m3-navigation-indicator'),
          width: M3NavigationBar.indicatorWidth * value,
          height: M3NavigationBar.indicatorHeight,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              // `NavigationBarTokens.ItemActiveIndicatorShape` = corner.full.
              shape: const StadiumBorder(),
              color: color.withValues(alpha: color.a * value.clamp(0.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

/// Нажимается весь пункт, а ripple и state layer рисуются только в рамке
/// индикатора 56×32 (`IndicatorRipple` + `MappedInteractionSource`).
/// Рамка полная, без анимации ширины: в Compose ripple — отдельный слой, чтобы
/// раскрытие индикатора не сбивало его тайминг.
class _IndicatorInkResponse extends InkResponse {
  const _IndicatorInkResponse({
    required super.onTap,
    required super.overlayColor,
    required super.child,
  }) : super(containedInkWell: true, customBorder: const StadiumBorder());

  @override
  RectCallback? getRectCallback(RenderBox referenceBox) {
    return () {
      final double width = referenceBox.size.width;
      final double indicatorWidth = width < M3NavigationBar.indicatorWidth
          ? width
          : M3NavigationBar.indicatorWidth;
      return Rect.fromLTWH(
        (width - indicatorWidth) / 2,
        M3NavigationBar.itemVerticalPadding,
        indicatorWidth,
        M3NavigationBar.indicatorHeight,
      );
    };
  }
}
