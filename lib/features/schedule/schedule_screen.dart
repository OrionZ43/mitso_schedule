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
import '../../theme/app_spacing.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../widgets/day_selector.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/m3_pager.dart';
import '../../widgets/m3_pull_to_refresh.dart';
import '../group_picker/group_picker_sheet.dart';
import '../home/home_shell.dart';
import 'lesson_details_page.dart';
import 'lesson_slot_item.dart';
import 'lesson_timing.dart';
import 'schedule_search.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// Обновление запущено кнопкой — индикатор pull-to-refresh выезжает и тогда
  /// (`PullToRefreshBox.isRefreshing`).
  bool _refreshingByButton = false;

  Future<void> _refreshByButton() async {
    if (_refreshingByButton) return;
    setState(() => _refreshingByButton = true);
    try {
      await ref.read(scheduleControllerProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _refreshingByButton = false);
    }
  }

  /// Обновление не удалось, но сохранённое расписание есть — сообщение со
  /// действием «Повторить» (snackbar → Usage: короткое сообщение о процессе,
  /// одно действие; в M3 нет баннеров).
  void _showRefreshError(ScheduleState state) {
    final String saved = DateFormat(
      'd MMMM, HH:mm',
      'ru',
    ).format(state.fetchedAt);
    appSnackbarHost.currentState?.show(
      '${state.refreshError!.message} Показано сохранённое от $saved.',
      actionLabel: 'Повторить',
      onAction: _refreshByButton,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scheduleControllerProvider, (previous, next) {
      final ScheduleState? state = next.value;
      if (state?.refreshError != null &&
          previous?.value?.refreshError != state!.refreshError) {
        _showRefreshError(state);
      }
    });
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
            action: M3Button(
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
            action: M3Button(
              onPressed: () => ref.invalidate(scheduleControllerProvider),
              color: M3ButtonColor.tonal,
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

    final bool hasSubtitle = group != null;
    return M3PullToRefresh(
      onRefresh: ref.read(scheduleControllerProvider.notifier).refresh,
      isRefreshing: _refreshingByButton,
      // Индикатор выезжает из-под развёрнутого app bar: тянуть можно только
      // от самого верха списка.
      edgeOffset:
          MediaQuery.paddingOf(context).top +
          (hasSubtitle
              ? SliverMediumFlexibleAppBar.expandedHeightWithSubtitle
              : SliverMediumFlexibleAppBar.expandedHeight),
      child: M3AppBarSettle(
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverMediumFlexibleAppBar(
              title: 'Расписание',
              subtitle: group == null
                  ? null
                  : '${group.groupName} · ${group.courseName}',
              actions: [
                // Альтернатива жесту pull-to-refresh — гайдлайн loading
                // indicator, Accessibility.
                if (group != null)
                  M3IconButton(
                    onPressed: _refreshingByButton ? null : _refreshByButton,
                    icon: const Icon(Symbols.refresh),
                    color: M3IconButtonColor.standard,
                    tooltip: 'Обновить',
                  ),
                // Одна trailing-кнопка может быть tonal (app bars → Usage).
                M3IconButton(
                  onPressed: () => showGroupPicker(context),
                  icon: const Icon(Symbols.groups, fill: 1),
                  color: M3IconButtonColor.tonal,
                  tooltip: group == null ? 'Выбрать группу' : 'Сменить группу',
                ),
              ],
            ),
            ...body,
          ],
        ),
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
      SliverToBoxAdapter(child: ScheduleSearchBar(days: days)),
      if (day == null)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: 'На сайте пока нет расписания'),
        )
      else ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space100),
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
          padding: const EdgeInsets.only(bottom: AppSpacing.space800),
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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin(context),
            ),
            child: LessonSlotList(
              slots: slots,
              statuses: statuses,
              // Подробности — следующий уровень иерархии: платформенный
              // переход forward/backward (styles/motion/transitions).
              onOpen: (slot, status) async {
                final DateTime? date = await Navigator.of(context)
                    .push<DateTime>(
                      MaterialPageRoute(
                        builder: (context) => LessonDetailsPage(
                          slot: slot,
                          day: day,
                          days: days,
                          status: status,
                          subgroup: subgroup,
                        ),
                      ),
                    );
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
