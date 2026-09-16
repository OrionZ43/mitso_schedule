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

/// Large top app bar: дата, заголовок и аватар.
///
/// Высоты — по спеке M3: развёрнутая 152dp, свёрнутая 64dp.
/// https://m3.material.io/components/top-app-bar/specs
class _ScheduleAppBar extends StatelessWidget {
  const _ScheduleAppBar();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 152,
      collapsedHeight: 64,
      toolbarHeight: 64,
      backgroundColor: context.colors.surface,
      actions: const [_ProfileAvatar(), SizedBox(width: 16)],
      flexibleSpace: FlexibleSpaceBar(
        // Заголовок не масштабируется: в макете он одного размера в обоих
        // состояниях, меняется только положение.
        expandedTitleScale: 1.0,
        titlePadding: const EdgeInsets.only(left: 22, right: 72, bottom: 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MockData.headerDate,
              style: context.text.labelLarge!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('Расписание', style: context.text.headlineMedium!.emphasized),
          ],
        ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
