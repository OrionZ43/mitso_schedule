import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'update_http.dart';
import 'update_manifest.dart';

/// Файл не скачался или не сошёлся с манифестом.
class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message, [this.cause]);

  /// Текст для пользователя.
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'UpdateDownloadException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Скачивание файла обновления:
///   * адреса из манифеста перебираются по очереди, при сбое берётся следующий;
///   * оборванная загрузка продолжается с места обрыва (HTTP Range), если
///     сервер это поддерживает, иначе файл качается заново;
///   * готовый файл сверяется по размеру и SHA-256 из подписанного манифеста;
///     хэш считается в отдельном изоляте, чтобы не тормозить интерфейс;
///   * уже скачанный и проверенный файл повторно не качается.
class UpdateDownloader {
  UpdateDownloader({required this.directory, UpdateTransport? transport})
    : _transport = transport ?? IoUpdateTransport();

  /// Куда складывать файлы обновления.
  final Directory directory;

  final UpdateTransport _transport;

  /// Скачивает и проверяет файл. [onProgress] получает долю от 0 до 1.
  Future<File> download(
    UpdateAsset asset, {
    void Function(double progress)? onProgress,
    UpdateCancelToken? cancelToken,
  }) async {
    await directory.create(recursive: true);
    final File target = File(p.join(directory.path, asset.fileName));
    if (await _isComplete(target, asset)) {
      onProgress?.call(1);
      return target;
    }

    final File part = File('${target.path}.${_partTag(asset)}.part');
    await _deleteStaleParts(target, keep: part);
    Object? lastError;
    for (final Uri url in asset.urls) {
      try {
        await _fetch(url, part, asset.size, onProgress, cancelToken);

        final int length = await part.length();
        if (length != asset.size) {
          // Недокачанный кусок оставляем: следующий адрес продолжит с него.
          throw UpdateDownloadException(
            'Загрузка оборвалась: $length из ${asset.size} байт',
          );
        }
        if (await sha256OfFile(part.path) != asset.sha256) {
          await part.delete();
          throw const UpdateDownloadException('SHA-256 не совпал с манифестом');
        }

        if (await target.exists()) await target.delete();
        return await part.rename(target.path);
      } on UpdateCancelled {
        rethrow;
      } catch (error) {
        lastError = error;
      }
      debugPrint('[Обновления] Не удалось скачать $url: $lastError');
    }
    throw UpdateDownloadException('Не удалось скачать обновление', lastError);
  }

  Future<void> _fetch(
    Uri url,
    File part,
    int total,
    void Function(double progress)? onProgress,
    UpdateCancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    int offset = await part.exists() ? await part.length() : 0;
    if (offset > total) {
      await part.delete();
      offset = 0;
    }
    if (offset == total) return;

    final UpdateStream stream = await _transport.openStream(
      url,
      offset: offset,
    );

    // 206 — сервер продолжил с нужного места; 200 — прислал файл целиком.
    final bool resumed = stream.resumed;
    int received = resumed ? offset : 0;
    final IOSink sink = part.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    try {
      await for (final List<int> chunk in stream.bytes) {
        // Выход из цикла закрывает поток, а с ним и соединение.
        cancelToken?.throwIfCancelled();
        received += chunk.length;
        if (received > total) {
          throw const UpdateDownloadException(
            'Сервер прислал больше, чем указано в манифесте',
          );
        }
        sink.add(chunk);
        onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
  }

  /// Недокачанный файл помечен началом хэша своей версии. Имя файла в релизах
  /// от версии к версии одно и то же, и без пометки загрузка новой версии
  /// продолжила бы кусок прошлой: хэш не сошёлся бы, и первая попытка
  /// обновиться уходила бы впустую.
  static String _partTag(UpdateAsset asset) =>
      asset.sha256.length > 12 ? asset.sha256.substring(0, 12) : asset.sha256;

  /// Удаляет куски других версий того же файла, в том числе вида
  /// `<имя>.part` — без пометки версией.
  Future<void> _deleteStaleParts(File target, {required File keep}) async {
    final String prefix = '${p.basename(target.path)}.';
    await for (final FileSystemEntity entity in directory.list()) {
      final String name = p.basename(entity.path);
      if (entity is! File ||
          !name.startsWith(prefix) ||
          !name.endsWith('.part') ||
          p.equals(entity.path, keep.path)) {
        continue;
      }
      try {
        await entity.delete();
      } catch (error) {
        debugPrint(
          '[Обновления] Не удалось удалить старый кусок $name: $error',
        );
      }
    }
  }

  Future<bool> _isComplete(File file, UpdateAsset asset) async {
    if (!await file.exists() || await file.length() != asset.size) {
      return false;
    }
    return await sha256OfFile(file.path) == asset.sha256;
  }

  /// Закрывает соединения. Вызывается, когда провайдер уходит.
  void close() => _transport.close();
}

/// SHA-256 файла в отдельном изоляте: на большом APK подсчёт в основном
/// изоляте съедает кадры.
Future<String> sha256OfFile(String path) => Isolate.run(() async {
  final Digest digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
});
