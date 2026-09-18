import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/data/balance_alerts.dart';
import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/mitso/student_client.dart';
import 'package:mitso_schedule/data/models/student_account.dart';
import 'package:mitso_schedule/state/student_controller.dart';

StudentAccount _account({
  double balance = 0,
  double debt = 0,
  double penalty = 0,
  DateTime? fetchedAt,
}) => StudentAccount(
  number: '100200',
  fullName: 'Иванов Иван Иванович',
  balance: balance,
  debt: debt,
  penalty: penalty,
  asOf: DateTime(2026, 9, 17),
  fetchedAt: fetchedAt ?? DateTime(2026, 9, 18, 14),
);

void main() {
  group('разбор страницы лицевого счёта', () {
    late StudentAccount account;

    setUpAll(() {
      account = StudentAccountParser.parse(
        File('test/fixtures/student_account.html').readAsStringSync(),
        number: '100200',
        fetchedAt: DateTime(2026, 9, 18, 14, 5),
      );
    });

    test('ФИО, суммы и дата', () {
      expect(account.fullName, 'Иванов Иван Иванович');
      expect(account.balance, -12.34);
      expect(account.debt, 10.00);
      expect(account.penalty, 2.34);
      expect(account.asOf, DateTime(2026, 9, 17));
      expect(account.number, '100200');
    });

    test('доступ к СДО', () {
      expect(account.moodle?.group, '2423');
      expect(account.moodle?.login, '100200');
      expect(account.moodle?.password, '12345678');
    });

    test('минус на балансе — задолженность', () {
      expect(account.inDebt, isTrue);
      expect(_account(balance: 1.61).inDebt, isFalse);
      expect(_account(penalty: 0.5).inDebt, isTrue);
    });

    test('фамилия с инициалами', () {
      expect(account.shortName, 'Иванов И. И.');
    });

    test('страница входа — счёт не найден', () {
      expect(
        () => StudentAccountParser.parse(
          File('test/fixtures/student_login.html').readAsStringSync(),
          number: '000000',
          fetchedAt: DateTime(2026, 9, 18),
        ),
        throwsA(
          isA<MitsoException>().having(
            (e) => e.message,
            'message',
            contains('не найден'),
          ),
        ),
      );
    });

    test('json туда и обратно', () {
      final StudentAccount copy = StudentAccount.fromJson(account.toJson());
      expect(copy.balance, account.balance);
      expect(copy.asOf, account.asOf);
      expect(copy.moodle?.password, account.moodle?.password);
    });
  });

  group('когда обновлять и когда сообщать', () {
    test('сайт считает счёт в 13:00 — до него данные вчерашние', () {
      expect(
        StudentController.lastSiteUpdate(DateTime(2026, 9, 18, 12, 59)),
        DateTime(2026, 9, 17, 13),
      );
      expect(
        StudentController.lastSiteUpdate(DateTime(2026, 9, 18, 13, 1)),
        DateTime(2026, 9, 18, 13),
      );
    });

    test('данные старее последнего обновления сайта — устарели', () {
      final DateTime now = DateTime(2026, 9, 18, 14);
      expect(
        StudentController.isStale(
          _account(fetchedAt: DateTime(2026, 9, 18, 12)),
          now,
        ),
        isTrue,
      );
      expect(
        StudentController.isStale(
          _account(fetchedAt: DateTime(2026, 9, 18, 13, 30)),
          now,
        ),
        isFalse,
      );
    });

    test('сообщаем о долге, когда он появился или вырос', () {
      final StudentAccount ok = _account(balance: 1.61);
      final StudentAccount debt = _account(balance: -5);
      final StudentAccount more = _account(balance: -20);

      expect(BalanceAlerts.shouldNotify(previous: null, current: ok), isFalse);
      expect(BalanceAlerts.shouldNotify(previous: null, current: debt), isTrue);
      expect(BalanceAlerts.shouldNotify(previous: ok, current: debt), isTrue);
      // Тот же долг второй раз не тревожит.
      expect(
        BalanceAlerts.shouldNotify(previous: debt, current: debt),
        isFalse,
      );
      expect(BalanceAlerts.shouldNotify(previous: debt, current: more), isTrue);
      expect(BalanceAlerts.shouldNotify(previous: debt, current: ok), isFalse);
    });
  });
}
