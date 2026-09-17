import 'package:flutter/foundation.dart';

/// Статус справки о пропуске.
///
/// Пока Telegram-бот не подключён, справки только сохраняются в приложении
/// ([notSent]); остальные статусы будет присылать бот.
enum CertificateStatus {
  notSent('Не отправлено'),
  pending('В обработке'),
  approved('Одобрено'),
  rejected('Отклонено');

  const CertificateStatus(this.label);

  final String label;
}

/// Зарегистрированная справка: фото и когда её сохранили.
@immutable
class Certificate {
  const Certificate({
    required this.id,
    required this.photoPath,
    required this.createdAt,
    this.status = CertificateStatus.notSent,
  });

  final String id;

  /// Фото справки в файлах приложения.
  final String photoPath;

  final DateTime createdAt;
  final CertificateStatus status;

  Map<String, Object?> toJson() => {
    'id': id,
    'photoPath': photoPath,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory Certificate.fromJson(Map<String, Object?> json) => Certificate(
    id: json['id']! as String,
    photoPath: json['photoPath']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    status: CertificateStatus.values.byName(json['status']! as String),
  );
}

/// Сводка пропусков в часах.
@immutable
class AbsenceSummary {
  const AbsenceSummary({
    required this.justifiedHours,
    required this.unjustifiedHours,
  });

  /// Пропуски, закрытые справками.
  final int justifiedHours;

  /// Пропуски без справки.
  final int unjustifiedHours;

  int get missedHours => justifiedHours + unjustifiedHours;
}
