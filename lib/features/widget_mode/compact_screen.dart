import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/lesson.dart';
import '../../state/mitso_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import '../schedule/lesson_timing.dart';
import 'app_window.dart';
import 'upcoming_lesson.dart';

/// Компактное окно на рабочем столе: часы и ближайшая пара.
///
/// Окно без рамки и поверх других — значит ни заголовка, чтобы тянуть, ни
/// кнопки закрытия у него нет: и то и другое здесь, в интерфейсе.
class CompactScreen extends ConsumerWidget {
  const CompactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = context.colors;

    return Material(
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space200,
          AppSpacing.space150,
          AppSpacing.space100,
          AppSpacing.space200,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TopRow(),
            const SizedBox(height: AppSpacing.space150),
            Expanded(child: const _LessonBlock()),
          ],
        ),
      ),
    );
  }
}

/// Часы, дата и кнопки окна. Всё, кроме кнопок, — ручка перетаскивания.
class _TopRow extends ConsumerWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = context.colors;
    final DateTime now = ref.watch(nowProvider);

    return Row(
      children: [
        Expanded(
          child: Listener(
            // Дальше окно тянет сама Windows, и Flutter событий уже не видит.
            onPointerDown: (_) => ref.read(appWindowProvider).startDrag(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const _Clock(),
                const SizedBox(width: AppSpacing.space150),
                Flexible(
                  child: Text(
                    _capitalize(DateFormat('EEE, d MMM', 'ru').format(now)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        M3IconButton(
          onPressed: () => ref.read(widgetModeProvider.notifier).set(false),
          icon: const Icon(Symbols.open_in_full),
          color: M3IconButtonColor.standard,
          size: M3ButtonSize.extraSmall,
          tooltip: 'Развернуть окно',
        ),
        M3IconButton(
          onPressed: () => ref.read(appWindowProvider).close(),
          icon: const Icon(Symbols.close),
          color: M3IconButtonColor.standard,
          size: M3ButtonSize.extraSmall,
          tooltip: 'Закрыть',
        ),
      ],
    );
  }
}

/// Часы: обновляются ровно на смене минуты, а не по общему таймеру на 30
/// секунд — иначе время отставало бы на полминуты.
class _Clock extends ConsumerStatefulWidget {
  const _Clock();

  @override
  ConsumerState<_Clock> createState() => _ClockState();
}

class _ClockState extends ConsumerState<_Clock> {
  Timer? _timer;
  late DateTime _now = ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final DateTime now = ref.read(clockProvider)();
    final Duration toNextMinute = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(toNextMinute, () {
      if (!mounted) return;
      setState(() => _now = ref.read(clockProvider)());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    DateFormat.Hm('ru').format(_now),
    style: context.text.headlineSmall!.copyWith(
      fontWeight: FontWeight.w600,
      // Цифры не должны дёргаться при смене минуты.
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Ближайшая пара: название, аудитория, время и, если идёт, сколько осталось.
class _LessonBlock extends ConsumerWidget {
  const _LessonBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpcomingLesson? upcoming = ref.watch(upcomingLessonProvider);
    final ColorScheme colors = context.colors;
    final TextTheme text = context.text;

    if (upcoming == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          ref.watch(scheduleTargetProvider) == null
              ? 'Расписание не выбрано'
              : 'Пар больше нет',
          style: text.bodyMedium!.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    final LessonSlot slot = upcoming.slot;
    final String? room = slot.lessons.first.room;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                slot.commonTitle ?? 'Пары по подгруппам',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall!.copyWith(color: colors.onSurface),
              ),
            ),
            if (room != null) ...[
              const SizedBox(width: AppSpacing.space100),
              _Room(room: room),
            ],
          ],
        ),
        const Spacer(),
        Text(
          _whenLabel(upcoming),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall!.copyWith(
            color: upcoming.isNow ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        // Идущая пара — та же волнистая шкала, что и на карточке в списке.
        if (upcoming.progress != null) ...[
          const SizedBox(height: AppSpacing.space100),
          M3WavyLinearProgress(
            value: upcoming.progress!.fraction,
            semanticsLabel: 'Пара идёт',
          ),
        ],
      ],
    );
  }

  /// «13:55–15:20 · осталось 48 мин», «через 25 мин» или «завтра в 8:30».
  static String _whenLabel(UpcomingLesson upcoming) {
    final String time = '${upcoming.slot.start}–${upcoming.slot.end}';
    final LessonProgress? progress = upcoming.progress;
    if (progress != null) {
      return '$time · осталось ${progress.minutesLeft} мин';
    }
    if (upcoming.startsIn != null) {
      return '$time · ${startsInLabel(upcoming.startsIn!)}';
    }
    final String day = _capitalize(
      DateFormat('EEE, d MMM', 'ru').format(upcoming.day),
    );
    return '$day · $time';
  }
}

/// Аудитория — короткая метка у края, как на карточке пары.
class _Room extends StatelessWidget {
  const _Room({required this.room});

  final String room;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space100,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        room,
        style: context.text.labelMedium!.copyWith(
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
