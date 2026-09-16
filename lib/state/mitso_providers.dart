import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mitso/mitso_client.dart';
import '../data/models/group_ref.dart';
import 'settings_controller.dart';

/// Не повторять упавшие сетевые провайдеры автоматически.
///
/// Riverpod 3 по умолчанию перезапускает провайдер с ошибкой с нарастающей
/// паузой — для сайта МИТСО это лишняя нагрузка. Обновление только по
/// действию пользователя.
Duration? noRetry(int retryCount, Object error) => null;

/// Источник расписания. В тестах переопределяется подстановкой.
final mitsoApiProvider = FutureProvider<MitsoApi>((ref) async {
  final MitsoClient client = await MitsoClient.create();
  ref.onDispose(client.close);
  return client;
}, retry: noRetry);

/// Текущее время. В тестах — фиксированное.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// «Сейчас» для «Сейчас идёт» и остатка пары: обновляется раз в 30 секунд.
final nowProvider = NotifierProvider<NowController, DateTime>(
  NowController.new,
);

class NowController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime Function() clock = ref.watch(clockProvider);
    final Timer timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => state = clock(),
    );
    ref.onDispose(timer.cancel);
    return clock();
  }
}

/// Группа, чьё расписание показывается. `null` — ещё не выбрана.
final selectedGroupProvider =
    NotifierProvider<SelectedGroupController, GroupRef?>(
      SelectedGroupController.new,
    );

class SelectedGroupController extends Notifier<GroupRef?> {
  static const String _key = 'group.selected';

  @override
  GroupRef? build() {
    final String? raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return null;
    try {
      return GroupRef.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // Повреждённая запись — считаем, что группа не выбрана.
      return null;
    }
  }

  void select(GroupRef group) {
    state = group;
    ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(group.toJson()));
  }
}
