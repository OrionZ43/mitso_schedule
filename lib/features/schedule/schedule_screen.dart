import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_data.dart';
import '../../data/models/lesson.dart';
import '../../state/schedule_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/day_selector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lesson_card.dart';
import '../../widgets/m3_pull_to_refresh.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScheduleDay day = ref.watch(selectedDayProvider);
    final int selectedIndex = ref.watch(selectedDayIndexProvider);
    final List<ScheduleDay> week = ref.watch(weekProvider);

    return M3PullToRefresh(
      onRefresh: ref.read(scheduleRefreshProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const _ScheduleAppBar(),
          const SliverToBoxAdapter(child: _ScheduleSearchBar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: DaySelector(
                days: week,
                selectedIndex: selectedIndex,
                onSelected: ref.read(selectedDayIndexProvider.notifier).select,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _DayHeading(day: day)),
          if (day.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(title: 'Занятий нет.\nОтдыхай!'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: day.lessons.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    LessonCard(lesson: day.lessons[index]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Medium flexible app bar из M3 Expressive: заголовок, подзаголовок и аватар.
///
/// Medium и large app bar в MDC объявлены устаревшими (TopAppBar.md), им на
/// смену пришли flexible-варианты. Токены `md.comp.app-bar.medium-flexible`:
/// развёрнутая высота 112dp, заголовок `headlineMedium`, подзаголовок
/// `labelLarge` цвета `onSurfaceVariant` под заголовком. Свёрнутое состояние —
/// small app bar 64dp (`titleLarge` / `labelMedium`). Отступы —
/// `m3_appbar_expanded_title_margin_horizontal` / `_bottom`: 16dp.
class _ScheduleAppBar extends StatelessWidget {
  const _ScheduleAppBar();

  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    final TextStyle expandedTitle = context.text.headlineMedium!.emphasized;
    final TextStyle collapsedTitle = context.text.titleLarge!.emphasized;
    final TextStyle expandedSubtitle = context.text.labelLarge!.copyWith(
      color: colors.onSurfaceVariant,
    );
    final TextStyle collapsedSubtitle = context.text.labelMedium!.copyWith(
      color: colors.onSurfaceVariant,
    );

    // Высота блока «заголовок + подзаголовок» при текущем масштабе шрифта.
    double blockHeight(TextStyle title, TextStyle subtitle) =>
        scaler.scale(title.fontSize!) * title.height! +
        scaler.scale(subtitle.fontSize!) * subtitle.height!;

    final double collapsedBlock = blockHeight(
      collapsedTitle,
      collapsedSubtitle,
    );
    final double expandedBlock = blockHeight(expandedTitle, expandedSubtitle);

    // 64 / 112dp по токенам; при крупном системном шрифте растут с текстом.
    final double collapsed = math.max(64, collapsedBlock + 2 * 8);
    final double expanded = math.max(112, expandedBlock + 2 * _margin + 24);

    return SliverAppBar(
      pinned: true,
      expandedHeight: expanded,
      collapsedHeight: collapsed,
      toolbarHeight: collapsed,
      backgroundColor: colors.surface,
      actions: const [
        _ProfileAvatar(),
        SizedBox(width: _margin),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // 0 — свёрнута, 1 — развёрнута полностью.
          final double t =
              ((constraints.maxHeight - collapsed) / (expanded - collapsed))
                  .clamp(0.0, 1.0);

          final TextStyle title = TextStyle.lerp(
            collapsedTitle,
            expandedTitle,
            t,
          )!;
          final TextStyle subtitle = TextStyle.lerp(
            collapsedSubtitle,
            expandedSubtitle,
            t,
          )!;

          // Свёрнутая: блок по центру 64dp. Развёрнутая: прижат к низу с
          // отступом 16dp.
          final double collapsedBottom = (collapsed - collapsedBlock) / 2;
          final double bottom =
              collapsedBottom + (_margin - collapsedBottom) * t;

          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: _margin,
              // Место под аватар справа.
              end: 72,
              bottom: bottom,
            ),
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Расписание',
                      style: title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    MockData.headerDate,
                    style: subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Semantics(
      label: 'Профиль: ${MockData.profile.name}',
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(
          child: Text(
            MockData.profile.initials,
            style: context.text.labelLarge!.emphasized.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка поиска по группам, преподавателям и аудиториям.
class _ScheduleSearchBar extends ConsumerWidget {
  const _ScheduleSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
      child: SearchAnchor.bar(
        barHintText: MockData.searchHint,
        barLeading: const Icon(Symbols.search),
        barTrailing: const [
          Tooltip(message: 'Голосовой поиск', child: Icon(Symbols.mic)),
        ],
        viewHintText: MockData.searchHint,
        suggestionsBuilder: (context, controller) => _suggestions(context, ref),
      ),
    );
  }

  List<Widget> _suggestions(BuildContext context, WidgetRef ref) {
    final String? selected = ref.watch(searchFilterProvider);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String filter in MockData.searchFilters)
              FilterChip(
                label: Text(filter),
                selected: selected == filter,
                onSelected: (_) =>
                    ref.read(searchFilterProvider.notifier).toggle(filter),
              ),
          ],
        ),
      ),
      const Divider(indent: 18, endIndent: 18, height: 22),
      for (final entry in MockData.recentSearches)
        ListTile(
          leading: const Icon(Symbols.history),
          title: Text(entry.label, style: context.text.bodyLarge),
          trailing: Text(
            entry.kind,
            style: context.text.labelMedium!.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          shape: AppShapes.rounded(AppShapes.largeIncreased),
          onTap: () {},
        ),
    ];
  }
}

/// Название дня и сводка по парам.
class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day});

  final ScheduleDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            day.title,
            style: context.text.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            day.summary,
            style: context.text.labelMedium!.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
