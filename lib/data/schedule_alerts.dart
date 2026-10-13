import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'schedule_diff.dart';

/// Уведомления о расписании: система в приложении, запись в тестах.
abstract interface class ScheduleAlertPort {
  /// Пары добавились, пропали или переехали.
  Future<void> showChanges(ScheduleDiff diff);

  /// Сайт опубликовал следующую неделю.
  Future<void> showNewWeek(ScheduleDiff diff);
}

/// Системные уведомления Android.
class SystemScheduleAlerts implements ScheduleAlertPort {
  const SystemScheduleAlerts();

  @override
  Future<void> showChanges(ScheduleDiff diff) =>
      ScheduleAlerts.showChanges(diff);

  @override
  Future<void> showNewWeek(ScheduleDiff diff) =>
      ScheduleAlerts.showNewWeek(diff);
}

/// Уведомления об изменениях в расписании.
///
/// Два постоянных номера: новое уведомление об изменениях заменяет прежнее, а
/// не копится в шторке. Канал отдельный от напоминаний о паре — изменения
/// приходят редко, и их можно отключить, не теряя напоминания.
abstract final class ScheduleAlerts {
  static const int changesId = 10;
  static const int newWeekId = 11;

  static const String channelId = 'schedule';
  static const String channelName = 'Расписание';
  static const String channelDescription =
      'Изменения в расписании и новая неделя';

  /// Белый значок для статус-бара — тот же, что у остальных уведомлений.
  static const String smallIcon = 'ic_stat_balance';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
      ),
    );
    _initialized = true;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.event,
    ),
  );

  static Future<void> showChanges(ScheduleDiff diff) async {
    if (diff.changes.isEmpty) return;
    await init();
    await _plugin.show(
      id: changesId,
      title: diff.changesTitle,
      body: diff.changesBody,
      notificationDetails: _details,
    );
  }

  static Future<void> showNewWeek(ScheduleDiff diff) async {
    if (!diff.hasNewWeek) return;
    await init();
    await _plugin.show(
      id: newWeekId,
      title: 'Расписание на ${diff.newWeekRange}',
      body: diff.newWeekSummary,
      notificationDetails: _details,
    );
  }
}
