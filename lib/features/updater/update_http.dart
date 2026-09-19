import 'dart:convert';
import 'dart:io';

/// Сервер ответил не тем, чем нужно.
class UpdateHttpException implements Exception {
  const UpdateHttpException(this.url, this.statusCode);

  final Uri url;
  final int statusCode;

  @override
  String toString() => 'UpdateHttpException: $statusCode на $url';
}

/// Загрузку отменил пользователь.
class UpdateCancelled implements Exception {
  const UpdateCancelled();

  @override
  String toString() => 'UpdateCancelled';
}

/// Отмена загрузки: один токен на одну попытку.
///
/// Проверяется на каждом куске из сети — выход из `await for` закрывает
/// соединение сам.
class UpdateCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const UpdateCancelled();
  }
}

/// Открытый поток файла.
class UpdateStream {
  const UpdateStream({required this.resumed, required this.bytes});

  /// Сервер продолжил с запрошенного места (206), а не прислал файл целиком.
  final bool resumed;

  final Stream<List<int>> bytes;
}

/// Сеть обновлений. В приложении — [IoUpdateTransport], в тестах подставная.
abstract interface class UpdateTransport {
  /// Скачивает небольшой текстовый файл целиком (манифест).
  Future<String> fetchText(Uri url);

  /// Открывает поток файла; [offset] > 0 — просит продолжить с этого места.
  Future<UpdateStream> openStream(Uri url, {int offset});

  /// Закрывает соединения.
  void close();
}

/// Сеть поверх `dart:io`.
///
/// Остальной сетевой слой приложения (`mitso_client.dart`,
/// `student_client.dart`) сделан так же: ради одной загрузки в год отдельный
/// HTTP-пакет в зависимостях не нужен. Редиректы `HttpClient` проходит сам —
/// GitHub отдаёт файлы релиза именно редиректом.
class IoUpdateTransport implements UpdateTransport {
  IoUpdateTransport({HttpClient? client})
    : _client =
          client ??
          (HttpClient()
            ..connectionTimeout = const Duration(seconds: 15)
            ..userAgent = 'mitso_schedule');

  final HttpClient _client;

  /// Ожидание заголовков ответа. Само тело качается без общего срока: на
  /// медленной сети большой файл идёт долго, и обрывать его нельзя.
  static const Duration _headersTimeout = Duration(seconds: 30);

  @override
  Future<String> fetchText(Uri url) async {
    final HttpClientRequest request = await _client.getUrl(url);
    final HttpClientResponse response = await request.close().timeout(
      _headersTimeout,
    );
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw UpdateHttpException(url, response.statusCode);
    }
    return response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(minutes: 1));
  }

  @override
  Future<UpdateStream> openStream(Uri url, {int offset = 0}) async {
    final HttpClientRequest request = await _client.getUrl(url);
    if (offset > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
    }
    final HttpClientResponse response = await request.close().timeout(
      _headersTimeout,
    );
    final int status = response.statusCode;
    if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
      await response.drain<void>();
      throw UpdateHttpException(url, status);
    }
    return UpdateStream(
      resumed: status == HttpStatus.partialContent,
      bytes: response,
    );
  }

  @override
  void close() => _client.close(force: true);
}
