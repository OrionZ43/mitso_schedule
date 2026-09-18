import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/parser.dart' as html;

import '../models/group_ref.dart';
import '../models/lesson.dart';
import 'schedule_parser.dart';

/// Сайт недоступен, ответил ошибкой или прислал неожиданную страницу.
class MitsoException implements Exception {
  const MitsoException(this.message, {this.cause});

  /// Текст для пользователя.
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'MitsoException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Текст ошибки для пользователя: у наших исключений — свой, у остальных —
/// общий.
String messageOf(Object error) => error is MitsoException
    ? error.message
    : 'Что-то пошло не так. Попробуйте ещё раз.';

/// Источник расписания: живой сайт в приложении, подстановка в тестах.
abstract interface class MitsoApi {
  Future<List<MitsoOption>> faculties();
  Future<List<MitsoOption>> forms(String facultyId);
  Future<List<MitsoOption>> courses(String facultyId, String formId);
  Future<List<MitsoOption>> groups(
    String facultyId,
    String formId,
    String courseId,
  );
  Future<List<ScheduleWeek>> groupSchedule(GroupRef group);
}

/// Клиент открытого расписания на apps.mitso.by.
///
/// Сайт на Yii2 и защищает POST-запросы CSRF-токеном, привязанным к сессии,
/// поэтому перед запросами открывается сессия: GET страницы формы даёт cookie
/// и `<meta name="csrf-token">`. Списки факультет → форма → курс → группа
/// отдаёт виджет Krajee DepDrop JSON-ответами, а одна отправка формы
/// возвращает сразу все доступные недели расписания.
class MitsoClient implements MitsoApi {
  MitsoClient(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Сертификаты, которые сервер не отдаёт в TLS-цепочке.
  ///
  /// apps.mitso.by присылает только конечный сертификат `*.mitso.by` без
  /// промежуточного «GlobalSign GCC R46 AlphaSSL CA 2025». Браузеры докачивают
  /// его по AIA, а Android — нет, и соединение падает с CERTIFICATE_VERIFY_FAILED.
  /// Корень R46 добавлен для старых Android, где его нет в системном хранилище.
  static const List<String> certificateAssets = [
    'assets/certs/globalsign_root_r46.pem',
    'assets/certs/globalsign_gcc_r46_alphassl_ca_2025.pem',
  ];

  /// Клиент приложения: сертификаты берутся из ассетов.
  static Future<MitsoClient> create() async {
    return withCertificates([
      for (final String asset in certificateAssets)
        (await rootBundle.load(asset)).buffer.asUint8List(),
    ]);
  }

  /// Клиент с доверием к переданным PEM-сертификатам поверх системных.
  ///
  /// Проверку сертификата это не отключает: доверие расширяется только до
  /// настоящих сертификатов GlobalSign (SHA-256 отпечатки сверены).
  static MitsoClient withCertificates(
    List<List<int>> pemCertificates, {
    DateTime Function()? clock,
  }) {
    final SecurityContext context = SecurityContext(withTrustedRoots: true);
    for (final List<int> pem in pemCertificates) {
      context.setTrustedCertificatesBytes(pem);
    }
    final HttpClient client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'mitso_schedule/1.0 (Android; +https://apps.mitso.by)';
    return MitsoClient(client, clock: clock);
  }

  static const String _base = 'https://apps.mitso.by/frontend/web';
  static const Duration _timeout = Duration(seconds: 30);

  final HttpClient _client;
  final DateTime Function() _clock;

  final Map<String, String> _cookies = {};
  String? _csrf;
  List<MitsoOption>? _faculties;

  void close() => _client.close(force: true);

  // ───────────────────────────── Списки выбора ─────────────────────────────

  /// Факультеты — статичный список в разметке формы.
  @override
  Future<List<MitsoOption>> faculties() async {
    await _ensureSession();
    return _faculties!;
  }

  @override
  Future<List<MitsoOption>> forms(String facultyId) =>
      _depDrop('education', {'faculty-id': facultyId});

  @override
  Future<List<MitsoOption>> courses(String facultyId, String formId) =>
      _depDrop('course', {'faculty-id': facultyId, 'form-id': formId});

  @override
  Future<List<MitsoOption>> groups(
    String facultyId,
    String formId,
    String courseId,
  ) => _depDrop('group', {
    'faculty-id': facultyId,
    'form-id': formId,
    'course-id': courseId,
  });

  // ─────────────────────────────── Расписание ───────────────────────────────

  /// Все доступные недели для группы (обычно текущая и следующая).
  ///
  /// Параметр недели сервер проверяет только на непустоту: при любом значении
  /// в ответе обе недели, поэтому список недель отдельно не запрашивается.
  @override
  Future<List<ScheduleWeek>> groupSchedule(GroupRef group) async {
    final String body = await _post('group-schedule', {
      'ScheduleSearch[fak]': [group.facultyId],
      'ScheduleSearch[form]': [group.formId],
      'ScheduleSearch[kurse]': [group.courseId],
      'ScheduleSearch[group_class]': [group.groupId],
      'ScheduleSearch[week]': ['0'],
    });
    try {
      return ScheduleParser.parse(body, today: _clock());
    } on ScheduleParseException catch (e) {
      throw MitsoException(
        'Сайт вернул страницу без расписания. Возможно, группа больше не существует.',
        cause: e,
      );
    }
  }

  // ─────────────────────────────── Транспорт ───────────────────────────────

  Future<List<MitsoOption>> _depDrop(
    String endpoint,
    Map<String, String> params,
  ) async {
    final String body = await _post(endpoint, {
      'depdrop_parents[]': params.values.toList(),
      for (final MapEntry<String, String> e in params.entries)
        'depdrop_all_params[${e.key}]': [e.value],
    }, ajax: true);
    try {
      final Map<String, Object?> json =
          jsonDecode(body) as Map<String, Object?>;
      return [
        for (final Object? item in json['output']! as List<Object?>)
          MitsoOption.fromJson(item! as Map<String, Object?>),
      ];
    } catch (e) {
      throw MitsoException('Не удалось разобрать ответ сайта.', cause: e);
    }
  }

  /// POST с CSRF-токеном. Если сессия истекла (Yii отвечает 400), она
  /// открывается заново и запрос повторяется один раз.
  Future<String> _post(
    String endpoint,
    Map<String, List<String>> form, {
    bool ajax = false,
  }) async {
    await _ensureSession();
    final (int status, String body) = await _send(endpoint, form, ajax: ajax);
    if (status != HttpStatus.badRequest) return _checked(status, body);

    _cookies.clear();
    _csrf = null;
    await _ensureSession();
    final (int retryStatus, String retryBody) = await _send(
      endpoint,
      form,
      ajax: ajax,
    );
    return _checked(retryStatus, retryBody);
  }

  Future<(int, String)> _send(
    String endpoint,
    Map<String, List<String>> form, {
    required bool ajax,
  }) {
    final String encoded = [
      '${Uri.encodeQueryComponent('_csrf-frontend')}=${Uri.encodeQueryComponent(_csrf!)}',
      for (final MapEntry<String, List<String>> e in form.entries)
        for (final String value in e.value)
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(value)}',
    ].join('&');

    return _request('POST', '/schedule/$endpoint', (request) {
      request.headers
        ..contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        )
        ..set('X-CSRF-Token', _csrf!);
      if (ajax) request.headers.set('X-Requested-With', 'XMLHttpRequest');
      request.write(encoded);
    });
  }

