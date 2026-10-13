import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Дополнительные цвета темы: статусы справок, зачёт и экзамен.
///
/// В M3 нет ролей «ожидает» и «одобрено», поэтому они заведены по правилам
/// custom colors (https://m3.material.io/styles/color/advanced; MDC
/// `docs/theming/Color.md` → Custom Colors, Color Harmonization): опорный цвет
/// гармонизируется с primary схемы (`Blend.harmonize`), из его тональной
/// палитры (акцентная палитра: тон источника, хрома не ниже 48) берутся четыре роли теми же тонами,
/// что у акцентных ролей: светлая тема — 40 / 100 / 90 / 30, тёмная —
/// 80 / 20 / 30 / 90. «Отклонено» — это ошибка, для неё роли error.
///
/// Опорные цвета — оттенки статусов из макета.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.pending,
    required this.onPending,
    required this.approved,
    required this.onApproved,
    required this.rejected,
    required this.onRejected,
    required this.exam,
    required this.onExam,
  });

  /// Контейнер и текст статуса «В обработке».
  final Color pending;
  final Color onPending;

  /// Контейнер и текст статуса «Одобрено».
  final Color approved;
  final Color onApproved;

  /// Контейнер и текст статуса «Отклонено».
  final Color rejected;
  final Color onRejected;

  /// Контейнер и текст метки «Экзамен».
  final Color exam;
  final Color onExam;

  /// Опорный цвет «В обработке» (янтарный из макета).
  static const Color pendingSource = Color(0xFFFFE1A6);

  /// Опорный цвет «Одобрено» (зелёный из макета).
  static const Color approvedSource = Color(0xFFBFF0D2);

  /// Опорный цвет «Экзамен» — тёплый красно-оранжевый. Роли `error` для него
  /// не годятся: экзамен не ошибка, а гайдлайн отводит error под ошибки.
  static const Color examSource = Color(0xFFFFCDBE);

  factory StatusColors.fromScheme(ColorScheme scheme) {
    final bool light = scheme.brightness == Brightness.light;
    (Color, Color) roles(Color source) {
      final int harmonized = Blend.harmonize(
        source.toARGB32(),
        scheme.primary.toARGB32(),
      );
      // Акцентная палитра опорного цвета — как primary у `CorePalette.of`:
      // тон источника, хрома не ниже 48.
      final Hct hct = Hct.fromInt(harmonized);
      final TonalPalette palette = TonalPalette.of(
        hct.hue,
        math.max(48, hct.chroma),
      );
      return light
          ? (Color(palette.get(90)), Color(palette.get(30)))
          : (Color(palette.get(30)), Color(palette.get(90)));
    }

    final (Color pending, Color onPending) = roles(pendingSource);
    final (Color approved, Color onApproved) = roles(approvedSource);
    final (Color exam, Color onExam) = roles(examSource);
    return StatusColors(
      pending: pending,
      onPending: onPending,
      approved: approved,
      onApproved: onApproved,
      rejected: scheme.errorContainer,
      onRejected: scheme.onErrorContainer,
      exam: exam,
      onExam: onExam,
    );
  }

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ??
      StatusColors.fromScheme(Theme.of(context).colorScheme);

  @override
  StatusColors copyWith({
    Color? pending,
    Color? onPending,
    Color? approved,
    Color? onApproved,
    Color? rejected,
    Color? onRejected,
    Color? exam,
    Color? onExam,
  }) {
    return StatusColors(
      pending: pending ?? this.pending,
      onPending: onPending ?? this.onPending,
      approved: approved ?? this.approved,
      onApproved: onApproved ?? this.onApproved,
      rejected: rejected ?? this.rejected,
      onRejected: onRejected ?? this.onRejected,
      exam: exam ?? this.exam,
      onExam: onExam ?? this.onExam,
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
      exam: Color.lerp(exam, other.exam, t)!,
      onExam: Color.lerp(onExam, other.onExam, t)!,
    );
  }
}
