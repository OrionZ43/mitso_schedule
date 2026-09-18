import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'balance_alerts.dart';
import 'mitso/student_client.dart';
import 'models/student_account.dart';

/// Фоновая проверка баланса.
///
/// Сайт пересчитывает счёт раз в сутки в 13:00, поэтому задача просыпается
/// раз в шесть часов и только при наличии сети: этого хватает, чтобы узнать о
/// долге в день его появления, и сайт не дёргается лишний раз.
abstract final class BalanceBackground {
  static const String taskId = 'mitso.balance.check';
  static const String taskName = 'balance-check';
  static const Duration frequency = Duration(hours: 6);

  /// Ключи `SharedPreferences` — те же, что у контроллера и настроек; в
  /// фоновом изоляте Riverpod недоступен.
  static const String numberKey = 'student.number';
  static const String cacheKey = 'student.cache';
  static const String alertsKey = 'settings.balanceAlerts';

  static Future<void> initialize() =>
      Workmanager().initialize(balanceCallbackDispatcher);

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

  /// Проверка счёта вне интерфейса: возвращает `false`, если не удалось и
  /// стоит повторить.
  static Future<bool> check() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String? number = prefs.getString(numberKey);
    if (number == null) return true;
    if (!(prefs.getBool(alertsKey) ?? true)) return true;

    StudentClient? client;
    try {
      client = await StudentClient.create();
      final StudentAccount account = await client.fetch(number);
      final StudentAccount? previous = _cached(prefs);
      await prefs.setString(cacheKey, jsonEncode(account.toJson()));
      if (BalanceAlerts.shouldNotify(previous: previous, current: account)) {
        await BalanceAlerts.showDebt(account);
      } else if (!account.inDebt) {
        // Долг закрыт — старое уведомление убираем.
        await BalanceAlerts.cancel();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      client?.close();
    }
  }

  static StudentAccount? _cached(SharedPreferences prefs) {
    final String? raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return StudentAccount.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }
}

/// Точка входа фонового изолята.
@pragma('vm:entry-point')
void balanceCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return BalanceBackground.check();
  });
}
