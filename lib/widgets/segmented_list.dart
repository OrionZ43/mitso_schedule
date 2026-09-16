import 'package:flutter/material.dart';

import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Segmented-список из M3 Expressive: каждый пункт в своём контейнере.
///
/// https://github.com/material-components/material-components-android/blob/master/docs/components/List.md
///
/// Геометрия — из `listitem/res/values/styles.xml` и каталога MDC:
/// у первого пункта верхние углы `large` (16dp) и нижние `extraSmall` (4dp),
/// у средних все `extraSmall`, у последнего наоборот, у одиночного все `large`;
/// между пунктами зазор 2dp, разделителей нет.
///
/// Отступление: по токену контейнер пункта — `surface`, а в каталоге MDC
/// список лежит на подложке `surfaceContainerHigh`. Фон вкладок здесь сам
/// `surface`, поэтому контейнер пункта — `surfaceContainer`: так пункты
/// отделяются от фона, как задумано.
class SegmentedList extends StatelessWidget {
  const SegmentedList({super.key, required this.children});

  final List<Widget> children;

  /// `cat_list_item_margin` в каталоге MDC.
  static const double gap = 2;

  /// `shapeCornerSizeLarge` у крайних пунктов.
  static const double outerCorner = AppShapes.large;

  /// `shapeCornerSizeExtraSmall` на стыках.
  static const double innerCorner = AppShapes.extraSmall;

  @override
  Widget build(BuildContext context) {
    final Color container = context.colors.surfaceContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          // Material, а не Container: ListTile рисует фон и ripple на
          // ближайшем Material-предке.
          Material(
            color: container,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? outerCorner : innerCorner),
                bottom: Radius.circular(
                  i == children.length - 1 ? outerCorner : innerCorner,
                ),
              ),
            ),
            child: children[i],
          ),
        ],
      ],
    );
  }
}
