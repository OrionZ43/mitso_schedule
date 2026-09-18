import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../models/student_account.dart';
import 'mitso_client.dart' show MitsoClient, MitsoException;

/// Лицевой счёт студента: живой сайт в приложении, подстановка в тестах.
abstract interface class StudentApi {
  /// Данные счёта [number]. Логин и пароль на сайте — один и тот же номер.
  Future<StudentAccount> fetch(String number);
}

/// Клиент личного кабинета на student.mitso.by.
///
/// Сайт простой: одна форма `login_stud.php` (`login` и `password` — номер
/// лицевого счёта) в ответ сразу отдаёт страницу с балансом и доступом к СДО,
/// сессия и cookie не нужны. Данные на сайте обновляются раз в сутки в 13:00
/// и относятся к концу предыдущего дня — чаще обновлять нечего.
class StudentClient implements StudentApi {
  StudentClient(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Клиент приложения: сертификаты `*.mitso.by` те же, что у расписания.
  static Future<StudentClient> create() async {
    return withCertificates([
      for (final String asset in MitsoClient.certificateAssets)
        (await rootBundle.load(asset)).buffer.asUint8List(),
    ]);
  }

  static StudentClient withCertificates(
    List<List<int>> pemCertificates, {
    DateTime Function()? clock,
  }) {
    final SecurityContext context = SecurityContext(withTrustedRoots: true);
    for (final List<int> pem in pemCertificates) {
      context.setTrustedCertificatesBytes(pem);
    }
    final HttpClient client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'mitso_schedule/1.0 (Android; +https://student.mitso.by)';
    return StudentClient(client, clock: clock);
  }

  static const String _loginUrl = 'https://student.mitso.by/login_stud.php';
  static const Duration _timeout = Duration(seconds: 30);

  final HttpClient _client;
  final DateTime Function() _clock;

  void close() => _client.close(force: true);

  @override
  Future<StudentAccount> fetch(String number) async {
    final String body = await _post(number);
    return StudentAccountParser.parse(
      body,
      number: number,
      fetchedAt: _clock(),
    );
  }

  Future<String> _post(String number) async {
    final String form = [
      'login=${Uri.encodeQueryComponent(number)}',
      'password=${Uri.encodeQueryComponent(number)}',
    ].join('&');

    try {
      final HttpClientRequest request = await _client
          .postUrl(Uri.parse(_loginUrl))
          .timeout(_timeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.write(form);
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw MitsoException(
          'Сайт лицевого счёта ответил ошибкой ${response.statusCode}.',
        );
      }
      return body;
    } on MitsoException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MitsoException('Сайт лицевого счёта не отвечает.', cause: e);
    } on SocketException catch (e) {
      throw MitsoException('Нет соединения с сайтом лицевого счёта.', cause: e);
    } on HandshakeException catch (e) {
      throw MitsoException(
        'Не удалось проверить сертификат сайта лицевого счёта.',
        cause: e,
      );
    }
  }
}

/// Разбор страницы лицевого счёта.
abstract final class StudentAccountParser {
  /// Ярлыки сумм на странице.
  static const String balanceLabel = 'Баланс';
  static const String debtLabel = 'Основной долг';
  static const String penaltyLabel = 'Пеня';

  static StudentAccount parse(
    String body, {
    required String number,
    required DateTime fetchedAt,
  }) {
    final dom.Document document = html.parse(body);

    final String name = _text(document.querySelector('#topsection .topmenu'));
    // Форма входа вместо кабинета — номер не подошёл.
    if (name.isEmpty || document.querySelector('form.form1') != null) {
      throw const MitsoException(
        'Лицевой счёт не найден. Проверьте номер: он указан в договоре.',
      );
    }

    final Map<String, String> amounts = {};
    for (final dom.Element row in document.querySelectorAll('table tr')) {
      final List<dom.Element> cells = row.querySelectorAll('td');
      if (cells.length < 2) continue;
      amounts[_text(cells[0])] = _text(cells[1]);
    }

    double amount(String label) {
      for (final MapEntry<String, String> entry in amounts.entries) {
        if (entry.key.startsWith(label)) return _money(entry.value);
      }
      throw MitsoException('На странице счёта нет строки «$label».');
    }

    final DateTime asOf = _asOf(document) ?? DateTime(fetchedAt.year, 1, 1);

    return StudentAccount(
      number: number,
      fullName: name,
      balance: amount(balanceLabel),
      debt: amount(debtLabel),
      penalty: amount(penaltyLabel),
      asOf: asOf,
      fetchedAt: fetchedAt,
      moodle: _moodle(document),
    );
  }

  /// «Состояние лицевого счета на конец дня 17-09-2026:».
  static DateTime? _asOf(dom.Document document) {
    for (final dom.Element section in document.querySelectorAll(
      '#what_section',
    )) {
      final RegExpMatch? match = RegExp(
        r'(\d{1,2})-(\d{1,2})-(\d{4})',
      ).firstMatch(_text(section));
      if (match != null) {
        return DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
        );
      }
    }
    return null;
  }

  /// Блок «Доступ к системе дистанционного обучения»: группа, логин, пароль.
  static MoodleAccess? _moodle(dom.Document document) {
    final Map<String, String> fields = {};
    for (final dom.Element paragraph in document.querySelectorAll('p')) {
      final dom.Element? label = paragraph.querySelector('b');
      if (label == null) continue;
      final String key = _text(label).replaceAll(':', '');
      final String value = _text(paragraph).substring(_text(label).length);
      if (value.trim().isNotEmpty) fields[key] = value.trim();
    }
    final String? login = fields['Логин'];
    final String? password = fields['Пароль'];
    if (login == null || password == null) return null;
    return MoodleAccess(
      group: fields['Группа'] ?? '',
      login: login,
      password: password,
    );
  }

  static String _text(dom.Element? element) =>
      (element?.text ?? '').replaceAll(' ', ' ').trim();

  /// «1.61», «1,61», «-12 345.00» → число.
  static double _money(String raw) {
    final String normalized = raw
        .replaceAll(RegExp(r'[\s ]'), '')
        .replaceAll(',', '.');
    final double? value = double.tryParse(normalized);
    if (value == null) {
      throw MitsoException('Не удалось прочитать сумму «$raw».');
    }
    return value;
  }
}
