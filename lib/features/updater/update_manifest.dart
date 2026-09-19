import 'package:path/path.dart' as p;

/// Ключи файлов, которые бывают в релизе.
///
/// Android: сначала APK под архитектуру устройства, затем универсальный —
/// он ставится куда угодно, но весит больше. Windows пока в планах, ключ
/// оставлен, чтобы манифест не пришлось менять задним числом.
const List<String> kUpdateAssetKeys = <String>[
  'android-arm64-v8a',
  'android-armeabi-v7a',
  'android-x86_64',
  'android-universal',
  'windows-x64',
];

/// Один файл релиза: откуда качать, сколько весит и каким должен быть хэш.
class UpdateAsset {
  const UpdateAsset({
    required this.urls,
    required this.size,
    required this.sha256,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    final Object? rawUrls = json['urls'];
    if (rawUrls is! List || rawUrls.isEmpty) {
      throw const FormatException('У файла нет адресов');
    }
    final List<Uri> urls = <Uri>[];
    for (final Object? raw in rawUrls) {
      final Uri? uri = raw is String ? Uri.tryParse(raw) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw FormatException('Адрес файла должен быть https: $raw');
      }
      urls.add(uri);
    }

    final Object? size = json['size'];
    if (size is! int || size <= 0 || size > maxSize) {
      throw FormatException('Недопустимый размер файла: $size');
    }

    final Object? hash = json['sha256'];
    if (hash is! String || !_sha256Pattern.hasMatch(hash)) {
      throw FormatException('Недопустимый SHA-256: $hash');
    }

    return UpdateAsset(urls: urls, size: size, sha256: hash.toLowerCase());
  }

  /// Верхняя граница размера — защита от забивания диска.
  static const int maxSize = 1024 * 1024 * 1024;

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Адреса в порядке попытки; при сбое берётся следующий.
  final List<Uri> urls;

  final int size;

  /// SHA-256 в нижнем регистре.
  final String sha256;

  /// Имя для сохранения на диск: последний сегмент первого адреса, очищенный
  /// от всего, кроме букв, цифр, точки, дефиса и подчёркивания, — имя приходит
  /// из сети, и на диск не должны попадать `..` или разделители пути.
  String get fileName {
    final List<String> segments = urls.first.pathSegments;
    final String raw = segments.isEmpty ? '' : p.basename(segments.last);
    final String safe = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-\_]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') {
      return 'mitso-update.bin';
    }
    return safe;
  }
}

/// Манифест релиза: что вышло и откуда качать.
///
/// Публикуется в каждом GitHub Release внутри подписанной обёртки
/// `mitso-update.json` (см. `update_envelope.dart`):
///
/// ```json
/// {
///   "version": "1.1.0",
///   "build": 12,
///   "minSupportedBuild": 9,
///   "publishedAt": "2026-10-01T12:00:00Z",
///   "notes": "Что нового…",
///   "message": null,
///   "releaseUrl": "https://github.com/OrionZ43/mitso_schedule/releases/tag/v1.1.0",
///   "assets": {
///     "android-arm64-v8a": {"urls": ["https://…"], "size": 21000000, "sha256": "…"},
///     "android-universal": {"urls": ["https://…"], "size": 42000000, "sha256": "…"}
///   }
/// }
/// ```
///
/// `version` — только для показа пользователю, версии сравниваются по `build`
/// (`+N` из pubspec). Файл без импортов Flutter: его разбирает и
/// `tool/update_signing.dart`, который запускается обычным `dart run`.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.build,
    required this.minSupportedBuild,
    required this.notes,
    required this.assets,
    this.message,
    this.releaseUrl,
    this.publishedAt,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final Object? version = json['version'];
    if (version is! String || version.trim().isEmpty) {
      throw const FormatException('В манифесте нет версии');
    }

    final Object? build = json['build'];
    if (build is! int || build <= 0) {
      throw FormatException('Недопустимый номер сборки: $build');
    }

    final Object? minSupported = json['minSupportedBuild'] ?? 0;
    if (minSupported is! int || minSupported < 0) {
      throw FormatException('Недопустимый minSupportedBuild: $minSupported');
    }

    final Object? rawAssets = json['assets'];
    if (rawAssets is! Map) {
      throw const FormatException('В манифесте нет списка файлов');
    }
    final Map<String, UpdateAsset> assets = <String, UpdateAsset>{};
    rawAssets.forEach((Object? key, Object? value) {
      if (key is! String || value is! Map<String, dynamic>) {
        throw FormatException('Некорректное описание файла: $key');
      }
      assets[key] = UpdateAsset.fromJson(value);
    });

    final Object? notes = json['notes'];
    final Object? message = json['message'];
    final Uri? releaseUrl = json['releaseUrl'] is String
        ? Uri.tryParse(json['releaseUrl'] as String)
        : null;
    final DateTime? publishedAt = json['publishedAt'] is String
        ? DateTime.tryParse(json['publishedAt'] as String)
        : null;

    return UpdateManifest(
      version: version.trim(),
      build: build,
      minSupportedBuild: minSupported,
      notes: notes is String ? notes.trim() : '',
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : null,
      releaseUrl: releaseUrl != null && releaseUrl.scheme == 'https'
          ? releaseUrl
          : null,
      publishedAt: publishedAt,
      assets: Map<String, UpdateAsset>.unmodifiable(assets),
    );
  }

  /// Для показа пользователю: «1.1.0».
  final String version;

  /// Номер сборки — по нему и только по нему сравниваются версии.
  final int build;

  /// Ниже этой сборки обновление обязательное.
  final int minSupportedBuild;

  /// Что нового.
  final String notes;

  /// Объявление для всех; `null` — объявления нет.
  final String? message;

  /// Страница релиза — запасной путь, когда файла под платформу нет.
  final Uri? releaseUrl;

  final DateTime? publishedAt;

  /// Ключ платформы (`android-arm64-v8a`, `windows-x64`…) → файл.
  final Map<String, UpdateAsset> assets;

  /// Первый файл из [preferredKeys], который есть в релизе.
  UpdateAsset? assetFor(List<String> preferredKeys) {
    for (final String key in preferredKeys) {
      final UpdateAsset? asset = assets[key];
      if (asset != null) return asset;
    }
    return null;
  }
}
