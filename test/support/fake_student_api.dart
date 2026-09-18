import 'dart:io';

import 'package:mitso_schedule/data/balance_alerts.dart';
import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/mitso/student_client.dart';
import 'package:mitso_schedule/data/models/student_account.dart';

/// Подстановка student.mitso.by: настоящая разметка страницы с выдуманными
/// данными, номер 100200. Любой другой номер — «счёт не найден».
class FakeStudentApi implements StudentApi {
  FakeStudentApi({this.fetchedAt, this.fail = false});

  static const String number = '100200';

  final DateTime? fetchedAt;

  /// Имитировать недоступный сайт.
  final bool fail;

  final List<String> requests = [];

  @override
  Future<StudentAccount> fetch(String number) async {
    requests.add(number);
    if (fail) {
      throw const MitsoException('Нет соединения с сайтом лицевого счёта.');
    }
    final String page = File(
      number == FakeStudentApi.number
          ? 'test/fixtures/student_account.html'
          : 'test/fixtures/student_login.html',
    ).readAsStringSync();
    return StudentAccountParser.parse(
      page,
      number: number,
      fetchedAt: fetchedAt ?? DateTime(2026, 9, 18, 14),
    );
  }
}

/// Запоминает уведомления о долге вместо показа.
class FakeBalanceAlerts implements BalanceAlertPort {
  final List<StudentAccount> shown = [];
  int cancelled = 0;

  @override
  Future<void> showDebt(StudentAccount account) async => shown.add(account);

  @override
  Future<void> cancel() async => cancelled++;
}
