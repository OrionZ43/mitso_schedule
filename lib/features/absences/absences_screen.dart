import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/absences_demo_data.dart';
import '../../data/models/certificate.dart';
import '../../state/absences_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/status_badge.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: M3AppBarSettle(
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            const SliverMediumFlexibleAppBar(
              title: 'Пропуски',
              subtitle: AbsencesDemoData.syncStatus,
            ),
            SliverList.list(
              children: [
                const SizedBox(height: 18),
                const _SummaryCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 12),
                  child: Text(
                    'Мои справки',
                    style: context.text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                for (final Certificate certificate in certificates)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _CertificateCard(certificate: certificate),
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

/// Карточка со статистикой: кольцевая диаграмма и легенда.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppShapes.all(AppShapes.extraLargeIncreased),
      ),
      child: Column(
        children: [
          const AbsenceDonut(
            missedHours: AbsencesDemoData.missedHours,
            justifiedHours: AbsencesDemoData.justifiedHours,
            unjustifiedHours: AbsencesDemoData.unjustifiedHours,
            limitHours: AbsencesDemoData.missedLimitHours,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _LegendTile(
                  color: colors.primaryContainer,
                  value: '${AbsencesDemoData.justifiedHours} ч',
                  label: 'оправдано',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LegendTile(
                  color: colors.primary,
                  value: '${AbsencesDemoData.unjustifiedHours} ч',
                  label: 'без справки',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppShapes.all(AppShapes.largeIncreased),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: context.text.titleMedium!.emphasized.copyWith(
                    fontSize: 15,
                  ),
                ),
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
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    final IconData icon = switch (certificate.status) {
      CertificateStatus.pending => Symbols.schedule,
      CertificateStatus.approved => Symbols.check_circle,
      CertificateStatus.rejected => Symbols.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        // Outlined card: фон surface, обводка outlineVariant.
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: AppShapes.all(AppShapes.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.title,
                      style: context.text.titleMedium!.emphasized.copyWith(
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      certificate.period,
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CertificateStatusBadge(status: certificate.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icon, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  certificate.note,
                  style: context.text.bodySmall!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
