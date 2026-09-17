import 'package:flutter/services.dart';
import 'package:mitso_schedule/data/certificate_photos.dart';

/// Подстановка камеры и галереи: сразу «снимает» [photoPath] и ничего не
/// копирует.
class FakeCertificatePhotos implements CertificatePhotos {
  FakeCertificatePhotos({
    this.photoPath = '/fake/certificate.jpg',
    this.failCapture = false,
  });

  String? photoPath;

  /// Имитировать недоступную камеру или галерею.
  final bool failCapture;

  final List<CertificatePhotoSource> captures = [];

  @override
  Future<String?> capture(CertificatePhotoSource source) async {
    captures.add(source);
    if (failCapture) throw PlatformException(code: 'no_available_camera');
    return photoPath;
  }

  @override
  Future<String> keep(String path, String id) async => path;
}
