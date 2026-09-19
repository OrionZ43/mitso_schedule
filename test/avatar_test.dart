import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/data/photo_picker.dart';
import 'package:mitso_schedule/state/avatar_controller.dart';
import 'package:mitso_schedule/state/mitso_providers.dart';
import 'package:mitso_schedule/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_mitso_api.dart';
import 'support/fake_photo_picker.dart';

void main() {
  late FakePhotoPicker photos;

  Future<ProviderContainer> containerWith({
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        photoPickerProvider.overrideWithValue(photos),
        clockProvider.overrideWithValue(() => fakeNow),
      ],
    );
  }

  setUp(() => photos = FakePhotoPicker(photoPath: '/fake/avatar.jpg'));

  test('снимок сохраняется в папку приложения и запоминается', () async {
    final ProviderContainer container = await containerWith();
    expect(container.read(avatarControllerProvider), isNull);

    final bool picked = await container
        .read(avatarControllerProvider.notifier)
        .pick(PhotoSource.camera);

    expect(picked, isTrue);
    expect(photos.captures, [PhotoSource.camera]);
    // Имя — время снимка: Flutter кэширует картинку по пути файла.
    expect(photos.kept.single, 'avatar/${fakeNow.microsecondsSinceEpoch}');
    expect(container.read(avatarControllerProvider), '/fake/avatar.jpg');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile.avatar'), '/fake/avatar.jpg');
  });

  test('отказ от снимка ничего не меняет', () async {
    photos.photoPath = null;
    final ProviderContainer container = await containerWith();

    expect(
      await container
          .read(avatarControllerProvider.notifier)
          .pick(PhotoSource.gallery),
      isFalse,
    );
    expect(container.read(avatarControllerProvider), isNull);
    expect(photos.kept, isEmpty);
  });

  test('новое фото заменяет прежнее, а старый файл удаляется', () async {
    final File old = File('${Directory.systemTemp.path}/mitso-avatar-old.jpg')
      ..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(() {
      if (old.existsSync()) old.deleteSync();
    });

    final ProviderContainer container = await containerWith(
      preferences: {'profile.avatar': old.path},
    );
    expect(container.read(avatarControllerProvider), old.path);

    await container
        .read(avatarControllerProvider.notifier)
        .pick(PhotoSource.gallery);

    expect(container.read(avatarControllerProvider), '/fake/avatar.jpg');
    expect(photos.discarded, [old.path]);
  });

  test('«Убрать фото» стирает запись и файл', () async {
    final File photo = File(
      '${Directory.systemTemp.path}/mitso-avatar-remove.jpg',
    )..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });

    final ProviderContainer container = await containerWith(
      preferences: {'profile.avatar': photo.path},
    );
    await container.read(avatarControllerProvider.notifier).remove();

    expect(container.read(avatarControllerProvider), isNull);
    expect(photos.discarded, [photo.path]);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile.avatar'), isNull);
  });

  test('пропавший файл забывается при запуске', () async {
    final ProviderContainer container = await containerWith(
      preferences: {'profile.avatar': '/nowhere/avatar.jpg'},
    );

    expect(container.read(avatarControllerProvider), isNull);
  });
}
