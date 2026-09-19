import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'update_envelope.dart';
import 'update_http.dart';
import 'update_keys.dart';
import 'update_manifest.dart';

/// Найденное обновление.
@immutable
class AvailableUpdate {
  const AvailableUpdate({
    required this.manifest,
    required this.asset,
    required this.isMandatory,
  });

  final UpdateManifest manifest;

  /// Файл для этого устройства; `null` — в релизе его нет, остаётся страница
  /// релиза ([UpdateManifest.releaseUrl]).
  final UpdateAsset? asset;

  /// Текущая сборка ниже `minSupportedBuild` — такое обновление нельзя
  /// отложить.
  final bool isMandatory;
}

/// Чем кончилась проверка обновлений.
enum UpdateCheckOutcome {
  /// Есть сборка новее.
  available,

  /// Опубликованная сборка не новее текущей.
  upToDate,

  /// Ни один адрес не ответил или подпись не сошлась: неизвестно, есть ли
  /// обновление.
  failed,

  /// Ключей подписи нет — проверка выключена.
  disabled,
}

/// Результат проверки: чем кончилась и что нашлось.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult(this.outcome, [this.update]);

  final UpdateCheckOutcome outcome;

  /// Заполнено только при [UpdateCheckOutcome.available].
  final AvailableUpdate? update;
}

/// Проверка обновлений: скачивает подписанный манифест, проверяет подпись,
/// сравнивает номер сборки и выбирает файл под это устройство.
class UpdateChecker {
  UpdateChecker({
    UpdateTransport? transport,
    List<Uri>? manifestUrls,
    Map<String, List<int>>? trustedKeys,
  }) : _transport = transport ?? IoUpdateTransport(),
       _manifestUrls = manifestUrls ?? defaultManifestUrls,
       _trustedKeys = trustedKeys ?? decodeUpdateSigningKeys();

  /// Где искать манифест.
  ///
  /// Сейчас только GitHub Releases: `latest/download/<имя файла>` всегда ведёт
  /// на последний релиз, и это обычная загрузка файла, а не API, поэтому лимит
  /// в 60 запросов в час не действует. Адрес может смениться — при переезде
  /// репозитория или появлении зеркала сюда добавляется ещё один адрес, они
  /// перебираются по порядку. Старые сборки приложения останутся на этом
  /// адресе, так что переезд лучше готовить заранее.
  static final List<Uri> defaultManifestUrls = <Uri>[
    Uri.parse(
      'https://github.com/OrionZ43/mitso_schedule/releases/latest/download/'
      '${UpdateEnvelope.fileName}',
    ),
  ];

  final UpdateTransport _transport;
  final List<Uri> _manifestUrls;
  final Map<String, List<int>> _trustedKeys;

  /// Есть ли чем проверять подпись. Пустая карта ключей в `update_keys.dart`
  /// означает «обновления выключены»: в сеть не ходим вовсе.
  bool get isEnabled => _trustedKeys.isNotEmpty;

  /// Обновление или `null`: новее нет, сети нет, подпись не сошлась. Ошибки
  /// наружу не бросает — только пишет в лог. Чем именно кончилась проверка,
  /// говорит [checkDetailed].
  Future<AvailableUpdate?> check({
    required int currentBuild,
    required List<String> assetKeys,
  }) async => (await checkDetailed(
    currentBuild: currentBuild,
    assetKeys: assetKeys,
  )).update;

  /// То же, что [check], но отличает «новее нет» от «проверить не удалось»:
  /// экрану нельзя писать «установлена последняя версия», когда нет сети.
  /// Берётся первый ответивший адрес; ошибки только пишутся в лог.
  Future<UpdateCheckResult> checkDetailed({
    required int currentBuild,
    required List<String> assetKeys,
  }) async {
    if (!isEnabled) {
      debugPrint(
        '[Обновления] Ключ подписи не задан (update_keys.dart) — '
        'проверка обновлений выключена',
      );
      return const UpdateCheckResult(UpdateCheckOutcome.disabled);
    }

    for (final Uri url in _manifestUrls) {
      try {
        final String envelope = await _transport.fetchText(url);
        final UpdateManifest manifest = await UpdateEnvelope.verifyAndParse(
          envelope,
          _trustedKeys,
        );
        if (manifest.build <= currentBuild) {
          return const UpdateCheckResult(UpdateCheckOutcome.upToDate);
        }
        return UpdateCheckResult(
          UpdateCheckOutcome.available,
          AvailableUpdate(
            manifest: manifest,
            asset: manifest.assetFor(assetKeys),
            isMandatory: currentBuild < manifest.minSupportedBuild,
          ),
        );
      } catch (error) {
        debugPrint(
          '[Обновления] Не удалось проверить обновления ($url): $error',
        );
      }
    }
    return const UpdateCheckResult(UpdateCheckOutcome.failed);
  }

  /// Закрывает соединения. Вызывается, когда провайдер уходит.
  void close() => _transport.close();
}

/// Ключи файлов для сборки под архитектуру [abi] в порядке предпочтения:
/// сначала свой APK, потом универсальный — он ставится куда угодно, но весит
/// вдвое больше.
///
/// Архитектуру берём не у устройства, а у самой сборки (`Abi.current()`): на
/// arm64-телефоне может стоять 32-разрядная копия приложения, и обновлять её
/// нужно такой же. Заодно не нужен плагин ради одного поля.
List<String> assetKeysFor(Abi abi) => switch (abi) {
  Abi.androidArm64 => const <String>['android-arm64-v8a', 'android-universal'],
  Abi.androidArm => const <String>['android-armeabi-v7a', 'android-universal'],
  Abi.androidX64 => const <String>['android-x86_64', 'android-universal'],
  Abi.windowsX64 => const <String>['windows-x64'],
  // Остальные архитектуры приложение не собирает — обновление ставится
  // вручную со страницы релиза.
  _ => const <String>[],
};

/// Ключи файлов для этой сборки.
List<String> currentAssetKeys() => assetKeysFor(Abi.current());

/// Номер сборки (`+N` из pubspec). На Windows `package_info_plus` берёт его из
/// ProductVersion exe.
Future<int> currentBuildNumber() async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return int.tryParse(info.buildNumber) ?? 0;
}
