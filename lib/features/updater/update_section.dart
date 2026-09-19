import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import '../../widgets/segmented_list.dart';
import 'update_checker.dart';
import 'update_provider.dart';

/// Раздел «О приложении» в настройках: версия, проверка и предложение
/// обновиться.
///
/// Карточка некликабельная, с кнопками внутри — `cards.md`: «Карточка либо
/// сама целиком действие, либо контейнер с кнопками внутри».
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState state = ref.watch(updateControllerProvider);
    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );
    final String version = ref.watch(appVersionProvider).value ?? '';
    final bool enabled = state.outcome != UpdateCheckOutcome.disabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedList(
          children: [
            M3ListItem(
              leading: const Icon(Symbols.system_update),
              headline: Text(
                version.isEmpty ? 'Расписание' : 'Расписание $version',
              ),
              supporting: Text(_statusOf(state)),
              trailing: enabled
                  ? M3Button(
                      onPressed: state.checking || state.isBusy
                          ? null
                          : controller.checkNow,
                      color: M3ButtonColor.text,
                      child: const Text('Проверить'),
                    )
                  : null,
            ),
          ],
        ),
        if (state.isVisible) ...[
          const SizedBox(height: AppSpacing.space150),
          const UpdateCard(),
        ],
      ],
    );
  }

  /// Строка состояния под версией. «Установлена последняя версия» пишем
  /// только после удачной проверки: без сети это было бы неправдой.
  static String _statusOf(UpdateState state) {
    if (state.checking) return 'Проверяем обновления…';
    return switch (state.outcome) {
      UpdateCheckOutcome.available =>
        'Доступна версия ${state.update!.manifest.version}',
      UpdateCheckOutcome.upToDate => 'Установлена последняя версия',
      UpdateCheckOutcome.failed => 'Не удалось проверить обновления',
      UpdateCheckOutcome.disabled => 'Проверка обновлений выключена',
      null => 'Обновления приходят из релизов на GitHub',
    };
  }
}

/// Найденное обновление: версия, что нового, загрузка и установка.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState state = ref.watch(updateControllerProvider);
    final AvailableUpdate? update = state.update;
    if (update == null) return const SizedBox.shrink();

    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );
    final ColorScheme colors = context.colors;
    final TextTheme text = context.text;

    return Card.filled(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.system_update, size: 18, color: colors.primary),
                const SizedBox(width: AppSpacing.space100),
                Text(
                  update.isMandatory
                      ? 'Обязательное обновление'
                      : 'Доступно обновление',
                  style: text.labelLarge!.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space50),
            Text(
              'Версия ${update.manifest.version}',
              style: text.titleLarge!.copyWith(color: colors.onSurface),
            ),
            if (update.manifest.notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space100),
              Text(
                update.manifest.notes,
                style: text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (!state.hasFile) ...[
              const SizedBox(height: AppSpacing.space100),
              Text(
                'Файла под это устройство в релизе нет — скачайте его со '
                'страницы релиза',
                style: text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (state.phase == UpdatePhase.downloading) ...[
              const SizedBox(height: AppSpacing.space200),
              _Progress(progress: state.progress),
            ],
            if (state.phase == UpdatePhase.installing) ...[
              const SizedBox(height: AppSpacing.space200),
              Text(
                'Открываем установщик…',
                style: text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.space150),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.error, size: 18, color: colors.error),
                  const SizedBox(width: AppSpacing.space100),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: text.bodyMedium!.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.space200),
            _Actions(state: state, controller: controller),
          ],
        ),
      ),
    );
  }
}

/// Кнопки карточки. Подтверждающее действие — последнее, как у диалогов
/// (`dialogs.md`: подтверждающая кнопка справа).
class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.controller});

  final UpdateState state;
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final AvailableUpdate update = state.update!;

    if (state.phase == UpdatePhase.downloading) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: M3Button(
          onPressed: controller.cancelDownload,
          color: M3ButtonColor.text,
          child: const Text('Отмена'),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!update.isMandatory)
          M3Button(
            onPressed: state.isBusy ? null : controller.dismiss,
            color: M3ButtonColor.text,
            child: const Text('Позже'),
          ),
        const SizedBox(width: AppSpacing.space100),
        if (state.hasFile)
          M3Button(
            onPressed: state.isBusy ? null : controller.downloadAndInstall,
            icon: const Icon(Symbols.download),
            child: Text(
              state.phase == UpdatePhase.failed ? 'Повторить' : 'Обновить',
            ),
          )
        else if (update.manifest.releaseUrl != null)
          M3Button(
            onPressed: () => launchUrl(
              update.manifest.releaseUrl!,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Symbols.open_in_new),
            color: M3ButtonColor.tonal,
            child: const Text('Открыть релиз'),
          ),
      ],
    );
  }
}

/// Открыт ли диалог обязательного обновления: повторная проверка не должна
/// класть второй диалог поверх первого.
bool _mandatoryDialogOpen = false;

/// Обновление, которое нельзя отложить: пока его не поставят, приложением
/// пользоваться нельзя (dialogs → Usage: «решение, которое блокирует работу»).
Future<void> showMandatoryUpdateDialog(BuildContext context) {
  if (_mandatoryDialogOpen) return Future<void>.value();
  _mandatoryDialogOpen = true;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _MandatoryUpdateDialog(),
  ).whenComplete(() => _mandatoryDialogOpen = false);
}

class _MandatoryUpdateDialog extends ConsumerWidget {
  const _MandatoryUpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState state = ref.watch(updateControllerProvider);
    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );
    final AvailableUpdate? update = state.update;
    if (update == null) return const SizedBox.shrink();
    final ColorScheme colors = context.colors;

    return PopScope(
      // Кнопка «Назад» диалог не закрывает: обновление обязательное.
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Symbols.system_update),
        title: const Text('Нужно обновить приложение'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Эта версия больше не работает с сайтом университета. '
              'Обновитесь до версии ${update.manifest.version}.',
            ),
            if (update.manifest.notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space150),
              Text(
                update.manifest.notes,
                style: context.text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (state.phase == UpdatePhase.downloading) ...[
              const SizedBox(height: AppSpacing.space200),
              _Progress(progress: state.progress),
            ],
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.space150),
              Text(
                state.error!,
                style: context.text.bodyMedium!.copyWith(color: colors.error),
              ),
            ],
          ],
        ),
        actions: [
          if (state.hasFile)
            TextButton(
              onPressed: state.isBusy ? null : controller.downloadAndInstall,
              child: Text(
                state.phase == UpdatePhase.failed ? 'Повторить' : 'Обновить',
              ),
            )
          else if (update.manifest.releaseUrl != null)
            TextButton(
              onPressed: () => launchUrl(
                update.manifest.releaseUrl!,
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Открыть релиз'),
            ),
        ],
      ),
    );
  }
}

/// Ход загрузки: волнистая шкала и проценты рядом.
class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 100).round();
    return Row(
      children: [
        Expanded(
          child: M3WavyLinearProgress(
            value: progress,
            semanticsLabel: 'Загрузка обновления',
          ),
        ),
        const SizedBox(width: AppSpacing.space150),
        Text(
          '$percent %',
          style: context.text.labelLarge!.copyWith(
            color: context.colors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
