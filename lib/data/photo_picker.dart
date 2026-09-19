import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Откуда взять фото.
enum PhotoSource { camera, gallery }

/// Съёмка, выбор и хранение фото: справка о пропуске, фото профиля.
/// В тестах подменяется.
abstract interface class PhotoPicker {
  /// Снимок системной камерой или выбор в системном фотовыборе. `null` —
  /// пользователь вернулся без фото.
  ///
  /// [maxSide] и [quality] — во что пережать снимок: у справки должен
  /// читаться текст, у аватара — нет.
  Future<String?> pick(PhotoSource source, {double maxSide, int quality});

  /// Переносит снимок из временных файлов в постоянные и возвращает новый
  /// путь: кэш, куда кладёт снимки `image_picker`, система может очистить.
  Future<String> keep(
    String path, {
    required String folder,
    required String name,
  });

  /// Удаляет сохранённый файл: заменили аватар — старый больше не нужен.
  Future<void> discard(String path);
}

/// Съёмка и хранение фото. В тестах подменяется.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => const DevicePhotoPicker(),
);

class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  /// Текст справки должен читаться, но файл не должен весить десятки
  /// мегабайт: длинная сторона до 2400 px, JPEG 90%.
  static const double maxSide = 2400;
  static const int quality = 90;

  @override
  Future<String?> pick(
    PhotoSource source, {
    double maxSide = maxSide,
    int quality = quality,
  }) async {
    final XFile? file = await ImagePicker().pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    return file?.path;
  }

  @override
  Future<String> keep(
    String path, {
    required String folder,
    required String name,
  }) async {
    final Directory root = await getApplicationSupportDirectory();
    final Directory dir = Directory('${root.path}/$folder');
    await dir.create(recursive: true);
    final String extension = path.contains('.')
        ? path.substring(path.lastIndexOf('.'))
        : '.jpg';
    final File kept = await File(path).copy('${dir.path}/$name$extension');
    return kept.path;
  }

  @override
  Future<void> discard(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      // Файл мог уже исчезнуть — на месте фото это ничего не меняет.
      debugPrint('[Фото] Не удалось удалить $path: $error');
    }
  }
}
