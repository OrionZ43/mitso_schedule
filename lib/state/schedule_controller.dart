import 'dart:convert';

import 'package:flutter/material.dart' show DateUtils, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mitso/mitso_client.dart';
import '../data/models/group_ref.dart';
import '../data/models/lesson.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Расписание выбранной группы.
@immutable
class ScheduleState {
  const ScheduleState({
    required this.weeks,
    required this.fetchedAt,
    this.refreshError,
  });

  final List<ScheduleWeek> weeks;

  /// Когда данные были получены с сайта.
  final DateTime fetchedAt;

  /// Последнее обновление не удалось, показаны сохранённые данные.
  final MitsoException? refreshError;

  /// Все дни всех недель подряд.
  List<ScheduleDay> get days => [for (final w in weeks) ...w.days];

  ScheduleState withRefreshError(MitsoException? error) =>
      ScheduleState(weeks: weeks, fetchedAt: fetchedAt, refreshError: error);
}

final scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, ScheduleState?>(
      ScheduleController.new,
      retry: noRetry,
    );

/// Загружает расписание: сначала сохранённое, затем свежее с сайта.
class ScheduleController extends AsyncNotifier<ScheduleState?> {
  static String _cacheKey(GroupRef group) =>
      'schedule.cache.${group.facultyId}|${group.formId}|${group.courseId}|${group.groupId}';

  @override
  Future<ScheduleState?> build() async {
    final GroupRef? group = ref.watch(selectedGroupProvider);
    if (group == null) return null;

    final ScheduleState? cached = _readCache(group);
    if (cached != null) {
      // Сохранённое показываем сразу, свежее подтягиваем в фоне.
      Future<void>(refresh);
      return cached;
    }
    return _fetch(group);
  }

  /// Обновление с сайта. При ошибке остаются прежние данные, а ошибка
  /// отмечается в [ScheduleState.refreshError].
  Future<void> refresh() async {
    final GroupRef? group = ref.read(selectedGroupProvider);
    if (group == null) return;

    try {
      final ScheduleState fresh = await _fetch(group);
      if (ref.read(selectedGroupProvider) == group) state = AsyncData(fresh);
    } on MitsoException catch (e, stack) {
      if (ref.read(selectedGroupProvider) != group) return;
      final ScheduleState? current = state.value;
      state = current != null
          ? AsyncData(current.withRefreshError(e))
          : AsyncError(e, stack);
    }
  }

  Future<ScheduleState> _fetch(GroupRef group) async {
    final MitsoApi api = await ref.read(mitsoApiProvider.future);
    final List<ScheduleWeek> weeks = await api.groupSchedule(group);
    final ScheduleState result = ScheduleState(
      weeks: weeks,
      fetchedAt: ref.read(clockProvider)(),
    );
    _writeCache(group, result);
    return result;
  }

  ScheduleState? _readCache(GroupRef group) {
    final String? raw = ref
        .read(sharedPreferencesProvider)
        .getString(_cacheKey(group));
    if (raw == null) return null;
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      return ScheduleState(
        fetchedAt: DateTime.parse(json['fetchedAt']! as String),
        weeks: [
          for (final Object? w in json['weeks']! as List<Object?>)
            ScheduleWeek.fromJson(w! as Map<String, Object?>),
        ],
      );
    } catch (_) {
      // Формат кэша поменялся или запись повреждена — просто грузим заново.
      return null;
    }
  }

  void _writeCache(GroupRef group, ScheduleState state) {
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _cacheKey(group),
          jsonEncode({
            'fetchedAt': state.fetchedAt.toIso8601String(),
            'weeks': [for (final w in state.weeks) w.toJson()],
          }),
        );
  }
}

/// Выбранный день. `null` — ещё не выбран: показывается сегодняшний или
/// ближайший следующий учебный день.
final selectedDateProvider =
    NotifierProvider<SelectedDateController, DateTime?>(
      SelectedDateController.new,
    );

class SelectedDateController extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    // Смена группы сбрасывает выбор дня.
    ref.watch(selectedGroupProvider);
    return null;
  }

  void select(DateTime date) => state = date;
}

/// День для показа: выбранный пользователем, иначе сегодня, иначе ближайший
/// следующий, иначе первый доступный.
ScheduleDay? resolveSelectedDay(
  List<ScheduleDay> days,
  DateTime? selected,
  DateTime now,
) {
  if (days.isEmpty) return null;
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime target = selected ?? today;
  for (final ScheduleDay day in days) {
    if (DateUtils.isSameDay(day.date, target)) return day;
  }
  if (selected == null) {
    for (final ScheduleDay day in days) {
      if (day.date.isAfter(today)) return day;
    }
  }
  return days.first;
}

/// Фильтр раскрытого поиска: где искать по загруженному расписанию.
enum ScheduleSearchField {
  subject('Предметы'),
  teacher('Преподаватели'),
  room('Аудитории');

  const ScheduleSearchField(this.label);

  final String label;
}

final searchFieldProvider =
    NotifierProvider<SearchFieldController, ScheduleSearchField>(
      SearchFieldController.new,
    );

class SearchFieldController extends Notifier<ScheduleSearchField> {
  @override
  ScheduleSearchField build() => ScheduleSearchField.subject;

  void select(ScheduleSearchField field) => state = field;
}
