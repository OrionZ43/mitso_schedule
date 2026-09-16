// Проверка TLS на устройстве: apps.mitso.by не отдаёт промежуточный
// сертификат GlobalSign, и на Android без вложенных сертификатов соединение
// должно падать. На Windows этого не увидеть — там Dart сверяет цепочку через
// системное хранилище, которое само докачивает промежуточный.
//
//   flutter test integration_test/mitso_tls_test.dart -d <устройство>
//
// Внимание: прогон пересобирает app-debug.apk с этим тестом вместо приложения.
// Перед `flutter install` соберите приложение заново:
//   flutter build apk --debug -t lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mitso_schedule/data/mitso/mitso_client.dart';
import 'package:mitso_schedule/data/models/group_ref.dart';

/// Показывает экран и ждёт, пока приложение станет активным.
///
/// Android 15+ закрывает сеть приложениям не на переднем плане
/// (APP_BACKGROUND) и только что установленным (APP_STANDBY). Без ожидания
/// запрос уходит раньше, чем активность становится видимой, и падает с
/// «Failed host lookup» — к TLS это отношения не имеет.
Future<void> _bringToForeground(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Проверка TLS'))),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 3));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('без вложенных сертификатов Android не доверяет сайту', (
    tester,
  ) async {
    await _bringToForeground(tester);
    final MitsoClient client = MitsoClient.withCertificates(const []);
    Object? error;
    try {
      await client.faculties();
    } catch (e) {
      error = e;
    } finally {
      client.close();
    }
    expect(
      error,
      isA<MitsoException>().having(
        (e) => e.cause,
        'cause',
        isA<HandshakeException>(),
      ),
    );
  });

  testWidgets('с вложенными сертификатами расписание 2423 УИР загружается', (
    tester,
  ) async {
    await _bringToForeground(tester);
    final MitsoClient client = await MitsoClient.create();
    try {
      final weeks = await client.groupSchedule(
        const GroupRef(
          facultyId: 'E`konomicheskij',
          facultyName: 'Экономический',
          formId: 'Dnevnaya',
          formName: 'Дневная',
          courseId: '3 kurs',
          courseName: '3 курс',
          groupId: '2423 UIR',
          groupName: '2423 УИР',
        ),
      );
      expect(weeks, isNotEmpty);
      expect(weeks.first.days, isNotEmpty);
    } finally {
      client.close();
    }
  });
}
