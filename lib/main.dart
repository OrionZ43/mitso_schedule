import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/balance_alerts.dart';
import 'data/balance_background.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Русские названия месяцев и дней недели для intl.
  await initializeDateFormatting('ru');

  // Фото справки из галереи — системный фотовыбор Android, а не файловый
  // менеджер.
  final ImagePickerPlatform picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Уведомление о долге и фоновая проверка баланса раз в шесть часов —
  // только на телефоне: плагины уведомлений и фоновых задач настольной
  // сборки не знают. Сбой плагина не должен мешать запуску: без уведомлений
  // приложение работает, а вот застрять на сплэше из-за них недопустимо.
  try {
    if (Platform.isAndroid) {
      await BalanceAlerts.init();
      await BalanceBackground.initialize();
      await BalanceBackground.sync(
        enabled:
            preferences.getBool(SettingsController.balanceAlertsKey) ?? true,
      );
    }
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'mitso_schedule',
        context: ErrorDescription('настройка уведомлений о балансе'),
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const ScheduleApp(),
    ),
  );
}
