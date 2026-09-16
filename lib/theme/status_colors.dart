import 'package:flutter/material.dart';

/// Цвета статусов справок.
///
/// В M3 нет ролей `warning`/`success`, поэтому они заведены как расширение
/// темы, а не хардкодятся в виджетах. Значения взяты из макета
/// (`STATUS` в `Расписание - Material 3 Expressive.dc.html`); контраст текста
/// к своему контейнеру >= 4.5:1 в обеих темах — см. `test/status_contrast_test.dart`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.pending,
    required this.onPending,
    required this.approved,
    required this.onApproved,
    required this.rejected,
    required this.onRejected,
  });

  final Color pending;
  final Color onPending;
  final Color approved;
  final Color onApproved;
  final Color rejected;
  final Color onRejected;

  static const StatusColors light = StatusColors(
    pending: Color(0xFFFFE1A6),
    onPending: Color(0xFF4E3900),
    approved: Color(0xFFBFF0D2),
    onApproved: Color(0xFF0A4B2C),
    rejected: Color(0xFFFFDAD6),
    onRejected: Color(0xFF7A1B14),
  );

  static const StatusColors dark = StatusColors(
    pending: Color(0xFF5A4200),
    onPending: Color(0xFFFFE1A6),
    approved: Color(0xFF0D4E2E),
    onApproved: Color(0xFFA9E9C5),
    rejected: Color(0xFF6E1710),
    onRejected: Color(0xFFFFB4AB),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({
    Color? pending,
    Color? onPending,
    Color? approved,
    Color? onApproved,
    Color? rejected,
    Color? onRejected,
  }) {
    return StatusColors(
      pending: pending ?? this.pending,
      onPending: onPending ?? this.onPending,
      approved: approved ?? this.approved,
      onApproved: onApproved ?? this.onApproved,
      rejected: rejected ?? this.rejected,
      onRejected: onRejected ?? this.onRejected,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      pending: Color.lerp(pending, other.pending, t)!,
      onPending: Color.lerp(onPending, other.onPending, t)!,
      approved: Color.lerp(approved, other.approved, t)!,
      onApproved: Color.lerp(onApproved, other.onApproved, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      onRejected: Color.lerp(onRejected, other.onRejected, t)!,
    );
  }
}
