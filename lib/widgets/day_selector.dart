import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/models/lesson.dart';
import '../theme/app_motion.dart';
import '../theme/app_transitions.dart';
import '../theme/app_typography.dart';
import 'm3_button_group.dart';
import 'm3_buttons.dart';
import 'm3_toggle_button.dart';

/// Селектор дней: по standard button group из toggle-кнопок на каждую
/// календарную неделю.
///
/// Неделю выбирает переключатель над лентой (`WeekSwitcher`), поэтому пальцем
/// лента не листается: при выборе дня другой недели она сама переезжает к
/// ней.
///
/// Какой компонент и почему — `docs/m3/components/button-groups.md`
/// («Селектор дней»): выбор одного дня из связанного набора, где соседи
/// реагируют на нажатие, — standard button group (single-select,
/// selection-required). Группа идёт одной строкой без переноса и без
/// прокрутки, поэтому на страницу — одна неделя, а недели — страницы
/// [PageView]: переход между равноправными страницами — паттерн lateral
/// (контент едет за пальцем, без затухания).
///
/// Кнопка дня — filled toggle (`ToggleButton`): невыбранная surfaceContainer /
/// onSurfaceVariant, выбранная primary / onPrimary, цвет без анимации;
/// формы по фактической высоте (`ToggleButtonDefaults.shapesFor`): round →
/// при выборе square, pressed — по токену размера; морф FastSpatial. Нажатая
/// кнопка расширяется за счёт соседей ([M3ButtonGroup]).
///
/// Осознанное отступление: подпись в две строки — день недели и число
/// (Guidelines «Label text»: «Don't truncate or wrap label text»). Одной
/// строкой «Пн 16» не помещается в ширину кнопки недели на компактном
/// экране; причина записана в `button-groups.md`.
class DaySelector extends StatefulWidget {
  const DaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Дни по порядку дат; обычно две недели.
  final List<ScheduleDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Поля страницы в компактном окне — 16dp (Layout, «Margins»).
  static const double horizontalPadding = 16;

  /// Вертикальный отступ содержимого — `ButtonDefaults.ContentPadding`
  /// (`ButtonVerticalPadding` = 8dp): у двухстрочной подписи своего токена нет.
  static const double verticalPadding = 8;

  /// Смена недели программно — переход с началом и концом на экране:
  /// Emphasized, 500 мс (`motion.md`, «Переходы»).
  static const Duration weekChangeDuration = Durations.long2;

  /// Индексы [days], разбитые по календарным неделям (с понедельника).
  static List<List<int>> weeksOf(List<ScheduleDay> days) {
    final List<List<int>> weeks = [];
    DateTime? currentMonday;
    for (int i = 0; i < days.length; i++) {
      final DateTime date = days[i].date;
      final DateTime monday = DateTime(
        date.year,
        date.month,
        date.day - (date.weekday - DateTime.monday),
      );
      if (currentMonday == null || monday != currentMonday) {
        weeks.add([]);
        currentMonday = monday;
      }
      weeks.last.add(i);
    }
    return weeks;
  }

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  late List<List<int>> _weeks = DaySelector.weeksOf(widget.days);
  late final PageController _pages = PageController(
    initialPage: _weekOf(widget.selectedIndex),
  );

  int _weekOf(int dayIndex) {
    for (int w = 0; w < _weeks.length; w++) {
      if (_weeks[w].contains(dayIndex)) return w;
    }
    return 0;
  }

  @override
  void didUpdateWidget(DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Список может пересоздаваться при каждой сборке экрана; листать назад к
    // выбранной неделе нужно, только если сменились сами даты.
    final bool daysChanged =
        !identical(oldWidget.days, widget.days) &&
        (oldWidget.days.length != widget.days.length ||
            Iterable<int>.generate(
              widget.days.length,
            ).any((i) => oldWidget.days[i].date != widget.days[i].date));
    if (daysChanged) _weeks = DaySelector.weeksOf(widget.days);
    if (daysChanged || oldWidget.selectedIndex != widget.selectedIndex) {
      // Не во время сборки: прокрутка рассылает уведомления.
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!mounted || !_pages.hasClients) return;
    final int target = _weekOf(widget.selectedIndex);
    final double? page = _pages.page;
    if (page != null && page == target.toDouble()) return;
    if (reduceMotionOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: DaySelector.weekChangeDuration,
        curve: AppTransitions.emphasized,
      );
    }
  }

  /// Высота строки текста с текущим масштабом шрифта.
  static double _lineHeight(TextStyle style, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();

    final TextTheme text = context.text;
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // [PageView] нужна высота заранее: она растёт вместе с масштабом шрифта,
    // минимум — высота кнопки размера M.
    final double contentHeight =
        2 * DaySelector.verticalPadding +
        _lineHeight(text.labelLarge!, scaler) +
        _lineHeight(text.titleMedium!, scaler);
    final double buttonHeight = math
        .max(M3ButtonSize.medium.height, contentHeight)
        .ceilToDouble();
    final M3ButtonSize bucket = M3ToggleButtonDefaults.sizeForHeight(
      buttonHeight,
    );
    final M3ToggleButtonShapes shapes = M3ToggleButtonDefaults.shapesForSize(
      bucket,
    );

    return SizedBox(
      height: math.max(buttonHeight, kMinInteractiveDimension),
      child: PageView.builder(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _weeks.length,
        itemBuilder: (context, week) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DaySelector.horizontalPadding,
          ),
          child: M3ButtonGroup(
            spacing: M3ButtonGroupDefaults.spacingFor(bucket),
            children: [
              for (final int index in _weeks[week])
                M3ButtonGroupItem(
                  key: ValueKey(widget.days[index].date),
                  weight: 1,
                  builder: (context, states) => M3ToggleButton(
                    checked: index == widget.selectedIndex,
                    onCheckedChange: (_) => widget.onSelected(index),
                    size: bucket,
                    shapes: shapes,
                    minHeight: buttonHeight,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: DaySelector.verticalPadding,
                    ),
                    semantics: M3ButtonSemantics.radio,
                    statesController: states,
                    child: _DayLabel(day: widget.days[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// День недели над числом; цвет — цвет содержимого кнопки.
class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day});

  final ScheduleDay day;

  @override
  Widget build(BuildContext context) {
    final Color color = DefaultTextStyle.of(context).style.color!;
    return Semantics(
      label: '${day.title}, ${DateFormat.MMMMd('ru').format(day.date)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `md.comp.button.small.label-text` и `medium.label-text`.
          Text(
            day.shortName,
            style: context.text.labelLarge!.copyWith(color: color),
          ),
          Text(
            day.dayNumber,
            style: context.text.titleMedium!.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
