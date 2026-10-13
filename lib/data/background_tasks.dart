import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'balance_background.dart';
import 'schedule_watch.dart';

/// Фоновые задачи приложения.
///
/// У `workmanager` одна точка входа на приложение, поэтому все задачи
/// разбираются по имени здесь: проверка расписания раз в три часа и проверка
/// лицевого счёта раз в шесть часов.
abstract final class BackgroundTasks {
  static Future<void> initialize() =>
      Workmanager().initialize(backgroundDispatcher);
}

/// Точка входа фонового изолята.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Фоновый изолят поднимается без плагинов: без этого `SharedPreferences`
    // и уведомления отвечают MissingPluginException, а задача молча падает.
    DartPluginRegistrant.ensureInitialized();

    switch (task) {
      case ScheduleWatch.taskName:
        return ScheduleWatch.check();
      case BalanceBackground.taskName:
        return BalanceBackground.check();
      default:
        debugPrint('[Фон] Неизвестная задача «$task»');
        return true;
    }
  });
}
