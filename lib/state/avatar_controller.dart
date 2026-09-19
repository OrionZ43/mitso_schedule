import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/photo_picker.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Фото профиля: путь к файлу в папке приложения, `null` — фото нет.
///
/// Никуда не отправляется и живёт только на устройстве.
final avatarControllerProvider = NotifierProvider<AvatarController, String?>(
  AvatarController.new,
);

class AvatarController extends Notifier<String?> {
  static const String key = 'profile.avatar';
  static const String folder = 'avatar';

  /// Аватар показывается не крупнее 96dp — больше 512 px хранить незачем.
  static const double maxSide = 512;
  static const int quality = 90;

  @override
  String? build() {
    final String? path = ref.read(sharedPreferencesProvider).getString(key);
    // Файл мог не пережить очистку данных или переезд между устройствами.
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  /// Снимает или выбирает фото. `false` — пользователь вернулся без снимка.
  Future<bool> pick(PhotoSource source) async {
    final PhotoPicker picker = ref.read(photoPickerProvider);
    final String? picked = await picker.pick(
      source,
      maxSide: maxSide,
      quality: quality,
    );
    if (picked == null) return false;

    // Имя новое каждый раз: Flutter кэширует картинку по пути файла, и
    // поверх старого пути новое фото не появилось бы.
    final String kept = await picker.keep(
      picked,
      folder: folder,
      name: '${ref.read(clockProvider)().microsecondsSinceEpoch}',
    );
    await _replace(kept);
    return true;
  }

  Future<void> remove() => _replace(null);

  Future<void> _replace(String? path) async {
    final String? previous = state;
    if (previous == path) return;
    state = path;

    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (path == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, path);
    }
    if (previous != null) {
      await ref.read(photoPickerProvider).discard(previous);
    }
  }
}
