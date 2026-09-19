import 'package:flutter/services.dart';
import 'package:mitso_schedule/data/photo_picker.dart';

/// Подстановка камеры и галереи: сразу «снимает» [photoPath], ничего не
/// копирует и не удаляет.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({
    this.photoPath = '/fake/certificate.jpg',
    this.failCapture = false,
  });

  String? photoPath;

  /// Имитировать недоступную камеру или галерею.
  final bool failCapture;

  final List<PhotoSource> captures = [];
  final List<String> kept = [];
  final List<String> discarded = [];

  @override
  Future<String?> pick(
    PhotoSource source, {
    double maxSide = 0,
    int quality = 0,
  }) async {
    captures.add(source);
    if (failCapture) throw PlatformException(code: 'no_available_camera');
    return photoPath;
  }

  @override
  Future<String> keep(
    String path, {
    required String folder,
    required String name,
  }) async {
    kept.add('$folder/$name');
    return path;
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}
