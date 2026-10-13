import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/schedule_diff.dart';
import '../../state/schedule_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';

/// Плашка «что изменилось»: пару добавили, перенесли или вышла новая неделя.
///
/// Уведомление приходит, когда приложение закрыто; если расписание
/// обновилось прямо в приложении, о том же самом говорит эта карточка.
/// Появление и уход — пружина `defaultSpatial`, как у остальных контейнеров.
class ScheduleChangesCard extends ConsumerWidget {
  const ScheduleChangesCard({super.key, required this.diff});

  final ScheduleDiff diff;

  /// Сколько правок показать списком: остальные свернуты в «и ещё N».
  static const int maxLines = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = context.colors;
    final bool newWeek = diff.hasNewWeek;
    final List<ScheduleChange> changes = diff.changes;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space150),
      child: Card.filled(
        color: colors.secondaryContainer,
        shape: AppShapes.rounded(AppShapes.extraLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    newWeek ? Symbols.event_available : Symbols.edit_calendar,
                    color: colors.onSecondaryContainer,
                    fill: 1,
                  ),
                  const SizedBox(width: AppSpacing.space150),
                  Expanded(
                    child: Text(
                      newWeek
                          ? 'Расписание на ${diff.newWeekRange}'
                          : diff.changesTitle,
                      style: context.text.titleMedium!.emphasized.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space100),
              if (newWeek)
                _line(context, diff.newWeekSummary)
              else ...[
                for (final ScheduleChange change in changes.take(maxLines))
                  _line(context, change.toString()),
                if (changes.length > maxLines)
                  _line(context, 'и ещё ${changes.length - maxLines}'),
              ],
              const SizedBox(height: AppSpacing.space150),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: M3Button(
                  onPressed: () => ref
                      .read(scheduleControllerProvider.notifier)
                      .markChangesSeen(),
                  color: M3ButtonColor.text,
                  size: M3ButtonSize.small,
                  child: const Text('Понятно'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.space50),
    child: Text(
      text,
      style: context.text.bodyMedium!.copyWith(
        color: context.colors.onSecondaryContainer,
      ),
    ),
  );
}

/// Появление плашки: пружина `defaultSpatial` по высоте и затухание
/// `defaultEffects` — `MotionSchemeKeyTokens` из Compose.
class ScheduleChangesSlot extends StatelessWidget {
  const ScheduleChangesSlot({super.key, this.diff});

  final ScheduleDiff? diff;

  @override
  Widget build(BuildContext context) {
    final ScheduleDiff? diff = this.diff;
    return AnimatedSize(
      duration: AppMotion.defaultSpatial.duration,
      curve: AppMotion.defaultSpatial.curve,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: diff == null ? 0 : 1,
        duration: AppMotion.defaultEffects.duration,
        curve: AppMotion.defaultEffects.curve,
        child: diff == null
            ? const SizedBox(width: double.infinity)
            : ScheduleChangesCard(diff: diff),
      ),
    );
  }
}
