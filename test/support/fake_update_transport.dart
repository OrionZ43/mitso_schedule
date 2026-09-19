import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:mitso_schedule/features/updater/update_envelope.dart';
import 'package:mitso_schedule/features/updater/update_http.dart';
import 'package:mitso_schedule/features/updater/update_downloader.dart';
import 'package:mitso_schedule/features/updater/update_installer.dart';
import 'package:mitso_schedule/features/updater/update_manifest.dart';

/// Сеть обновлений в тестах: отдаёт заранее заданные байты по адресу.
///
/// Умеет всё, что важно загрузчику: раздавать файл кусками, продолжать с
/// места обрыва, обрывать поток посреди файла и падать на выбранных адресах.
class FakeUpdateTransport implements UpdateTransport {
  FakeUpdateTransport([Map<Uri, List<int>>? files])
    : files = <Uri, List<int>>{...?files};

  /// Адрес → содержимое файла.
  final Map<Uri, List<int>> files;

  /// Все запрошенные адреса по порядку.
  final List<Uri> requests = <Uri>[];

  /// Смещения, с которых просили продолжить.
  final List<int> offsets = <int>[];

  /// Адреса, на которых сеть «падает».
  final Set<Uri> broken = <Uri>{};

  /// Сколько байт отдавать одним куском.
  int chunkSize = 16;

  /// Продолжает ли сервер с запрошенного места. `false` — отдаёт файл
  /// целиком, как GitHub без поддержки Range.
  bool supportsRange = true;

  /// Оборвать поток, отдав столько байт; `null` — отдавать до конца.
  int? cutAfter;

  bool closed = false;

  @override
  Future<String> fetchText(Uri url) async {
    requests.add(url);
    if (broken.contains(url)) throw const SocketExceptionLike();
    final List<int>? body = files[url];
    if (body == null) throw UpdateHttpException(url, 404);
    return utf8.decode(body);
  }

  @override
  Future<UpdateStream> openStream(Uri url, {int offset = 0}) async {
    requests.add(url);
    offsets.add(offset);
    if (broken.contains(url)) throw const SocketExceptionLike();
    final List<int>? body = files[url];
    if (body == null) throw UpdateHttpException(url, 404);

    final bool resumed = supportsRange && offset > 0;
    final List<int> tail = resumed ? body.sublist(offset) : body;
    return UpdateStream(resumed: resumed, bytes: _chunks(tail));
  }

  Stream<List<int>> _chunks(List<int> body) async* {
    int sent = 0;
    for (int i = 0; i < body.length; i += chunkSize) {
      final List<int> chunk = body.sublist(
        i,
        (i + chunkSize).clamp(0, body.length),
      );
      yield chunk;
      sent += chunk.length;
      if (cutAfter != null && sent >= cutAfter!) return;
    }
  }

  @override
  void close() => closed = true;
}

/// Сбой сети: настоящий `SocketException` тесту ни к чему, важен сам факт.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();

  @override
  String toString() => 'Сети нет';
}

/// Выпуск релиза в тестах: держит пару ключей и подписывает манифесты, как
/// `tool/update_signing.dart`.
class FakeRelease {
  FakeRelease._(this.kid, this._keyPair, this.publicKey);

  static Future<FakeRelease> create({String kid = 'test-key'}) async {
    final SimpleKeyPair keyPair = await Ed25519().newKeyPair();
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();
    return FakeRelease._(kid, keyPair, publicKey);
  }

  final String kid;
  final SimpleKeyPair _keyPair;
  final SimplePublicKey publicKey;

  /// Ключи для [UpdateEnvelope.verifyAndParse] и [UpdateChecker].
  Map<String, List<int>> get trustedKeys => <String, List<int>>{
    kid: publicKey.bytes,
  };

  /// Подписанный `mitso-update.json`.
  Future<String> sign(Map<String, Object?> manifest) => UpdateEnvelope.sign(
    manifestBytes: utf8.encode(jsonEncode(manifest)),
    kid: kid,
    keyPair: _keyPair,
  );
}

/// Манифест релиза для тестов.
Map<String, Object?> manifestJson({
  String version = '1.1.0',
  int build = 2,
  int minSupportedBuild = 0,
  String notes = 'Что нового',
  Map<String, Object?>? assets,
}) => <String, Object?>{
  'version': version,
  'build': build,
  'minSupportedBuild': minSupportedBuild,
  'notes': notes,
  'releaseUrl': 'https://github.com/OrionZ43/mitso_schedule/releases/tag/v1',
  'assets': assets ?? <String, Object?>{},
};

/// Описание файла релиза для тестов.
Map<String, Object?> assetJson({
  required String url,
  required int size,
  required String sha256,
}) => <String, Object?>{
  'urls': <String>[url],
  'size': size,
  'sha256': sha256,
};

/// Установка в тестах: запоминает файл и, если велели, падает.
class FakeInstaller implements UpdateInstallPort {
  FakeInstaller({this.isSupported = true, this.error});

  final List<File> installed = <File>[];

  @override
  final bool isSupported;

  /// Чем кончится установка; `null` — установщик откроется.
  UpdateInstallException? error;

  @override
  Future<void> install(File file) async {
    installed.add(file);
    if (error != null) throw error!;
  }
}

/// Загрузчик для тестов интерфейса: сразу отдаёт готовый файл.
///
/// Настоящий работает с диском и считает SHA-256 в отдельном изоляте — в
/// `testWidgets` время ненастоящее, и такой загрузке просто неоткуда взять
/// ход. Сам он проверен в `update_download_test.dart`.
class FakeDownloader extends UpdateDownloader {
  FakeDownloader(this.file)
    : super(directory: Directory.systemTemp, transport: FakeUpdateTransport());

  final File file;

  @override
  Future<File> download(
    UpdateAsset asset, {
    void Function(double progress)? onProgress,
    UpdateCancelToken? cancelToken,
  }) async {
    onProgress?.call(1);
    return file;
  }
}
