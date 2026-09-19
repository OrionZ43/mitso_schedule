import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/features/updater/update_checker.dart';
import 'package:mitso_schedule/features/updater/update_envelope.dart';
import 'package:mitso_schedule/features/updater/update_keys.dart';
import 'package:mitso_schedule/features/updater/update_manifest.dart';

import 'support/fake_update_transport.dart';

const String _hash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  group('Манифест', () {
    test('разбирается целиком', () {
      final UpdateManifest manifest = UpdateManifest.fromJson(
        manifestJson(
          assets: <String, Object?>{
            'android-arm64-v8a': assetJson(
              url: 'https://example.org/app-arm64.apk',
              size: 1000,
              sha256: _hash.toUpperCase(),
            ),
          },
        ),
      );

      expect(manifest.version, '1.1.0');
      expect(manifest.build, 2);
      expect(manifest.notes, 'Что нового');
      expect(manifest.releaseUrl!.host, 'github.com');
      // Хэш всегда в нижнем регистре: с ним сравнивают посчитанный.
      expect(manifest.assets['android-arm64-v8a']!.sha256, _hash);
    });

    test('без номера сборки не принимается', () {
      final Map<String, Object?> json = manifestJson()..remove('build');
      expect(() => UpdateManifest.fromJson(json), throwsFormatException);
    });

    test('адрес файла только https', () {
      expect(
        () => UpdateManifest.fromJson(
          manifestJson(
            assets: <String, Object?>{
              'android-universal': assetJson(
                url: 'http://example.org/app.apk',
                size: 10,
                sha256: _hash,
              ),
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('размер и хэш проверяются', () {
      expect(
        () => UpdateAsset.fromJson(
          assetJson(
            url: 'https://example.org/app.apk',
            size: UpdateAsset.maxSize + 1,
            sha256: _hash,
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateAsset.fromJson(
          assetJson(
            url: 'https://example.org/app.apk',
            size: 10,
            sha256: 'не хэш',
          ),
        ),
        throwsFormatException,
      );
    });

    test('имя файла с сервера на диск не пускается как есть', () {
      UpdateAsset asset(String url) =>
          UpdateAsset.fromJson(assetJson(url: url, size: 10, sha256: _hash));

      expect(
        asset('https://example.org/r/app-arm64.apk').fileName,
        'app-arm64.apk',
      );
      // Разделители пути и переход вверх остаться не должны.
      expect(
        asset('https://example.org/%2e%2e%2fpasswd').fileName.contains('/'),
        isFalse,
      );
      expect(asset('https://example.org/').fileName, 'mitso-update.bin');
    });

    test('берётся первый подходящий файл', () {
      final UpdateManifest manifest = UpdateManifest.fromJson(
        manifestJson(
          assets: <String, Object?>{
            'android-universal': assetJson(
              url: 'https://example.org/universal.apk',
              size: 10,
              sha256: _hash,
            ),
          },
        ),
      );

      expect(
        manifest
            .assetFor(<String>['android-arm64-v8a', 'android-universal'])!
            .urls
            .first
            .path,
        '/universal.apk',
      );
      expect(manifest.assetFor(<String>['windows-x64']), isNull);
    });

    test('смещение versionCode по архитектуре снимается', () {
      // Так Flutter нумерует сборки при --split-per-abi: armeabi-v7a 1001,
      // arm64-v8a 2001, x86_64 4001 — это всё сборка 1 из pubspec.
      expect(normalizeBuildNumber(1), 1);
      expect(normalizeBuildNumber(1001), 1);
      expect(normalizeBuildNumber(2001), 1);
      expect(normalizeBuildNumber(4001), 1);
      expect(normalizeBuildNumber(2042), 42);
    });

    test('ключи файлов для каждой архитектуры знакомы манифесту', () {
      for (final Abi abi in <Abi>[
        Abi.androidArm64,
        Abi.androidArm,
        Abi.androidX64,
        Abi.windowsX64,
      ]) {
        expect(assetKeysFor(abi), isNotEmpty, reason: '$abi');
        expect(
          assetKeysFor(abi).every(kUpdateAssetKeys.contains),
          isTrue,
          reason: 'Опечатка в ключе файла для $abi',
        );
      }
      // Архитектур, которые приложение не собирает, в релизе нет.
      expect(assetKeysFor(Abi.linuxArm64), isEmpty);
    });
  });

  group('Подпись', () {
    late FakeRelease release;

    setUp(() async => release = await FakeRelease.create());

    test('свой манифест принимается', () async {
      final String envelope = await release.sign(manifestJson(build: 7));
      final UpdateManifest manifest = await UpdateEnvelope.verifyAndParse(
        envelope,
        release.trustedKeys,
      );
      expect(manifest.build, 7);
    });

    test('подменённый манифест не принимается', () async {
      final String envelope = await release.sign(manifestJson(build: 7));
      final Map<String, dynamic> json =
          jsonDecode(envelope) as Map<String, dynamic>;
      json['payload'] = base64Encode(
        utf8.encode(jsonEncode(manifestJson(build: 999))),
      );

      expect(
        () => UpdateEnvelope.verifyAndParse(
          jsonEncode(json),
          release.trustedKeys,
        ),
        throwsA(isA<UpdateSignatureException>()),
      );
    });

    test('чужой ключ не принимается', () async {
      final FakeRelease other = await FakeRelease.create();
      final String envelope = await other.sign(manifestJson());

      expect(
        () => UpdateEnvelope.verifyAndParse(envelope, release.trustedKeys),
        throwsA(isA<UpdateSignatureException>()),
      );
    });

    test('неизвестный kid не принимается', () async {
      final FakeRelease other = await FakeRelease.create(kid: 'другой');
      final String envelope = await other.sign(manifestJson());

      expect(
        () => UpdateEnvelope.verifyAndParse(envelope, release.trustedKeys),
        throwsA(isA<UpdateSignatureException>()),
      );
    });

    test('мусор вместо файла не принимается', () {
      expect(
        () => UpdateEnvelope.verifyAndParse(
          '<html>404</html>',
          <String, List<int>>{'test-key': List<int>.filled(32, 0)},
        ),
        throwsA(isA<UpdateSignatureException>()),
      );
    });

    test('ключи в приложении разбираются', () {
      // Пока карта пуста, обновления выключены — это допустимое состояние,
      // но каждая строка в ней обязана быть base64 от 32 байт.
      for (final MapEntry<String, List<int>> entry
          in decodeUpdateSigningKeys().entries) {
        expect(entry.value, hasLength(32), reason: entry.key);
      }
    });
  });
}
