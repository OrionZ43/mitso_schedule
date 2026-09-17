import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Откуда взять фото справки.
enum CertificatePhotoSource { camera, gallery }

/// Съёмка и хранение фото справок. В тестах подменяется.
abstract interface class CertificatePhotos {
  /// Снимок системной камерой или выбор в системном фотовыборе. `null` —
  /// пользователь вернулся без фото.
  Future<String?> capture(CertificatePhotoSource source);

  /// Переносит снимок из временных файлов в постоянные и возвращает новый
  /// путь: кэш, куда кладёт снимки `image_picker`, система может очистить.
  Future<String> keep(String path, String id);
}

class DeviceCertificatePhotos implements CertificatePhotos {
  const DeviceCertificatePhotos();

  /// Текст справки должен читаться, но файл не должен весить десятки
  /// мегабайт: длинная сторона до 2400 px, JPEG 90%.
  static const double maxSide = 2400;
  static const int quality = 90;

  @override
  Future<String?> capture(CertificatePhotoSource source) async {
    final XFile? file = await ImagePicker().pickImage(
      source: switch (source) {
        CertificatePhotoSource.camera => ImageSource.camera,
        CertificatePhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    return file?.path;
  }

  @override
  Future<String> keep(String path, String id) async {
    final Directory root = await getApplicationSupportDirectory();
    final Directory dir = Directory('${root.path}/certificates');
    await dir.create(recursive: true);
    final String extension = path.contains('.')
        ? path.substring(path.lastIndexOf('.'))
        : '.jpg';
    final File kept = await File(path).copy('${dir.path}/$id$extension');
    return kept.path;
  }
}
