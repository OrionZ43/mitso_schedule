import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const ScheduleApp(),
    ),
  );
}
