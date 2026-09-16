import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mitso/mitso_client.dart';
import '../../data/models/group_ref.dart';
import '../../data/models/lesson.dart';
import '../../state/mitso_providers.dart';
import '../../state/schedule_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../widgets/day_selector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lesson_card.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/m3_pager.dart';
import '../../widgets/m3_pull_to_refresh.dart';
import '../group_picker/group_picker_sheet.dart';
import 'lesson_details_page.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GroupRef? group = ref.watch(selectedGroupProvider);
    final AsyncValue<ScheduleState?> schedule = ref.watch(
      scheduleControllerProvider,
    );
    final DateTime now = ref.watch(nowProvider);
    final ScheduleState? data = schedule.value;

    final List<Widget> body;
    if (group == null) {
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: 'Выберите группу',
            description:
                'Расписание загружается с сайта МИТСО — apps.mitso.by.',
            action: FilledButton(
              onPressed: () => showGroupPicker(context),
              child: const Text('Выбрать группу'),
            ),
          ),
        ),
      ];
    } else if (data != null) {
      body = _scheduleSlivers(context, ref, data, now);
    } else if (schedule.hasError) {
      final Object error = schedule.error!;
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: 'Не удалось загрузить расписание',
            description: error is MitsoException
                ? error.message
                : 'Проверьте подключение к интернету.',
            action: FilledButton.tonal(
              onPressed: () => ref.invalidate(scheduleControllerProvider),
              child: const Text('Повторить'),
            ),
          ),
        ),
      ];
    } else {
      // Первая загрузка без сохранённых данных — короткое ожидание.
      body = const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: M3LoadingIndicator(semanticsLabel: 'Загрузка расписания'),
          ),
        ),
      ];
    }

    return M3PullToRefresh(
      onRefresh: ref.read(scheduleControllerProvider.notifier).refresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _ScheduleAppBar(now: now, group: group),
          ...body,
        ],
      ),
    );
  }

  List<Widget> _scheduleSlivers(
    BuildContext context,
    WidgetRef ref,
    ScheduleState data,
    DateTime now,
  ) {
    final List<ScheduleDay> days = data.days;
    final ScheduleDay? day = resolveSelectedDay(
      days,
      ref.watch(selectedDateProvider),
      now,
    );

    return [
      if (data.refreshError != null)
        SliverToBoxAdapter(
          child: _RefreshErrorBanner(
            error: data.refreshError!,
            fetchedAt: data.fetchedAt,
            onRetry: ref.read(scheduleControllerProvider.notifier).refresh,
          ),
        ),
      SliverToBoxAdapter(child: _ScheduleSearchBar(days: days)),
      if (day == null)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: 'На сайте пока нет расписания'),
        )
      else ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DaySelector(
              days: days,
              selectedIndex: days.indexOf(day),
              onSelected: (index) => ref
                  .read(selectedDateProvider.notifier)
                  .select(days[index].date),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverToBoxAdapter(
            child: _DayPager(
              days: days,
              selectedIndex: days.indexOf(day),
              now: now,
              onPageChanged: (index) => ref
                  .read(selectedDateProvider.notifier)
                  .select(days[index].date),
            ),
          ),
        ),
      ],
    ];
  }
}

/// Дни — равноправные страницы одного уровня, поэтому смена дня — паттерн
/// **lateral**: https://m3.material.io/styles/motion/transitions. Страницы
/// едут вместе и следуют за пальцем, без затухания («Fading content as it
/// slides makes the peer relationship and swipe gesture less obvious»).
///
/// Выбор дня в ленте или в поиске перелистывает pager как
/// `PagerState.animateScrollToPage` в Compose.
class _DayPager extends StatefulWidget {
  const _DayPager({
    required this.days,
    required this.selectedIndex,
    required this.now,
    required this.onPageChanged,
  });

  final List<ScheduleDay> days;
  final int selectedIndex;
  final DateTime now;
  final ValueChanged<int> onPageChanged;

  @override
  State<_DayPager> createState() => _DayPagerState();
}

class _DayPagerState extends State<_DayPager> {
  late final PageController _controller = PageController(
    initialPage: widget.selectedIndex,
  );

