import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Значок приложения в лаунчере.
///
/// Меняется включением одного `activity-alias` и выключением остальных
/// (`MainActivity.kt`, канал `mitso/app_icon`): другого способа поменять
/// иконку у Android нет. Лаунчер обновляет значок сам, обычно за пару секунд.
enum AppIcon {
  cookieCap('', 'Печенька и шапка', 'assets/app_icons/default.png'),
  cap('cap', 'Шапка', 'assets/app_icons/cap.png'),
  clock('clock', 'Печенька и часы', 'assets/app_icons/clock.png'),
  card('card', 'Карточка и шапка', 'assets/app_icons/card.png');

  const AppIcon(this.name, this.title, this.asset);

  /// Имя варианта в манифесте; у значка по умолчанию пусто.
  final String name;

  final String title;

  /// Образец для выбора в настройках.
  final String asset;

  static AppIcon byName(String? name) => AppIcon.values.firstWhere(
    (icon) => icon.name == name,
    orElse: () => AppIcon.cookieCap,
  );
}

/// Канал смены значка. В тестах подменяется.
final appIconChannelProvider = Provider<MethodChannel>(
  (ref) => const MethodChannel('mitso/app_icon'),
);

final appIconControllerProvider =
    AsyncNotifierProvider<AppIconController, AppIcon>(AppIconController.new);

class AppIconController extends AsyncNotifier<AppIcon> {
  MethodChannel get _channel => ref.read(appIconChannelProvider);

  @override
  Future<AppIcon> build() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AppIcon.cookieCap;
    }
    try {
      final String? name = await _channel.invokeMethod<String>('current');
      return AppIcon.byName(name);
    } on PlatformException {
      return AppIcon.cookieCap;
    } on MissingPluginException {
      return AppIcon.cookieCap;
    }
  }

  /// Включает значок [icon]; возвращает `false`, если система отказала.
  Future<bool> select(AppIcon icon) async {
    if (state.value == icon) return true;
    final AppIcon previous = state.value ?? AppIcon.cookieCap;
    state = AsyncValue<AppIcon>.data(icon);
    try {
      await _channel.invokeMethod<void>('select', {'name': icon.name});
      return true;
    } catch (_) {
      state = AsyncValue<AppIcon>.data(previous);
      return false;
    }
  }
}
