import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/features/updater/update_checker.dart';
import 'package:mitso_schedule/features/updater/update_downloader.dart';
import 'package:mitso_schedule/features/updater/update_installer.dart';
import 'package:mitso_schedule/features/updater/update_provider.dart';

import 'support/fake_update_transport.dart';

final Uri _manifestUrl = Uri.parse('https://example.org/mitso-update.json');
final Uri _apkUrl = Uri.parse('https://example.org/app-arm64.apk');
final List<int> _apk = List<int>.generate(512, (int i) => i % 251);

void main() {
  late FakeRelease release;
  late FakeUpdateTransport transport;
  late FakeInstaller installer;
  late Directory directory;

  setUp(() async {
    release = await FakeRelease.create();
    transport = FakeUpdateTransport(<Uri, List<int>>{_apkUrl: _apk});
    installer = FakeInstaller();
    directory = await Directory.systemTemp.createTemp('mitso-update-state');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  /// Публикует релиз: подписанный манифест на своём адресе.
  Future<void> publish({
    int build = 5,
    int minSupported = 0,
    bool withAsset = true,
  }) async {
    transport.files[_manifestUrl] = utf8.encode(
      await release.sign(
        manifestJson(
          build: build,
          minSupportedBuild: minSupported,
          assets: withAsset
              ? <String, Object?>{
                  'android-arm64-v8a': assetJson(
                    url: '$_apkUrl',
                    size: _apk.length,
                    sha256: sha256.convert(_apk).toString(),
                  ),
                }
              : <String, Object?>{},
        ),
      ),
    );
  }

  ProviderContainer containerWith({
    Map<String, List<int>>? keys,
    int currentBuild = 1,
  }) => ProviderContainer.test(
    overrides: [
      updateCheckerProvider.overrideWith(
        (Ref ref) => UpdateChecker(
          transport: transport,
          manifestUrls: <Uri>[_manifestUrl],
          trustedKeys: keys ?? release.trustedKeys,
        ),
      ),
      updateTargetProvider.overrideWith(
        (Ref ref) async => UpdateTarget(
          build: currentBuild,
          assetKeys: const <String>['android-arm64-v8a', 'android-universal'],
        ),
      ),
      updateDownloaderProvider.overrideWith(
        (Ref ref) async =>
            UpdateDownloader(directory: directory, transport: transport),
      ),
      updateInstallerProvider.overrideWith((Ref ref) => installer),
    ],
  );

  /// Подписывается на состояние и ждёт, пока проверка закончится.
  Future<ProviderSubscription<UpdateState>> start(
    ProviderContainer container,
  ) async {
    final ProviderSubscription<UpdateState> subscription = container.listen(
      updateControllerProvider,
      (UpdateState? previous, UpdateState next) {},
    );
    await pumpEventQueue();
    return subscription;
  }

  UpdateController controller(ProviderContainer container) =>
      container.read(updateControllerProvider.notifier);

  test('при первом обращении проверяет и показывает обновление', () async {
    await publish(build: 5);
    final ProviderContainer container = containerWith();

    final ProviderSubscription<UpdateState> state = await start(container);

    expect(state.read().checking, isFalse);
    expect(state.read().outcome, UpdateCheckOutcome.available);
    expect(state.read().update!.manifest.version, '1.1.0');
    expect(state.read().isVisible, isTrue);
    expect(state.read().hasFile, isTrue);
  });

  test('без ключей подписи ничего не проверяется', () async {
    await publish();
    final ProviderContainer container = containerWith(
      keys: const <String, List<int>>{},
    );

    final ProviderSubscription<UpdateState> state = await start(container);

    expect(state.read().outcome, UpdateCheckOutcome.disabled);
    expect(transport.requests, isEmpty);
  });

  test('«Позже» прячет обновление, обязательное не прячется', () async {
    await publish(build: 5);
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    controller(container).dismiss();
    expect(state.read().isVisible, isFalse);

    // Обязательное обновление: текущая сборка ниже minSupportedBuild.
    await publish(build: 6, minSupported: 6);
    await controller(container).checkNow();
    await pumpEventQueue();
    controller(container).dismiss();

    expect(state.read().update!.isMandatory, isTrue);
    expect(state.read().isVisible, isTrue);
  });

  test('скачивает файл и отдаёт его установщику', () async {
    await publish(build: 5);
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    await controller(container).downloadAndInstall();

    expect(installer.installed, hasLength(1));
    expect(await installer.installed.single.readAsBytes(), _apk);
    // Установщик открыт — предлагаем нажать ещё раз, если его закрыли.
    expect(state.read().phase, UpdatePhase.available);
    expect(state.read().error, isNull);
  });

  test('прогрессом дёргает экран не чаще, чем на процент', () async {
    await publish(build: 5);
    transport.chunkSize = 1;
    final ProviderContainer container = containerWith();
    await start(container);

    final List<double> shown = <double>[];
    container.listen(updateControllerProvider, (
      UpdateState? previous,
      UpdateState next,
    ) {
      if (next.phase == UpdatePhase.downloading) shown.add(next.progress);
    });
    await controller(container).downloadAndInstall();

    // 512 кусков по байту — но экран перерисовывается около ста раз.
    expect(shown.length, lessThanOrEqualTo(101));
    expect(shown, isNotEmpty);
  });

  test('отказ установщика показывается словами', () async {
    await publish(build: 5);
    installer.error = const UpdateInstallException('Разрешите установку');
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    await controller(container).downloadAndInstall();

    expect(state.read().phase, UpdatePhase.failed);
    expect(state.read().error, 'Разрешите установку');
  });

  test('сорвавшаяся загрузка не выглядит как успех', () async {
    await publish(build: 5);
    transport.broken.add(_apkUrl);
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    await controller(container).downloadAndInstall();

    expect(state.read().phase, UpdatePhase.failed);
    expect(state.read().error, 'Не удалось скачать обновление');
    expect(installer.installed, isEmpty);
  });

  test('отмена возвращает к предложению обновиться', () async {
    await publish(build: 5);
    transport.chunkSize = 1;
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    final Future<void> download = controller(container).downloadAndInstall();
    await pumpEventQueue(times: 3);
    expect(state.read().phase, UpdatePhase.downloading);
    controller(container).cancelDownload();
    await download;

    expect(state.read().phase, UpdatePhase.available);
    expect(state.read().progress, 0);
    expect(installer.installed, isEmpty);
  });

  test('пропавшая сеть не стирает найденное обновление', () async {
    await publish(build: 5);
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    transport.broken.add(_manifestUrl);
    await controller(container).checkNow();

    expect(state.read().outcome, UpdateCheckOutcome.failed);
    expect(state.read().update, isNotNull);
    expect(state.read().checking, isFalse);
  });

  test('релиз без файла под устройство оставляет страницу релиза', () async {
    await publish(build: 5, withAsset: false);
    final ProviderContainer container = containerWith();
    final ProviderSubscription<UpdateState> state = await start(container);

    expect(state.read().isVisible, isTrue);
    expect(state.read().hasFile, isFalse);
    expect(state.read().update!.manifest.releaseUrl, isNotNull);

    // Качать нечего — кнопка «Обновить» ничего не делает.
    await controller(container).downloadAndInstall();
    expect(installer.installed, isEmpty);
    expect(state.read().phase, UpdatePhase.available);
  });
}
