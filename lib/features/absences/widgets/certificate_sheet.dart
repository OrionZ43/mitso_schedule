import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../state/absences_controller.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/m3_bottom_sheet.dart';
import '../../../widgets/m3_buttons.dart';
import '../../../widgets/m3_loading_indicator.dart';
import '../../../widgets/segmented_list.dart';
import '../../home/home_shell.dart';

/// Нижний лист отправки справки.
///
/// https://m3.material.io/components/bottom-sheets — модальный лист для
/// короткого дополнительного действия; закрыть можно кнопкой, свайпом или
/// нажатием на scrim.
Future<void> showCertificateSheet(BuildContext context) {
  return showM3ModalBottomSheet<void>(
    context: context,
    builder: (context, scrollController) =>
        _CertificateSheet(scrollController: scrollController),
  );
}

class _CertificateSheet extends ConsumerStatefulWidget {
  const _CertificateSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_CertificateSheet> createState() => _CertificateSheetState();
}

class _CertificateSheetState extends ConsumerState<_CertificateSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref.read(absencesControllerProvider.notifier).submit();
    if (!mounted) return;
    Navigator.of(context).pop();
    appSnackbarHost.currentState?.show('Справка отправлена куратору');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space200,
        0,
        AppSpacing.space200,
        AppSpacing.space300,
      ),
      children: [
        Semantics(
          header: true,
          child: Text('Оправдать пропуск', style: context.text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.space100),
        Text(
          'Прикрепи фото справки — бот отправит её куратору и обновит '
          'статистику.',
          style: context.text.bodyMedium!.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space200),
        SegmentedList(
          children: [
            M3ListItem(
              leading: const Icon(Symbols.add_a_photo),
              headline: const Text('Фото справки'),
              supporting: const Text('Сфотографировать или выбрать из галереи'),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space300),
        // Отменяющее действие слева от подтверждающего; размер Medium.
        Row(
          children: [
            Expanded(
              child: M3Button(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                color: M3ButtonColor.outlined,
                size: M3ButtonSize.medium,
                child: const Text('Отмена'),
              ),
            ),
            const SizedBox(width: AppSpacing.space150),
            Expanded(
              child: Semantics(
                // Пока идёт отправка, кнопка не принимает нажатий, но не
                // выглядит отключённой: индикатор внутри должен иметь
                // контраст ≥ 3:1 к кнопке (loading indicator → Accessibility).
                enabled: !_submitting,
                child: M3Button(
                  onPressed: _submit,
                  size: M3ButtonSize.medium,
                  child: _submitting
                      ? M3LoadingIndicator(
                          size: 24,
                          color: colors.onPrimary,
                          semanticsLabel: 'Отправка справки',
                        )
                      : const Text('Отправить'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
