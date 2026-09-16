import 'package:flutter/material.dart';

import '../data/models/certificate.dart';
import '../data/models/lesson.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/status_colors.dart';

/// Бейдж типа занятия на карточке пары.
class LessonTypeBadge extends StatelessWidget {
  const LessonTypeBadge({
    super.key,
    required this.type,
    required this.label,
    this.onPrimarySurface = false,
  });

  final LessonType type;

  /// Подпись: «Лекция», «Лаб» или сокращение с сайта для прочих типов.
  final String label;

  /// Карточка текущей пары залита `primary` — бейдж становится полупрозрачным.
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final StatusColors status = StatusColors.of(context);

    final (Color background, Color foreground) = onPrimarySurface
        ? (colors.onPrimary.withValues(alpha: 0.22), colors.onPrimary)
        : switch (type) {
            LessonType.lecture => (
              colors.primaryContainer,
              colors.onPrimaryContainer,
            ),
            LessonType.practice => (status.approved, status.onApproved),
            LessonType.lab => (
              colors.tertiaryContainer,
              colors.onTertiaryContainer,
            ),
            LessonType.other => (
              colors.secondaryContainer,
              colors.onSecondaryContainer,
            ),
          };

    return _Badge(background: background, foreground: foreground, label: label);
  }
}

/// Бейдж статуса справки.
class CertificateStatusBadge extends StatelessWidget {
  const CertificateStatusBadge({super.key, required this.status});

  final CertificateStatus status;

  @override
  Widget build(BuildContext context) {
    final StatusColors colors = StatusColors.of(context);

    final (Color background, Color foreground) = switch (status) {
      CertificateStatus.pending => (colors.pending, colors.onPending),
      CertificateStatus.approved => (colors.approved, colors.onApproved),
      CertificateStatus.rejected => (colors.rejected, colors.onRejected),
    };

    return _Badge(
      background: background,
      foreground: foreground,
      label: status.label,
      height: 28,
      horizontalPadding: 12,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.background,
    required this.foreground,
    required this.label,
    this.height,
    this.horizontalPadding = 10,
  });

  final Color background;
  final Color foreground;
  final String label;
  final double? height;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        (height == null ? context.text.labelSmall : context.text.labelMedium)!
            .copyWith(color: foreground);

    // Высота задаётся минимумом, а не фиксируется: при масштабе шрифта
    // до 200% бейдж растёт вместе с текстом и ничего не обрезается.
    return Container(
      constraints: BoxConstraints(minHeight: height ?? 0),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.all(AppShapes.chip),
      ),
      // widthFactor: 1 — центрировать по вертикали, но по ширине остаться
      // по размеру текста: Container с alignment занял бы всю ширину.
      child: Center(widthFactor: 1, child: Text(label, style: style)),
    );
  }
}