  @override
  void didUpdateWidget(_DayPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) return;
    final double page = _controller.page ?? widget.selectedIndex.toDouble();
    // Страница уже сменилась жестом — pager сам на месте.
    if (page.round() == widget.selectedIndex) return;
    M3Pager.animateToPage(
      _controller,
      widget.selectedIndex,
      reduceMotion: reduceMotionOf(context),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpandablePageView(
      controller: _controller,
      itemCount: widget.days.length,
      minHeight: 240,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) => _DayContent(
        day: widget.days[index],
        days: widget.days,
        now: widget.now,
      ),
    );
  }
}

/// Заголовок дня и его пары.
class _DayContent extends ConsumerWidget {
  const _DayContent({required this.day, required this.days, required this.now});

  final ScheduleDay day;
  final List<ScheduleDay> days;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? subgroup = ref.watch(
      settingsControllerProvider.select((s) => s.subgroup),
    );
    final List<LessonSlot> slots = day.slots(subgroup: subgroup);
    final List<SlotStatus> statuses = slotTimings(slots, day.date, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayHeading(day: day, slots: slots, now: now),
        if (slots.isEmpty)
          const EmptyState(title: 'Занятий нет.\nОтдыхай!')
        else
          for (int i = 0; i < slots.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: LessonCard<DateTime>(
                slot: slots[i],
                timing: statuses[i].timing,
                progress: statuses[i].progress,
                startsInMinutes: statuses[i].startsIn,
                details: (context, close) => LessonDetailsPage(
                  slot: slots[i],
                  day: day,
                  days: days,
                  status: statuses[i],
                  subgroup: subgroup,
                  close: close,
                ),
                // Переход к другому дню — после обратной анимации, чтобы
                // карточка успела свернуться на своё место.
                onClosed: (date) {
                  if (date != null) {
                    ref.read(selectedDateProvider.notifier).select(date);
                  }
                },
              ),
            ),
      ],
    );
  }
}

/// Medium flexible app bar из M3 Expressive: заголовок, подзаголовок и кнопка
/// выбора группы.
///
/// Medium и large app bar в MDC объявлены устаревшими (TopAppBar.md), им на
/// смену пришли flexible-варианты. Токены `md.comp.app-bar.medium-flexible`:
/// развёрнутая высота 112dp, заголовок `headlineMedium`, подзаголовок
/// `labelLarge` цвета `onSurfaceVariant` под заголовком. Свёрнутое состояние —
/// small app bar 64dp (`titleLarge` / `labelMedium`). Отступы —
/// `m3_appbar_expanded_title_margin_horizontal` / `_bottom`: 16dp.
class _ScheduleAppBar extends StatelessWidget {
  const _ScheduleAppBar({required this.now, required this.group});

