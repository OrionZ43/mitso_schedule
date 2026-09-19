import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Установку не запустить: нет разрешения, платформа не та или установщик
/// не открылся.
class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);

  /// Текст для пользователя.
  final String message;

  @override
  String toString() => 'UpdateInstallException: $message';
}

/// Чем ставится обновление на этой платформе.
enum UpdateInstallTarget {
  /// Системный установщик APK.
  android,

  /// Тихий установщик Inno Setup.
  windows,

  /// Приложение обновить само себя не может — остаётся страница релиза.
  manual,
}

/// Способ установки для этой сборки.
UpdateInstallTarget currentInstallTarget() {
  if (Platform.isAndroid) return UpdateInstallTarget.android;
  if (Platform.isWindows) return UpdateInstallTarget.windows;
  return UpdateInstallTarget.manual;
}

/// Установка скачанного файла: система в приложении, запись в тестах.
abstract interface class UpdateInstallPort {
  /// Умеет ли приложение поставить обновление само.
  bool get isSupported;

  /// Запускает установку [file]. Бросает [UpdateInstallException], если
  /// установщик не открылся.
  Future<void> install(File file);
}

/// Системная установка скачанного и проверенного файла.
///
/// Android — системный установщик APK через канал `mitso/updates`
///           (`MainActivity.kt`): APK отдаётся `FileProvider`, потому что
///           начиная с Android 7 `file://` в чужое приложение не передать.
///           Разрешение «установка неизвестных приложений» Android показывает
///           не диалогом, а страницей настроек — канал её открывает, а
///           пользователь возвращается и нажимает «Обновить» ещё раз.
/// Windows — тихий запуск установщика Inno Setup и выход из приложения:
///           установщик дождётся закрытия, заменит файлы и запустит новую
///           версию.
/// Остальные платформы — не поддерживаются, остаётся страница релиза.
class UpdateInstaller implements UpdateInstallPort {
  const UpdateInstaller({
    this.channel = const MethodChannel('mitso/updates'),
    this.target,
  });

  /// Канал к Android. В тестах подменяется.
  final MethodChannel channel;

  /// Способ установки; `null` — как на этой платформе. В тестах задаётся
  /// явно: тесты идут на настольной машине, а проверять нужно обе ветки.
  final UpdateInstallTarget? target;

  UpdateInstallTarget get _target => target ?? currentInstallTarget();

  @override
  bool get isSupported => _target != UpdateInstallTarget.manual;

  @override
  Future<void> install(File file) async => switch (_target) {
    UpdateInstallTarget.android => _installAndroid(file),
    UpdateInstallTarget.windows => _installWindows(file),
    UpdateInstallTarget.manual => throw const UpdateInstallException(
      'На этой платформе обновление ставится вручную',
    ),
  };

  Future<void> _installAndroid(File apk) async {
    try {
      final bool allowed =
          await channel.invokeMethod<bool>('canInstall') ?? false;
      if (!allowed) {
        await channel.invokeMethod<void>('requestInstallPermission');
        throw const UpdateInstallException(
          'Разрешите «Расписанию» устанавливать приложения и нажмите '
          '«Обновить» ещё раз',
        );
      }
      await channel.invokeMethod<void>('install', <String, String>{
        'path': apk.path,
      });
    } on PlatformException catch (error) {
      debugPrint('[Обновления] Установка: ${error.code} ${error.message}');
      throw const UpdateInstallException('Не удалось открыть установщик');
    } on MissingPluginException {
      throw const UpdateInstallException('Не удалось открыть установщик');
    }
  }

  Future<void> _installWindows(File setup) async {
    final String log = p.join(Directory.systemTemp.path, 'mitso-update.log');
    await Process.start(
      setup.path,
      windowsInstallerArguments(log),
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  /// Ключи Inno Setup: без окон и вопросов, без перезагрузки системы;
  /// `/update=1` — после замены файлов установщик снова запускает приложение.
  @visibleForTesting
  static List<String> windowsInstallerArguments(String logPath) => <String>[
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/update=1',
    '/LOG=$logPath',
  ];
}
