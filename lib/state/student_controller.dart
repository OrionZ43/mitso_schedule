import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/balance_alerts.dart';
import '../data/mitso/student_client.dart';
import '../data/models/student_account.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Уведомления о долге. В тестах переопределяются подстановкой.
final balanceAlertsProvider = Provider<BalanceAlertPort>(
  (ref) => const SystemBalanceAlerts(),
);

/// Источник лицевого счёта. В тестах переопределяется подстановкой.
final studentApiProvider = FutureProvider<StudentApi>((ref) async {
  final StudentClient client = await StudentClient.create();
  ref.onDispose(client.close);
  return client;
}, retry: noRetry);

/// Подключён ли лицевой счёт.
final studentLinkedProvider = Provider<bool>(
  (ref) => ref.watch(studentControllerProvider).value != null,
);

/// Лицевой счёт студента: `null` — не подключён.
final studentControllerProvider =
    AsyncNotifierProvider<StudentController, StudentAccount?>(
      StudentController.new,
      retry: noRetry,
    );

class StudentController extends AsyncNotifier<StudentAccount?> {
  static const String numberKey = 'student.number';
  static const String cacheKey = 'student.cache';

  /// Сайт пересчитывает счёт раз в сутки в 13:00 — чаще спрашивать нечего.
  static const int updateHour = 13;

  @override
  Future<StudentAccount?> build() async {
    final String? number = _prefs.getString(numberKey);
    if (number == null) return null;

    final StudentAccount? cached = readCache();
    if (cached != null) {
      // Сохранённое показываем сразу, свежее подтягиваем в фоне.
      if (isStale(cached, ref.read(clockProvider)())) Future<void>(refresh);
      return cached;
    }
    return _fetch(number);
  }

  /// Данные устарели, если их получили до последнего обновления сайта.
  static bool isStale(StudentAccount account, DateTime now) =>
      account.fetchedAt.isBefore(lastSiteUpdate(now));

  /// Ближайшие прошедшие 13:00.
  static DateTime lastSiteUpdate(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day, updateHour);
    return now.isBefore(today)
        ? today.subtract(const Duration(days: 1))
        : today;
  }

  /// Подключает счёт [number]: проверяет его на сайте и запоминает.
  Future<void> link(String number) async {
    state = const AsyncValue<StudentAccount?>.loading();
    state = await AsyncValue.guard(() async {
      final StudentAccount account = await _fetch(number);
      await _prefs.setString(numberKey, number);
      return account;
    });
  }

  /// Обновляет счёт, если данные старее последнего обновления сайта:
  /// вызывается при возвращении в приложение.
  Future<void> refreshIfStale() async {
    final StudentAccount? account = state.value;
    if (account == null) return;
    if (!isStale(account, ref.read(clockProvider)())) return;
    try {
      await refresh();
    } catch (_) {
      // Молча: экран показывает сохранённые данные.
    }
  }

  /// Перезапрашивает счёт. Ошибку показывает экран, сохранённое остаётся.
  Future<void> refresh() async {
    final String? number = _prefs.getString(numberKey) ?? state.value?.number;
    if (number == null) return;
    try {
      final StudentAccount account = await _fetch(number);
      state = AsyncValue<StudentAccount?>.data(account);
    } catch (error, stack) {
      if (state.value == null) {
        state = AsyncValue<StudentAccount?>.error(error, stack);
      } else {
        // Сохранённые данные остаются на экране, ошибку отдаём наверх.
        rethrow;
      }
    }
  }

  /// Отключает счёт и стирает сохранённые данные, включая доступ к СДО.
  Future<void> unlink() async {
    await _prefs.remove(numberKey);
    await _prefs.remove(cacheKey);
    state = const AsyncValue<StudentAccount?>.data(null);
  }

  /// Последние сохранённые данные счёта.
  StudentAccount? readCache() {
    final String? raw = _prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return StudentAccount.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<StudentAccount> _fetch(String number) async {
    final StudentApi api = await ref.read(studentApiProvider.future);
    final StudentAccount account = await api.fetch(number);
    await _prefs.setString(cacheKey, jsonEncode(account.toJson()));
    await _alert(previous: state.value, current: account);
    return account;
  }

  /// Долг появился или вырос — уведомление; долг закрыт — старое убираем.
  Future<void> _alert({
    StudentAccount? previous,
    required StudentAccount current,
  }) async {
    if (!ref.read(settingsControllerProvider).balanceAlerts) return;
    final BalanceAlertPort alerts = ref.read(balanceAlertsProvider);
    if (BalanceAlerts.shouldNotify(previous: previous, current: current)) {
      await alerts.showDebt(current);
    } else if (!current.inDebt) {
      await alerts.cancel();
    }
  }
}
