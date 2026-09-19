import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_platform.dart';
import '../state/mitso_providers.dart' show noRetry;
import 'models/lesson.dart';

/// Расписание для часов.
///
/// Телефон кладёт его в Data Layer (канал `mitso/wear` → `WearSync.kt`), а
/// часы забирают сами — им не нужны ни сеть, ни логин. Отправляются только
/// недели и название группы: время загрузки в JSON не попадает, чтобы
/// неизменившееся расписание не гонялось по Bluetooth заново.
class WearSync {
  const WearSync({this.channel = const MethodChannel('mitso/wear')});

  final MethodChannel channel;

  /// Часы, подключённые к телефону прямо сейчас. Пустой список — их нет,
  /// нет Play Services или платформа не та.
  Future<List<String>> connectedWatches() async {
    if (!AppPlatform.isPhone) return const <String>[];
    try {
      final List<Object?>? names = await channel.invokeMethod<List<Object?>>(
        'watches',
      );
      return <String>[
        for (final Object? name in names ?? const <Object?>[])
          if (name is String) name,
      ];
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException catch (error) {
      debugPrint('[Часы] ${error.code} ${error.message}');
      return const <String>[];
    }
  }

  /// Отправляет расписание; `false` — часов нет, платформа не та или
  /// отправить не удалось.
  Future<bool> push(String group, List<ScheduleWeek> weeks) async {
    if (!AppPlatform.isPhone) return false;
    final String payload = jsonEncode(<String, Object?>{
      'group': group,
      'weeks': [for (final ScheduleWeek week in weeks) week.toJson()],
    });
    try {
      return await channel.invokeMethod<bool>('sync', <String, String>{
            'payload': payload,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('[Часы] ${error.code} ${error.message}');
      return false;
    }
  }
}

final wearSyncProvider = Provider<WearSync>((ref) => const WearSync());

/// Подключённые часы — для раздела «Часы» в настройках.
final connectedWatchesProvider = FutureProvider<List<String>>(
  (ref) => ref.read(wearSyncProvider).connectedWatches(),
  retry: noRetry,
);
