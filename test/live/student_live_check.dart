// Проверка живого student.mitso.by. Не входит в обычный `flutter test`
// (имя без _test.dart): ходит в сеть.
//
//   flutter test test/live/student_live_check.dart
//
// Настоящий номер счёта в репозиторий не попадает: по умолчанию проверяется
// только отказ сайта на выдуманный номер — он показывает, что форма входа и
// разметка на месте. Чтобы проверить разбор настоящей страницы, номер
// передаётся переменной окружения и остаётся на машине:
//
//   flutter test test/live/student_live_check.dart --dart-define=ACCOUNT=123456
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/mitso/student_client.dart';
import 'package:mitso_schedule/data/models/student_account.dart';

const String _account = String.fromEnvironment('ACCOUNT');

List<int> _read(String path) => File(path).readAsBytesSync();

StudentClient _client() => StudentClient.withCertificates([
  for (final String asset in MitsoClient.certificateAssets) _read(asset),
]);

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'выдуманный номер — внятный отказ, а не пустая страница',
    () async {
      final StudentClient client = _client();
      addTearDown(client.close);

      await expectLater(
        client.fetch('000000'),
        throwsA(
          isA<MitsoException>().having(
            (e) => e.message,
            'message',
            contains('Лицевой счёт не найден'),
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'настоящий номер: страница разбирается',
    () async {
      if (_account.isEmpty) {
        debugPrint('ACCOUNT не задан — проверка настоящего счёта пропущена');
        return;
      }
      final StudentClient client = _client();
      addTearDown(client.close);

      final StudentAccount account = await client.fetch(_account);
      // Ни ФИО, ни номера, ни паролей в выводе: только то, что разобралось.
      debugPrint(
        'счёт разобран: баланс ${account.balance}, долг ${account.debt}, '
        'пеня ${account.penalty}, на ${account.asOf}, '
        'СДО ${account.moodle == null ? 'нет' : 'есть'}',
      );
      expect(account.fullName, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
