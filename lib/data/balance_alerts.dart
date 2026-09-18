import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models/student_account.dart';

/// Уведомления о долге: система в приложении, запись в тестах.
abstract interface class BalanceAlertPort {
  Future<void> showDebt(StudentAccount account);
  Future<void> cancel();
}

/// Системные уведомления Android.
class SystemBalanceAlerts implements BalanceAlertPort {
  const SystemBalanceAlerts();

  @override
  Future<void> showDebt(StudentAccount account) =>
      BalanceAlerts.showDebt(account);

  @override
  Future<void> cancel() => BalanceAlerts.cancel();
}

/// Уведомление о задолженности по лицевому счёту.
///
/// Канал уведомлений один, уведомление тоже одно (id постоянный): новое
/// заменяет предыдущее, а не копится в шторке.
abstract final class BalanceAlerts {
  static const int notificationId = 1;
  static const String channelId = 'balance';
  static const String channelName = 'Лицевой счёт';
  static const String channelDescription =
      'Сообщения о задолженности по лицевому счёту';

  /// Белый значок для статус-бара: цветной значок приложения Android
  /// превращает в белое пятно.
  static const String smallIcon = '@drawable/ic_stat_balance';

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

  /// Android 13+ спрашивает разрешение на уведомления.
  static Future<bool> requestPermission() async {
    await init();
    final bool? granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Сообщать о долге стоит, когда он появился или вырос: иначе уведомление
  /// повторялось бы при каждой проверке.
  static bool shouldNotify({
    StudentAccount? previous,
    required StudentAccount current,
  }) {
    if (!current.inDebt) return false;
    if (previous == null || !previous.inDebt) return true;
    return current.balance < previous.balance;
  }

  static Future<void> showDebt(StudentAccount account) async {
    await init();
    final String amount = account.balance
        .abs()
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    await _plugin.show(
      id: notificationId,
      title: 'Долг по лицевому счёту',
      body: account.balance < 0
          ? 'Баланс −$amount Br. Проверьте оплату в личном кабинете.'
          : 'Есть основной долг или пеня. Проверьте личный кабинет.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
        ),
      ),
    );
  }

  static Future<void> cancel() async {
    await init();
    await _plugin.cancel(id: notificationId);
  }
}
