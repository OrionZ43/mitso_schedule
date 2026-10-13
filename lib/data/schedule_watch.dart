import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../state/mitso_providers.dart'
    show ScheduleTarget, GroupTarget, TeacherTarget;
import 'mitso/mitso_client.dart';
import 'models/lesson.dart';
import 'schedule_alerts.dart';
import 'schedule_diff.dart';

/// Фоновая проверка расписания.
///
/// Сайт меняют без предупреждения: пару могут добавить за день. Задача
/// просыпается раз в три часа и только при наличии сети, сравнивает свежее
/// расписание с сохранённым и сообщает, что изменилось. Один запрос раз в три
/// часа — не «массовые запросы»: это та же страница, которую открывает
/// приложение.
abstract final class ScheduleWatch {
  static const String taskId = 'mitso.schedule.check';
  static const String taskName = 'schedule-check';
  static const Duration frequency = Duration(hours: 3);

  /// Ключи `SharedPreferences` — те же, что у контроллеров: в фоновом
  /// изоляте Riverpod недоступен.
  static const String targetKey = 'schedule.target';
  static const String changesKey = 'settings.scheduleChanges';
  static const String newWeekKey = 'settings.newWeekAlerts';
  static const String assessmentsKey = 'settings.assessmentAlerts';

  /// Один переключатель из 1.3.0 — значение по умолчанию для новых трёх.
  static const String legacyWatchKey = 'settings.scheduleWatch';

  /// Нужна ли фоновая проверка: хоть одно уведомление включено.
  static bool watches(SharedPreferences prefs) {
    final bool legacy = prefs.getBool(legacyWatchKey) ?? true;
    return (prefs.getBool(changesKey) ?? legacy) ||
        (prefs.getBool(newWeekKey) ?? legacy) ||
        (prefs.getBool(assessmentsKey) ?? legacy);
  }

  /// Когда фоновая проверка в последний раз сходила на сайт и чем кончилась —
  /// это видно в настройках.
  static const String lastCheckKey = 'schedule.lastCheckAt';
  static const String lastErrorKey = 'schedule.lastCheckError';

  static String cacheKey(ScheduleTarget target) =>
      'schedule.cache.${target.cacheKey}';

  /// Включает или выключает периодическую проверку.
  static Future<void> sync({required bool enabled}) async {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        taskId,
        taskName,
        frequency: frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().cancelByUniqueName(taskId);
    }
  }

  /// Проверка вне интерфейса: `false` — не удалось, стоит повторить.
  static Future<bool> check({
    ScheduleAlertPort alerts = const SystemScheduleAlerts(),
    DateTime Function() clock = DateTime.now,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!watches(prefs)) return true;
    final bool legacy = prefs.getBool(legacyWatchKey) ?? true;
    final bool tellChanges = prefs.getBool(changesKey) ?? legacy;
    final bool tellNewWeek = prefs.getBool(newWeekKey) ?? legacy;

    final ScheduleTarget? target = _target(prefs);
    if (target == null) return true;

    MitsoClient? client;
    try {
      client = await MitsoClient.create();
      final List<ScheduleWeek> fresh = switch (target) {
        GroupTarget(:final group) => await client.groupSchedule(group),
        TeacherTarget(:final name) => await client.teacherSchedule(name),
      };
      final List<ScheduleWeek> cached = _cached(prefs, target);
      final ScheduleDiff diff = diffSchedules(before: cached, after: fresh);

      _write(prefs, target, fresh, clock());
      await prefs.setString(lastCheckKey, clock().toIso8601String());
      await prefs.remove(lastErrorKey);

      if (tellNewWeek && diff.hasNewWeek) await alerts.showNewWeek(diff);
      if (tellChanges && diff.changes.isNotEmpty) {
        await alerts.showChanges(diff);
      }
      return true;
    } catch (error) {
      debugPrint('[Расписание] Фоновая проверка не удалась: $error');
      await prefs.setString(lastCheckKey, clock().toIso8601String());
      await prefs.setString(lastErrorKey, '$error');
      return false;
    } finally {
      client?.close();
    }
  }

  static ScheduleTarget? _target(SharedPreferences prefs) {
    final String? raw = prefs.getString(targetKey);
    if (raw == null) return null;
    try {
      return ScheduleTarget.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  static List<ScheduleWeek> _cached(
    SharedPreferences prefs,
    ScheduleTarget target,
  ) {
    final String? raw = prefs.getString(cacheKey(target));
    if (raw == null) return const [];
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      return [
        for (final Object? week in json['weeks']! as List<Object?>)
          ScheduleWeek.fromJson(week! as Map<String, Object?>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Формат записи — тот же, что у `ScheduleController`: кэш общий.
  static void _write(
    SharedPreferences prefs,
    ScheduleTarget target,
    List<ScheduleWeek> weeks,
    DateTime now,
  ) {
    prefs.setString(
      cacheKey(target),
      jsonEncode({
        'fetchedAt': now.toIso8601String(),
        'weeks': [for (final ScheduleWeek week in weeks) week.toJson()],
      }),
    );
  }
}
