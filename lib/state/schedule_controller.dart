import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../data/models/lesson.dart';

/// Неделя целиком.
final weekProvider = Provider<List<ScheduleDay>>((ref) => MockData.week);

/// Индекс выбранного дня в селекторе Пн–Сб.
final selectedDayIndexProvider = NotifierProvider<SelectedDayController, int>(
  SelectedDayController.new,
);

class SelectedDayController extends Notifier<int> {
  @override
  int build() => MockData.initialDayIndex;

  void select(int index) {
    if (index < 0 || index >= MockData.week.length) return;
    state = index;
  }
}

/// День, который сейчас показан на вкладке «Расписание».
final selectedDayProvider = Provider<ScheduleDay>((ref) {
  final index = ref.watch(selectedDayIndexProvider);
  return ref.watch(weekProvider)[index];
});

/// Выбранный фильтр в раскрытом поиске: `Группы` / `Преподаватели` / `Аудитории`.
///
/// `null` — ни один фильтр не выбран (повторное нажатие снимает выбор).
final searchFilterProvider = NotifierProvider<SearchFilterController, String?>(
  SearchFilterController.new,
);

class SearchFilterController extends Notifier<String?> {
  @override
  String? build() => MockData.searchFilters.first;

  void toggle(String filter) {
    state = state == filter ? null : filter;
  }
}

/// Имитация похода за свежим расписанием для pull-to-refresh.
final scheduleRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () => Future<void>.delayed(const Duration(milliseconds: 1200));
});
