import 'package:flutter/foundation.dart';

/// Чем платформа отличается для интерфейса.
///
/// Приложение собирается под Android и под Windows. На компьютере нет камеры
/// для фото справки, значок приложения не меняется, а уведомление о долге и
/// фоновая проверка счёта незачем: плагины под них телефонные.
///
/// В тестах `defaultTargetPlatform` — Android, поэтому телефонные ветки
/// проверяются как обычно; настольные проверяются с
/// `debugDefaultTargetPlatformOverride`.
abstract final class AppPlatform {
  static bool get isPhone => defaultTargetPlatform == TargetPlatform.android;

  static bool get isDesktop => !isPhone;
}
