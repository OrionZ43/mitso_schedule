import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_platform.dart';

/// Окно настольной сборки: канал `mitso/window` в `flutter_window.cpp`.
///
/// На телефоне канала нет — все вызовы там молча ничего не делают.
class AppWindow {
  const AppWindow({this.channel = const MethodChannel('mitso/window')});

  final MethodChannel channel;

  /// Компактный режим: окно без рамки поверх других окон, в правом нижнем
  /// углу экрана.
  Future<void> setCompact(bool compact) => _call('setCompact', compact);

  /// Тянуть окно за содержимое: заголовка у компактного окна нет.
  Future<void> startDrag() => _call('startDrag');

  /// Закрыть приложение — системной кнопки закрытия у компактного окна тоже
  /// нет.
  Future<void> close() => _call('close');

  /// Запускается ли приложение вместе с Windows.
  Future<bool> autostart() async =>
      await _call<bool>('autostart').then((bool? value) => value ?? false);

  Future<void> setAutostart(bool enabled) => _call('setAutostart', enabled);

  Future<T?> _call<T>(String method, [Object? argument]) async {
    if (AppPlatform.isPhone) return null;
    try {
      return await channel.invokeMethod<T>(method, argument);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('[Окно] $method: ${error.code} ${error.message}');
      return null;
    }
  }
}

final appWindowProvider = Provider<AppWindow>((ref) => const AppWindow());

/// Запущено ли приложение сразу компактным — ключ `--widget` в автозапуске.
/// Подменяется в `main()`.
final startCompactProvider = Provider<bool>((ref) => false);

/// Компактный режим включён.
final widgetModeProvider = NotifierProvider<WidgetModeController, bool>(
  WidgetModeController.new,
);

class WidgetModeController extends Notifier<bool> {
  @override
  bool build() {
    final bool compact =
        ref.read(startCompactProvider) && AppPlatform.isDesktop;
    if (compact) {
      // Окно создаётся обычным и ужимается, когда Flutter уже жив.
      Future<void>(() => ref.read(appWindowProvider).setCompact(true));
    }
    return compact;
  }

  Future<void> set(bool compact) async {
    if (state == compact) return;
    state = compact;
    await ref.read(appWindowProvider).setCompact(compact);
  }

  Future<void> toggle() => set(!state);
}

/// Автозапуск вместе с Windows. `false` на телефоне и когда канал молчит.
final autostartProvider = AsyncNotifierProvider<AutostartController, bool>(
  AutostartController.new,
);

class AutostartController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(appWindowProvider).autostart();

  Future<void> set(bool enabled) async {
    state = AsyncValue<bool>.data(enabled);
    await ref.read(appWindowProvider).setAutostart(enabled);
  }
}
