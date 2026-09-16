import 'models/certificate.dart';

/// Демо-данные вкладки «Пропуски».
///
/// Источника для пропусков и справок у МИТСО нет: apps.mitso.by отдаёт только
/// расписание, а student.mitso.by — лицевой счёт с балансом оплаты. Пока
/// источник не найден, вкладка показывает эти значения из макета.
abstract final class AbsencesDemoData {
  static const String syncStatus = 'Демо-данные · источник не подключён';

  /// Пропущено часов всего.
  static const int missedHours = 14;

  /// Допустимый лимит пропусков.
  static const int missedLimitHours = 40;

  /// Из них оправдано справками.
  static const int justifiedHours = 8;

  /// Из них без справки.
  static const int unjustifiedHours = 6;

  static const List<Certificate> certificates = [
    Certificate(
      id: '1',
      title: 'ОРВИ, справка №1042',
      period: '12 — 15 сентября · 8 ч',
      status: CertificateStatus.pending,
      note: 'Отправлено 15 сент, 18:24',
    ),
    Certificate(
      id: '2',
      title: 'Соревнования по волейболу',
      period: '2 — 4 сентября · 6 ч',
      status: CertificateStatus.approved,
      note: 'Проверено куратором',
    ),
    Certificate(
      id: '3',
      title: 'Фото справки от 28 августа',
      period: '28 августа · 4 ч',
      status: CertificateStatus.rejected,
      note: 'Причина: нечитаемое фото',
    ),
  ];
}