  final DateTime now;
  final GroupRef? group;

  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    final String subtitle = group == null
        ? 'Группа не выбрана'
        : '${group!.groupName} · ${group!.courseName}';

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
      actions: [
        IconButton.filledTonal(
          onPressed: () => showGroupPicker(context),
          icon: const Icon(Symbols.groups),
          tooltip: group == null ? 'Выбрать группу' : 'Сменить группу',
        ),
        const SizedBox(width: _margin - 4),
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
          final TextStyle sub = TextStyle.lerp(
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
              // Место под кнопку группы справа.
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
                    subtitle,
                    style: sub,
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

/// Обновление не удалось, но есть сохранённое расписание.
class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({
    required this.error,
    required this.fetchedAt,
    required this.onRetry,
  });

  final MitsoException error;
  final DateTime fetchedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String saved = DateFormat('d MMMM, HH:mm', 'ru').format(fetchedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: colors.errorContainer,
        borderRadius: AppShapes.all(AppShapes.large),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Symbols.cloud_off, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${error.message} Показано сохранённое от $saved.',
                  style: context.text.bodyMedium!.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: colors.onErrorContainer,
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Поиск по загруженному расписанию: предметы, преподаватели, аудитории.
class _ScheduleSearchBar extends ConsumerWidget {
  const _ScheduleSearchBar({required this.days});

  final List<ScheduleDay> days;

  static const String _hint = 'Поиск предмета, препода, аудитории';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
      child: SearchAnchor.bar(
        barHintText: _hint,
        barLeading: const Icon(Symbols.search),
        viewHintText: _hint,
        suggestionsBuilder: (context, controller) =>
            _suggestions(context, ref, controller),
      ),
    );
  }

  List<Widget> _suggestions(
    BuildContext context,
    WidgetRef ref,
    SearchController controller,
  ) {
    final ScheduleSearchField field = ref.watch(searchFieldProvider);
    final String query = controller.text.trim().toLowerCase();

    String? valueOf(Lesson lesson) => switch (field) {
      ScheduleSearchField.subject => lesson.title,
      ScheduleSearchField.teacher => lesson.teacher,
      ScheduleSearchField.room => lesson.room,
    };

    // Подгруппы одной пары с тем же предметом — одна строка результата.
    final Set<String> seen = {};
    final List<(ScheduleDay, Lesson)> matches = [
      if (query.isNotEmpty)
        for (final ScheduleDay day in days)
          for (final Lesson lesson in day.lessons)
            if ((valueOf(lesson)?.toLowerCase().contains(query) ?? false) &&
                seen.add(
                  '${day.date}|${lesson.start}|${lesson.title}|${valueOf(lesson)}',
                ))
              (day, lesson),
    ];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ScheduleSearchField value in ScheduleSearchField.values)
              FilterChip(
                label: Text(value.label),
                selected: field == value,
                onSelected: (_) =>
                    ref.read(searchFieldProvider.notifier).select(value),
              ),
          ],
        ),
      ),
      const Divider(indent: 18, endIndent: 18, height: 22),
      if (query.isEmpty)
        const _SearchHint(text: 'Ищет по неделям, загруженным с сайта.')
      else if (matches.isEmpty)
        const _SearchHint(text: 'Ничего не найдено.')
      else
        for (final (ScheduleDay day, Lesson lesson) in matches)
          ListTile(
            leading: const Icon(Symbols.event),
            title: Text(lesson.title, style: context.text.bodyLarge),
            subtitle: Text(
              [
                '${day.shortName}, ${DateFormat('d MMMM', 'ru').format(day.date)} · ${lesson.start}',
                ?lesson.teacher,
                if (lesson.room != null) roomLabel(lesson.room!),
              ].join(' · '),
            ),
            shape: AppShapes.rounded(AppShapes.largeIncreased),
            onTap: () {
              ref.read(selectedDateProvider.notifier).select(day.date);
              controller.closeView(null);
            },
          ),
    ];
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        text,
        style: context.text.bodyMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Название дня и сводка по парам: «Сегодня / среда, 16 сентября» слева,
/// «4 пары / 08:15—14:25» справа.
class _DayHeading extends StatelessWidget {
  const _DayHeading({
    required this.day,
    required this.slots,
    required this.now,
  });

  final ScheduleDay day;
  final List<LessonSlot> slots;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String date = DateFormat('d MMMM', 'ru').format(day.date);
    final String? relative = relativeDayName(day.date, now);

    final TextStyle secondary = context.text.bodyMedium!.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        runSpacing: 4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  relative ?? day.title,
                  style: context.text.titleLarge!.emphasized,
                ),
              ),
              Text(
                relative != null ? '${day.title.toLowerCase()}, $date' : date,
                style: secondary,
              ),
            ],
          ),
          if (slots.isEmpty)
            Text('Выходной', style: secondary)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${slots.length} ${ScheduleDay.pairsWord(slots.length)}',
                  style: context.text.titleSmall,
                ),
                Text(
                  '${slots.first.start}—${slots.last.end}',
                  style: secondary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// «Сегодня», «Завтра», «Вчера» или `null` для остальных дней.
String? relativeDayName(DateTime date, DateTime now) {
  // Через UTC: разница в днях не должна зависеть от перевода часов.
  final int diff = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  return switch (diff) {
    0 => 'Сегодня',
    1 => 'Завтра',
    -1 => 'Вчера',
    _ => null,
  };
}
