import 'package:flutter/foundation.dart';

/// Статус справки об оправдании пропуска.
enum CertificateStatus {
  pending('В обработке'),
  approved('Одобрено'),
  rejected('Отклонено');

  const CertificateStatus(this.label);

  final String label;
}

@immutable
class Certificate {
  const Certificate({
    required this.id,
    required this.title,
    required this.period,
    required this.status,
    required this.note,
  });

  final String id;
  final String title;

  /// Период и количество часов: `12 — 15 сентября · 8 ч`.
  final String period;

  final CertificateStatus status;

  /// Пояснение под карточкой: `Отправлено 15 сент, 18:24`.
  final String note;
}
