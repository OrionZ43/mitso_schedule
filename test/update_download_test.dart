import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/features/updater/update_checker.dart';
import 'package:mitso_schedule/features/updater/update_downloader.dart';
import 'package:mitso_schedule/features/updater/update_http.dart';
import 'package:mitso_schedule/features/updater/update_installer.dart';
import 'package:mitso_schedule/features/updater/update_manifest.dart';

import 'support/fake_update_transport.dart';

final Uri _manifestUrl = Uri.parse('https://example.org/mitso-update.json');
final Uri _apkUrl = Uri.parse('https://example.org/app-arm64.apk');

/// Файл релиза: 512 байт, как настоящий APK — только меньше.
final List<int> _apk = List<int>.generate(512, (int i) => i % 251);
final String _apkHash = sha256.convert(_apk).toString();

Map<String, Object?> _releaseManifest({int build = 2, int minSupported = 0}) =>
    manifestJson(
      build: build,
      minSupportedBuild: minSupported,
      assets: <String, Object?>{
        'android-arm64-v8a': assetJson(
          url: '$_apkUrl',
          size: _apk.length,
          sha256: _apkHash,
        ),
      },
    );

UpdateAsset _asset() =>
    UpdateManifest.fromJson(_releaseManifest()).assets['android-arm64-v8a']!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Проверка обновлений', () {
    late FakeRelease release;
    late FakeUpdateTransport transport;

    setUp(() async {
      release = await FakeRelease.create();
      transport = FakeUpdateTransport();
    });

    Future<void> publish(Map<String, Object?> manifest) async =>
        transport.files[_manifestUrl] = utf8.encode(
          await release.sign(manifest),
        );

    UpdateChecker checker({Map<String, List<int>>? keys, List<Uri>? urls}) =>
        UpdateChecker(
          transport: transport,
          manifestUrls: urls ?? <Uri>[_manifestUrl],
          trustedKeys: keys ?? release.trustedKeys,
        );

    Future<UpdateCheckResult> check(UpdateChecker c, {int currentBuild = 1}) =>
        c.checkDetailed(
          currentBuild: currentBuild,
          assetKeys: <String>['android-arm64-v8a', 'android-universal'],
        );

    test('без ключей подписи в сеть не ходит', () async {
      final UpdateCheckResult result = await check(
        checker(keys: const <String, List<int>>{}),
      );

      expect(result.outcome, UpdateCheckOutcome.disabled);
      expect(transport.requests, isEmpty);
    });

    test('находит сборку новее и файл под устройство', () async {
      await publish(_releaseManifest(build: 5));

      final UpdateCheckResult result = await check(checker());

      expect(result.outcome, UpdateCheckOutcome.available);
      expect(result.update!.manifest.build, 5);
      expect(result.update!.asset!.urls.first, _apkUrl);
      expect(result.update!.isMandatory, isFalse);
    });

    test('сборка не новее — обновления нет', () async {
      await publish(_releaseManifest(build: 3));

      expect(
        (await check(checker(), currentBuild: 3)).outcome,
        UpdateCheckOutcome.upToDate,
      );
    });

    test('сборка ниже minSupportedBuild — обновление обязательное', () async {
      await publish(_releaseManifest(build: 5, minSupported: 4));

      final UpdateCheckResult result = await check(checker(), currentBuild: 3);

      expect(result.update!.isMandatory, isTrue);
    });

    test('упавший адрес — берётся следующий', () async {
      final Uri mirror = Uri.parse('https://mirror.example.org/update.json');
      await publish(_releaseManifest(build: 5));
      transport.files[mirror] = transport.files[_manifestUrl]!;
      transport.broken.add(_manifestUrl);

      final UpdateCheckResult result = await check(
        checker(urls: <Uri>[_manifestUrl, mirror]),
      );

      expect(result.outcome, UpdateCheckOutcome.available);
      expect(transport.requests, <Uri>[_manifestUrl, mirror]);
    });

    test('сети нет — это не «установлена последняя версия»', () async {
      await publish(_releaseManifest(build: 5));
      transport.broken.add(_manifestUrl);

      expect((await check(checker())).outcome, UpdateCheckOutcome.failed);
    });

    test('чужая подпись — обновления нет', () async {
      final FakeRelease other = await FakeRelease.create();
      transport.files[_manifestUrl] = utf8.encode(
        await other.sign(_releaseManifest(build: 5)),
      );

      expect((await check(checker())).outcome, UpdateCheckOutcome.failed);
    });
  });

  group('Загрузка', () {
    late Directory directory;
    late FakeUpdateTransport transport;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('mitso-update-test');
      transport = FakeUpdateTransport(<Uri, List<int>>{_apkUrl: _apk});
    });

    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    UpdateDownloader downloader() =>
        UpdateDownloader(directory: directory, transport: transport);

    /// Имя недокачанного куска — как его назовёт загрузчик.
    File part(UpdateAsset asset) => File(
      '${directory.path}/${asset.fileName}.${asset.sha256.substring(0, 12)}.part',
    );

    test('качает файл и сверяет хэш', () async {
      final List<double> progress = <double>[];
      final File file = await downloader().download(
        _asset(),
        onProgress: progress.add,
      );

      expect(await file.readAsBytes(), _apk);
      expect(file.path, endsWith('app-arm64.apk'));
      expect(progress.last, 1);
      expect(progress, isNot(contains(greaterThan(1))));
    });

    test('уже скачанное не качается заново', () async {
      final UpdateAsset asset = _asset();
      await downloader().download(asset);
      transport.requests.clear();

      await downloader().download(asset);

      expect(transport.requests, isEmpty);
    });

    test('оборванная загрузка продолжается с места обрыва', () async {
      final UpdateAsset asset = _asset();
      transport.cutAfter = 128;
      await expectLater(
        downloader().download(asset),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(await part(asset).length(), 128);

      transport.cutAfter = null;
      transport.offsets.clear();
      final File file = await downloader().download(asset);

      expect(transport.offsets, <int>[128]);
      expect(await file.readAsBytes(), _apk);
    });

    test('сервер без поддержки Range — файл качается заново', () async {
      final UpdateAsset asset = _asset();
      transport
        ..cutAfter = 128
        ..supportsRange = false;
      await expectLater(
        downloader().download(asset),
        throwsA(isA<UpdateDownloadException>()),
      );

      transport.cutAfter = null;
      final File file = await downloader().download(asset);

      expect(await file.readAsBytes(), _apk);
    });

    test('кусок от прошлой версии не мешает', () async {
      final UpdateAsset asset = _asset();
      // Загрузка, брошенная на прошлой версии: имя файла в релизах одно и то
      // же, помечен кусок хэшем.
      final File stale = File('${directory.path}/${asset.fileName}.part');
      await stale.writeAsBytes(List<int>.filled(64, 7));

      final File file = await downloader().download(asset);

      expect(await file.readAsBytes(), _apk);
      expect(stale.existsSync(), isFalse);
    });

    test('подменённый файл не сохраняется', () async {
      transport.files[_apkUrl] = List<int>.filled(_apk.length, 0);

      await expectLater(
        downloader().download(_asset()),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(directory.listSync(), isEmpty);
    });

    test('лишние байты сверх манифеста не принимаются', () async {
      transport.files[_apkUrl] = <int>[..._apk, ..._apk];

      await expectLater(
        downloader().download(_asset()),
        throwsA(isA<UpdateDownloadException>()),
      );
    });

    test('отмена прерывает загрузку и оставляет кусок', () async {
      final UpdateAsset asset = _asset();
      final UpdateCancelToken cancelToken = UpdateCancelToken();
      transport.chunkSize = 32;

      await expectLater(
        downloader().download(
          asset,
          cancelToken: cancelToken,
          onProgress: (double value) {
            if (value >= 0.5) cancelToken.cancel();
          },
        ),
        throwsA(isA<UpdateCancelled>()),
      );

      expect(await part(asset).length(), greaterThan(0));
    });
  });

  group('Установка', () {
    const MethodChannel channel = MethodChannel('mitso/updates');
    late List<MethodCall> calls;
    late bool canInstall;

    setUp(() {
      calls = <MethodCall>[];
      canInstall = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return call.method == 'canInstall' ? canInstall : null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    File apk() => File('${Directory.systemTemp.path}/app.apk');

    test('Android: открывает системный установщик', () async {
      await const UpdateInstaller(
        target: UpdateInstallTarget.android,
      ).install(apk());

      expect(calls.map((MethodCall c) => c.method), <String>[
        'canInstall',
        'install',
      ]);
      expect(calls.last.arguments, <String, String>{'path': apk().path});
    });

    test('Android: без разрешения открывает настройки и объясняет', () async {
      canInstall = false;

      await expectLater(
        const UpdateInstaller(
          target: UpdateInstallTarget.android,
        ).install(apk()),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException e) => e.message,
            'message',
            contains('Разрешите'),
          ),
        ),
      );
      expect(calls.map((MethodCall c) => c.method), <String>[
        'canInstall',
        'requestInstallPermission',
      ]);
    });

    test('Windows: установщик запускается тихо и перезапускает приложение', () {
      final List<String> arguments = UpdateInstaller.windowsInstallerArguments(
        r'C:\Temp\mitso-update.log',
      );

      expect(arguments, contains('/VERYSILENT'));
      expect(arguments, contains('/update=1'));
      expect(arguments, contains(r'/LOG=C:\Temp\mitso-update.log'));
    });

    test('на прочих платформах приложение себя не ставит', () async {
      const UpdateInstaller installer = UpdateInstaller(
        target: UpdateInstallTarget.manual,
      );

      expect(installer.isSupported, isFalse);
      await expectLater(
        installer.install(apk()),
        throwsA(isA<UpdateInstallException>()),
      );
    });
  });
}
