import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mitso_schedule/features/updater/update_checker.dart';
import 'package:mitso_schedule/features/updater/update_provider.dart';
import 'package:mitso_schedule/widgets/m3_navigation_bar.dart';

import 'app_test.dart';
import 'support/fake_update_transport.dart';

final Uri _manifestUrl = Uri.parse('https://example.org/mitso-update.json');
final Uri _apkUrl = Uri.parse('https://example.org/app-arm64.apk');
final List<int> _apk = List<int>.generate(512, (int i) => i % 251);

void main() {
  late FakeRelease release;
  late FakeUpdateTransport transport;
  late FakeInstaller installer;
  late Directory directory;

  setUpAll(() async => initializeDateFormatting('ru'));

  setUp(() async {
    release = await FakeRelease.create();
    transport = FakeUpdateTransport(<Uri, List<int>>{_apkUrl: _apk});
    installer = FakeInstaller();
    directory = await Directory.systemTemp.createTemp('mitso-update-ui');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  /// Кладёт на «сервер» подписанный манифест. [build] = 1 — обновления нет:
  /// у приложения в тестах та же сборка.
  Future<void> publish({int build = 5, bool withAsset = true}) async {
    transport.files[_manifestUrl] = utf8.encode(
      await release.sign(
        manifestJson(
          build: build,
          notes: 'Волнистая шкала и другие радости',
          assets: withAsset
              ? <String, Object?>{
                  'android-arm64-v8a': assetJson(
                    url: '$_apkUrl',
                    size: _apk.length,
                    sha256: sha256.convert(_apk).toString(),
                  ),
                }
              : <String, Object?>{},
        ),
      ),
    );
  }

  List<Override> overrides() => <Override>[
    updateCheckerProvider.overrideWith(
      (Ref ref) => UpdateChecker(
        transport: transport,
        manifestUrls: <Uri>[_manifestUrl],
        trustedKeys: release.trustedKeys,
      ),
    ),
    updateTargetProvider.overrideWith(
      (Ref ref) async => const UpdateTarget(
        build: 1,
        assetKeys: <String>['android-arm64-v8a', 'android-universal'],
      ),
    ),
    updateDownloaderProvider.overrideWith(
      (Ref ref) async => FakeDownloader(File('${directory.path}/app.apk')),
    ),
    updateInstallerProvider.overrideWith((Ref ref) => installer),
  ];

  /// Профиль → шестерёнка.
  Future<void> openSettings(WidgetTester tester) async {
    await openTab(tester, 'Профиль');
    await tester.tap(find.byIcon(Symbols.settings));
    await settle(tester);
  }

  testWidgets('обновление предлагается в настройках и ставится', (
    tester,
  ) async {
    await publish();
    await pumpApp(tester, overrides: overrides());
    await openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('О приложении'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    expect(find.text('Расписание 1.0.0 (1)'), findsOneWidget);
    expect(find.text('Доступна версия 1.1.0'), findsOneWidget);
    expect(find.text('Версия 1.1.0'), findsOneWidget);
    expect(find.text('Волнистая шкала и другие радости'), findsOneWidget);

    await tester.tap(find.text('Обновить'));
    await settle(tester);

    expect(installer.installed, hasLength(1));
    expect(installer.installed.single.path, endsWith('app.apk'));
  });

  testWidgets('точка ведёт от вкладки к настройкам', (tester) async {
    await publish();
    await pumpApp(tester, overrides: overrides());
    await tester.pump(const Duration(milliseconds: 100));

    // Точка на «Профиле»: пункт не выбран, значит бейдж виден.
    final Badge profileBadge = tester.widget<Badge>(
      find
          .descendant(
            of: find.byType(M3NavigationBar),
            matching: find.byType(Badge),
          )
          .last,
    );
    expect(profileBadge.isLabelVisible, isTrue);
    expect(profileBadge.label, isNull, reason: 'Точка, а не счётчик');

    await openTab(tester, 'Профиль');

    // На выбранном пункте точки нет (badges → With other components).
    expect(
      tester
          .widget<Badge>(
            find
                .descendant(
                  of: find.byType(M3NavigationBar),
                  matching: find.byType(Badge),
                )
                .last,
          )
          .isLabelVisible,
      isFalse,
    );
    // Зато она на шестерёнке, за которой лежит обновление.
    expect(find.byTooltip('Настройки, доступно обновление'), findsOneWidget);
  });

  testWidgets('«Позже» убирает и карточку, и точку', (tester) async {
    await publish();
    await pumpApp(tester, overrides: overrides());
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Позже'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    await tester.tap(find.text('Позже'));
    await settle(tester);

    expect(find.text('Версия 1.1.0'), findsNothing);
    expect(find.text('Доступна версия 1.1.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await settle(tester);
    expect(find.byTooltip('Настройки'), findsOneWidget);
  });

  testWidgets('когда новее нет — так и написано', (tester) async {
    await publish(build: 1);
    await pumpApp(tester, overrides: overrides());
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('О приложении'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    expect(find.text('Установлена последняя версия'), findsOneWidget);
    expect(find.text('Обновить'), findsNothing);
  });

  testWidgets('без сети не пишем, что версия последняя', (tester) async {
    await publish();
    transport.broken.add(_manifestUrl);
    await pumpApp(tester, overrides: overrides());
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('О приложении'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    expect(find.text('Не удалось проверить обновления'), findsOneWidget);
  });
}
