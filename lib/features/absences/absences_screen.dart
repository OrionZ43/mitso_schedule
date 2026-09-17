import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/certificate.dart';
import '../../state/absences_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import 'widgets/absence_donut.dart';

class AbsencesScreen extends ConsumerWidget {
  const AbsencesScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  /// Место под extended FAB, чтобы он не закрывал последний пункт.
  static const double fabClearance = AppSpacing.space900 + AppSpacing.space300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Certificate> certificates = ref.watch(
      absencesControllerProvider,
    );
    final AbsenceSummary? summary = ref.watch(absenceSummaryProvider);
    final double margin = AppSpacing.screenMargin(context);

    return M3AppBarSettle(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverMediumFlexibleAppBar(
            title: 'Пропуски',
            // Статус источника: сводку будет присылать Telegram-бот.
            subtitle: summary == null ? 'Telegram-бот не подключён' : null,
          ),
          if (summary == null && certificates.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: fabClearance),
                child: EmptyState(
                  title: 'Справок пока нет',
                  description:
                      'Сфотографируй справку — она сохранится здесь. '
                      'Статистика пропусков появится, когда подключится '
                      'Telegram-бот.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              sliver: SliverList.list(
                children: [
                  if (summary != null) _SummaryCard(summary: summary),
                  if (certificates.isNotEmpty) ...[
                    const SectionHeader('Мои справки'),
                    SegmentedList(
                      children: [
                        for (final Certificate certificate in certificates)
                          _certificateItem(context, certificate),
                      ],
                    ),
                  ],
                  const SizedBox(height: fabClearance),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Справка — пункт списка с фото и статусом текстом.
  M3ListItem _certificateItem(BuildContext context, Certificate certificate) {
    final String saved = DateFormat(
      "d MMMM, HH:mm",
      'ru',
    ).format(certificate.createdAt);

    return M3ListItem(
      leading: CertificateThumbnail(path: certificate.photoPath),
      overline: Text(certificate.status.label),
      headline: const Text('Справка'),
      supporting: Text('Сохранена $saved'),
      semanticsLabel: 'Справка. ${certificate.status.label}. Сохранена $saved',
    );
  }
}

/// Миниатюра фото справки — leading image пункта списка
/// (`md.comp.list.list-item.leading-image`: 56dp, expressive-форма
/// `corner.small`).
class CertificateThumbnail extends StatelessWidget {
  const CertificateThumbnail({super.key, required this.path});

  final String path;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    // Декодируем сразу в размер миниатюры, а не в полный снимок.
    final int cacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppShapes.small),
      child: SizedBox.square(
        dimension: size,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Icon(Symbols.image, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Сводка: кольцевая диаграмма и легенда в filled card
/// (`FilledCardTokens`: surfaceContainerHighest, 12dp, без тени).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final AbsenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          children: [
            AbsenceDonut(
              justifiedHours: summary.justifiedHours,
              unjustifiedHours: summary.unjustifiedHours,
            ),
            const SizedBox(height: AppSpacing.space200),
            Row(
              children: [
                Expanded(
                  child: _Legend(
                    color: colors.tertiary,
                    value: '${summary.justifiedHours} ч',
                    label: 'по справке',
                  ),
                ),
                const SizedBox(width: AppSpacing.space150),
                Expanded(
                  child: _Legend(
                    color: colors.primary,
                    value: '${summary.unjustifiedHours} ч',
                    label: 'без справки',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.space75),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: AppSpacing.space100),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: context.text.titleMedium),
              Text(
                label,
                style: context.text.bodySmall!.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
