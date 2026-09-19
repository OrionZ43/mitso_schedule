import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models/lesson.dart';

/// Одно запланированное напоминание.
@immutable
class LessonReminder {
  const LessonReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  /// Постоянный номер уведомления: по нему напоминание заменяется и
  /// отменяется.
  final int id;

  /// Когда показать.
  final DateTime when;

  /// Название предмета.
  final String title;

  /// «Через 15 минут · ауд. 62 (к)».
  final String body;

  @override
  bool operator ==(Object other) =>
      other is LessonReminder &&
      other.id == id &&
      other.when == when &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, when, title, body);

  @override
  String toString() => 'LessonReminder($id, $when, $title, $body)';
}

/// Планировщик напоминаний: система в приложении, запись в тестах.
abstract interface class LessonReminderPort {
  /// Заменяет все запланированные напоминания на [reminders].
  Future<void> replace(List<LessonReminder> reminders);

  /// Спрашивает разрешения (уведомления и точные будильники Android 12+).
  /// `false` — пользователь отказал, напоминания включать бессмысленно.
  Future<bool> requestPermission();
}

/// Сколько напоминаний держать запланированными.
///
/// Больше недели вперёд смысла нет: расписание на сайте меняется, а
/// приложение всё равно перепланирует при каждом обновлении.
const int kMaxLessonReminders = 32;

/// Первый номер уведомления: у уведомления о долге свой (1).
const int kReminderBaseId = 1000;

/// Что и когда напомнить.
///
/// Берутся пары, до начала которых ещё больше [before]: напоминание о паре,
/// которая вот-вот начнётся, приходило бы задним числом. Пары подгрупп в одно
/// время — одно напоминание: для студента это одна пара.
List<LessonReminder> planLessonReminders({
  required List<ScheduleDay> days,
  required Duration before,
  required DateTime now,
  int limit = kMaxLessonReminders,
}) {
  final List<LessonReminder> reminders = [];

  for (final ScheduleDay day in days) {
    for (final LessonSlot slot in day.slots()) {
      final DateTime start = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
      ).add(Duration(minutes: slot.startMinutes));
      final DateTime when = start.subtract(before);
      if (!when.isAfter(now)) continue;

      reminders.add(
        LessonReminder(
          id: kReminderBaseId + reminders.length,
          when: when,
          title: slot.commonTitle ?? 'Пары по подгруппам',
          body: _body(slot, before),
        ),
      );
    }
  }

  reminders.sort((a, b) => a.when.compareTo(b.when));
  final List<LessonReminder> limited = reminders.take(limit).toList();
  // Номера идут по порядку времени: так их проще отменять и заменять.
  return [
    for (int i = 0; i < limited.length; i++)
      LessonReminder(
        id: kReminderBaseId + i,
        when: limited[i].when,
        title: limited[i].title,
        body: limited[i].body,
      ),
  ];
}

/// «Через 15 минут · ауд. 62 (к)» или «Через 15 минут · 2423 УИР».
String _body(LessonSlot slot, Duration before) {
  final List<String> parts = [_beforeLabel(before)];

  final List<String> rooms = [
    for (final Lesson lesson in slot.lessons)
      if (lesson.room != null) lesson.room!,
  ];
  final List<String> groups = [
    for (final Lesson lesson in slot.lessons)
      if (lesson.group != null) lesson.group!,
  ];

  if (groups.isNotEmpty) {
    parts.add(groups.toSet().join(', '));
  }
  if (rooms.isNotEmpty) {
    parts.add(
      rooms.length == 1 ? 'ауд. ${rooms.first}' : 'ауд. ${rooms.join(', ')}',
    );
  }
  return parts.join(' · ');
}

/// «Через 15 минут», «Через час», «Через 1 ч 30 мин».
String _beforeLabel(Duration before) {
  final int minutes = before.inMinutes;
  if (minutes == 60) return 'Через час';
  if (minutes < 60) return 'Через $minutes мин';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? 'Через $hours ч' : 'Через $hours ч $rest мин';
}

/// Системные напоминания Android.
class SystemLessonReminders implements LessonReminderPort {
  const SystemLessonReminders();

  @override
  Future<void> replace(List<LessonReminder> reminders) =>
      LessonReminders.replace(reminders);

  @override
  Future<bool> requestPermission() => LessonReminders.requestPermission();
}

/// Напоминания о начале пары.
///
/// Уведомления планируются заранее и живут в системе: приложению не нужно
/// просыпаться в фоне. Время пар — минское: расписание на сайте в нём и
/// составлено, поэтому зона зафиксирована, а не берётся с телефона.
abstract final class LessonReminders {
  static const String channelId = 'lessons';
  static const String channelName = 'Пары';
  static const String channelDescription =
      'Напоминания о начале занятий по расписанию';

  /// Белый значок для статус-бара, как у уведомления о долге.
  static const String smallIcon = 'ic_stat_balance';

  /// Расписание МИТСО составлено по минскому времени.
  static const String timeZone = 'Europe/Minsk';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timeZone));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
      ),
    );
    _initialized = true;
  }

  /// Спрашивается только разрешение на уведомления (Android 13+). Точное
  /// время приложение получает при установке (`USE_EXACT_ALARM`), поэтому
  /// системный экран «Будильники и напоминания» пользователю не показывается.
  static Future<bool> requestPermission() async {
    await init();
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Планирует [reminders] вместо всех прежних.
  static Future<void> replace(List<LessonReminder> reminders) async {
    await init();
    for (
      int id = kReminderBaseId;
      id < kReminderBaseId + kMaxLessonReminders;
      id++
    ) {
      await _plugin.cancel(id: id);
    }
    if (reminders.isEmpty) return;

    // Точное время: пара начинается в своё время, а не «примерно». На
    // Android 13+ разрешение выдано при установке; на Android 12 его могли
    // отнять — тогда планируем неточно: напоминание придёт с опозданием в
    // несколько минут, но придёт. Попытка запланировать точно без разрешения
    // закончилась бы исключением и молчанием.
    final AndroidScheduleMode mode = await _canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (final LessonReminder reminder in reminders) {
      try {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.event,
            ),
          ),
          androidScheduleMode: mode,
        );
      } catch (error) {
        debugPrint('[Напоминания] Не удалось запланировать: $error');
      }
    }
  }

  /// Разрешены ли точные будильники. До Android 12 — всегда да.
  static Future<bool> _canScheduleExact() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? false;
  }
}