  /// Открывает сессию: cookie и CSRF-токен со страницы формы, заодно —
  /// статичный список факультетов.
  Future<void> _ensureSession() async {
    if (_csrf != null && _faculties != null) return;

    final (int status, String body) = await _request(
      'GET',
      '/schedule/group-schedule',
      null,
    );
    _checked(status, body);

    final document = html.parse(body);
    final String? token = document
        .querySelector('meta[name="csrf-token"]')
        ?.attributes['content'];
    if (token == null || token.isEmpty) {
      throw const MitsoException('Сайт расписания не выдал токен сессии.');
    }
    _csrf = token;
    _faculties = [
      for (final option in document.querySelectorAll(
        'select#faculty-id option',
      ))
        if ((option.attributes['value'] ?? '').isNotEmpty)
          MitsoOption(
            id: option.attributes['value']!,
            name: option.text.trim(),
          ),
    ];
  }

  Future<(int, String)> _request(
    String method,
    String path,
    void Function(HttpClientRequest request)? configure,
  ) async {
    try {
      final HttpClientRequest request = await _client
          .openUrl(method, Uri.parse('$_base$path'))
          .timeout(_timeout);
      request.followRedirects = true;
      if (_cookies.isNotEmpty) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        );
      }
      configure?.call(request);

      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      for (final Cookie cookie in response.cookies) {
        _cookies[cookie.name] = cookie.value;
      }
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return (response.statusCode, body);
    } on HandshakeException catch (e) {
      throw MitsoException(
        'Не удалось проверить сертификат сайта расписания.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw MitsoException('Нет соединения с сайтом расписания.', cause: e);
    } on TimeoutException catch (e) {
      throw MitsoException('Сайт расписания не отвечает.', cause: e);
    } on HttpException catch (e) {
      throw MitsoException('Ошибка связи с сайтом расписания.', cause: e);
    }
  }

  String _checked(int status, String body) {
    if (status >= 200 && status < 300) return body;
    throw MitsoException('Сайт расписания ответил ошибкой $status.');
  }
}

/// Пункт списка выбора: транслитерированный `id` для запросов и подпись.
@immutable
class MitsoOption {
  const MitsoOption({required this.id, required this.name});

  factory MitsoOption.fromJson(Map<String, Object?> json) => MitsoOption(
    // У недель id — число, у остальных списков — строка.
    id: json['id'].toString(),
    name: (json['name'] ?? '').toString().trim(),
  );

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is MitsoOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
