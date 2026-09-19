import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/data/models/lesson.dart';
import 'package:mitso_schedule/data/wear_sync.dart';

final List<ScheduleWeek> _weeks = <ScheduleWeek>[
  ScheduleWeek(
    label: 'Текущая неделя',
    days: <ScheduleDay>[
      ScheduleDay(
        date: DateTime(2026, 9, 16),
        lessons: const <Lesson>[
          Lesson(
            start: '09:45',
            end: '11:05',
            title: 'Веб-дизайн и шаблоны проектирования',
            type: LessonType.lecture,
            typeLabel: 'Лекция',
            teacher: 'Калинин М. А.',
            room: '71',
          ),
        ],
      ),
    ],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('mitso/wear');
  late List<MethodCall> calls;

  void mockChannel({bool? answer}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return answer;
        });
  }

  setUp(() => calls = <MethodCall>[]);

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('на часы уходят группа и недели', () async {
    mockChannel(answer: true);

    final bool sent = await const WearSync().push('2423 УИР', _weeks);

    expect(sent, isTrue);
    expect(calls.single.method, 'sync');
    final Map<String, Object?> payload =
        jsonDecode(
              (calls.single.arguments as Map<Object?, Object?>)['payload']!
                  as String,
            )
            as Map<String, Object?>;
    expect(payload['group'], '2423 УИР');
    final List<Object?> weeks = payload['weeks']! as List<Object?>;
    expect(weeks, hasLength(1));
    final Map<String, Object?> day =
        ((weeks.first! as Map<String, Object?>)['days']! as List<Object?>)
                .first!
            as Map<String, Object?>;
    expect(day['date'], startsWith('2026-09-16'));

    // Время загрузки не отправляется: иначе одинаковое расписание каждый раз
    // заново уезжало бы на часы по Bluetooth.
    expect(payload.containsKey('fetchedAt'), isFalse);
  });

  test('без часов приложение не падает', () async {
    // Канала нет — как на телефоне без Play Services или на компьютере.
    final bool sent = await const WearSync().push('2423 УИР', _weeks);
    expect(sent, isFalse);
  });

  test('отказ платформы — не ошибка', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          throw PlatformException(code: 'no_payload');
        });

    expect(await const WearSync().push('2423 УИР', _weeks), isFalse);
  });
}
