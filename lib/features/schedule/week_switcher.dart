import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/lesson.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/day_selector.dart';

/// Выбор недели над лентой дней: «Эта неделя» / «Следующая» и даты недели.
///
/// Недели — взаимоисключающие варианты одного набора, поэтому connected button
/// group (button groups → Guidelines: замена segmented button, растягивается
/// на ширину экрана).
class WeekSwitcher extends StatelessWidget {
  const WeekSwitcher({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.now,
    required this.onSelected,
  });

  final List<ScheduleDay> days;

  /// Выбранный день в [days].
  final int selectedIndex;

  final DateTime now;

  /// Выбран день [days] с этим индексом.
  final ValueChanged<int> onSelected;

  static DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// «Эта неделя», «Следующая», «Прошлая» или даты недели.
  static String labelOf(List<ScheduleDay> week, DateTime now) {
    final DateTime a = _mondayOf(week.first.date);
    final DateTime b = _mondayOf(now);
    // Через UTC: разница в днях не должна зависеть от перевода часов.
    final int diff =
        DateTime.utc(
          a.year,
          a.month,
          a.day,
        ).difference(DateTime.utc(b.year, b.month, b.day)).inDays ~/
        7;
    return switch (diff) {
      0 => 'Эта неделя',
      1 => 'Следующая',
      -1 => 'Прошлая',
      _ => rangeOf(week),
    };
  }

  /// `14–19 сентября` или `28 сентября – 3 октября`.
  static String rangeOf(List<ScheduleDay> week) {
    final DateTime first = week.first.date;
    final DateTime last = week.last.date;
    if (first.month == last.month) {
      return '${first.day}–${DateFormat('d MMMM', 'ru').format(last)}';
    }
    final DateFormat format = DateFormat('d MMMM', 'ru');
    return '${format.format(first)} – ${format.format(last)}';
  }

  /// День, который открывается при выборе недели [week]: сегодня, если он в
  /// этой неделе; иначе тот же день недели, что выбран сейчас; иначе первый.
  static int dayToOpen(
    List<ScheduleDay> days,
    List<int> week,
    int selectedIndex,
    DateTime now,
  ) {
    for (final int i in week) {
      if (DateUtils.isSameDay(days[i].date, now)) return i;
    }
    final int weekday = days[selectedIndex].date.weekday;
    for (final int i in week) {
      if (days[i].date.weekday == weekday) return i;
    }
    return week.first;
  }

  @override
  Widget build(BuildContext context) {
    final List<List<int>> weeks = DaySelector.weeksOf(days);
    final int selectedWeek = weeks.indexWhere(
      (week) => week.contains(selectedIndex),
    );
    final List<ScheduleDay> current = [
      for (final int i in weeks[selectedWeek]) days[i],
    ];
    final String range = rangeOf(current);
    final String label = labelOf(current, now);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.screenMargin(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (weeks.length > 1)
            ConnectedButtonGroup<int>(
              values: [for (int w = 0; w < weeks.length; w++) w],
              labelOf: (w) =>
                  labelOf([for (final int i in weeks[w]) days[i]], now),
              selected: selectedWeek,
              onSelected: (w) =>
                  onSelected(dayToOpen(days, weeks[w], selectedIndex, now)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space100,
              AppSpacing.space100,
              AppSpacing.space100,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                // Одна неделя — без переключателя, подпись с названием.
                weeks.length > 1 || label == range ? range : '$label · $range',
                style: context.text.bodyMedium!.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
