import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/absences_demo_data.dart';
import '../../data/models/certificate.dart';
import '../../state/absences_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/status_colors.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import 'widgets/absence_donut.dart';

class AbsencesScreen extends ConsumerWidget {
  const AbsencesScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Certificate> certificates = ref.watch(
      absencesControllerProvider,
    );
    final double margin = AppSpacing.screenMargin(context);

    return M3AppBarSettle(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          const SliverMediumFlexibleAppBar(
            title: 'Пропуски',
            subtitle: AbsencesDemoData.syncStatus,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            sliver: SliverList.list(
              children: [
                const _SummaryCard(),
                const SectionHeader('Мои справки'),
                SegmentedList(
                  children: [
                    for (final Certificate certificate in certificates)
                      _certificateItem(context, certificate),
                  ],
                ),
                // Место под extended FAB, чтобы он не закрывал последний пункт.
                const SizedBox(
                  height: AppSpacing.space900 + AppSpacing.space300,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Справка — пункт списка. Статус передаётся и цветом аватара, и текстом
  /// (lists → Accessibility: «Indicate selection with more than color»).
  M3ListItem _certificateItem(BuildContext context, Certificate certificate) {
    final StatusColors status = StatusColors.of(context);
    final (
      Color container,
      Color content,
      IconData icon,
    ) = switch (certificate.status) {
      CertificateStatus.pending => (
        status.pending,
        status.onPending,
        Symbols.schedule,
      ),
      CertificateStatus.approved => (
        status.approved,
        status.onApproved,
        Symbols.check,
      ),
      CertificateStatus.rejected => (
        status.rejected,
        status.onRejected,
        Symbols.close,
      ),
    };

    return M3ListItem(
      // Аватар пункта: 40dp, пара «контейнер / on-контейнер»
      // (`ListTokens.ItemLeadingAvatar*`).
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: container, shape: BoxShape.circle),
        child: Icon(icon, color: content),
      ),
      overline: Text(certificate.status.label),
      headline: Text(certificate.title),
      supporting: Text('${certificate.period}\n${certificate.note}'),
      semanticsLabel:
          '${certificate.title}. ${certificate.status.label}. '
          '${certificate.period}. ${certificate.note}',
    );
  }
}

/// Сводка: кольцевая диаграмма и легенда в filled card
/// (`FilledCardTokens`: surfaceContainerHighest, 12dp, без тени).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          children: [
            const AbsenceDonut(
              missedHours: AbsencesDemoData.missedHours,
              justifiedHours: AbsencesDemoData.justifiedHours,
              unjustifiedHours: AbsencesDemoData.unjustifiedHours,
              limitHours: AbsencesDemoData.missedLimitHours,
            ),
            const SizedBox(height: AppSpacing.space200),
            Row(
              children: [
                Expanded(
                  child: _Legend(
                    color: colors.tertiary,
                    value: '${AbsencesDemoData.justifiedHours} ч',
                    label: 'оправдано',
                  ),
                ),
                const SizedBox(width: AppSpacing.space150),
                Expanded(
                  child: _Legend(
                    color: colors.primary,
                    value: '${AbsencesDemoData.unjustifiedHours} ч',
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
