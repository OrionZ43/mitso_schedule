import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app_platform.dart';
import '../../../data/photo_picker.dart';
import '../../../state/absences_controller.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/m3_bottom_sheet.dart';
import '../../../widgets/m3_buttons.dart';
import '../../../widgets/m3_loading_indicator.dart';
import '../../../widgets/segmented_list.dart';
import '../../home/home_shell.dart';

/// Нижний лист регистрации пропуска: фото справки с камеры или из галереи.
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
  String? _photoPath;
  String? _error;
  bool _capturing = false;
  bool _saving = false;

  /// Высота превью снимка.
  static const double previewHeight = 240;

  Future<void> _capture(PhotoSource source) async {
    if (_capturing || _saving) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final String? path = await ref.read(photoPickerProvider).pick(source);
      if (!mounted) return;
      setState(() => _photoPath = path ?? _photoPath);
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _error = source == PhotoSource.camera
            ? 'Не удалось открыть камеру.'
            : 'Не удалось открыть галерею.',
      );
    } on MissingPluginException {
      // Платформа без фотовыбора: кнопок там нет, но перестраховка дешёвая.
      if (!mounted) return;
      setState(() => _error = 'Фото добавляется в приложении на телефоне.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _save() async {
    final String? path = _photoPath;
    if (path == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(absencesControllerProvider.notifier).register(path);
    } on FileSystemException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить фото.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    appSnackbarHost.currentState?.show('Справка сохранена');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String? photo = _photoPath;

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
          child: Text(
            'Зарегистрировать пропуск',
            style: context.text.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.space100),
        Text(
          'Сфотографируй справку или выбери фото из галереи. Пока '
          'Telegram-бот не подключён, справка сохранится в приложении.',
          style: context.text.bodyMedium!.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space200),
        if (photo != null) ...[
          Semantics(
            image: true,
            label: 'Фото справки',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.large),
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: previewHeight,
                  child: Image.file(
                    File(photo),
                    fit: BoxFit.cover,
                    // Декодируем под ширину превью: портретный снимок в
                    // широкой рамке упирается в ширину.
                    cacheWidth:
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Symbols.image,
                          size: 40,
                          opticalSize: 40,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space100),
        ],
        // На компьютере камеры нет — остаётся готовый файл: фото, снятое
        // телефоном, или скан.
        if (AppPlatform.isDesktop)
          SegmentedList(
            children: [
              M3ListItem(
                leading: const Icon(Symbols.folder_open),
                headline: Text(
                  photo == null ? 'Выбрать файл' : 'Выбрать другой файл',
                ),
                supporting: const Text('Фото с телефона или скан справки'),
                onTap: () => _capture(PhotoSource.gallery),
                enabled: !_saving,
              ),
            ],
          )
        else
          SegmentedList(
            children: [
              M3ListItem(
                leading: const Icon(Symbols.photo_camera),
                headline: Text(
                  photo == null ? 'Сфотографировать' : 'Переснять',
                ),
                onTap: () => _capture(PhotoSource.camera),
                enabled: !_saving,
              ),
              M3ListItem(
                leading: const Icon(Symbols.photo_library),
                headline: Text(
                  photo == null ? 'Выбрать из галереи' : 'Выбрать другое фото',
                ),
                onTap: () => _capture(PhotoSource.gallery),
                enabled: !_saving,
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.space100),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: context.text.bodyMedium!.copyWith(color: colors.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space300),
        // Отменяющее действие слева от подтверждающего; размер Medium.
        Row(
          children: [
            Expanded(
              child: M3Button(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                color: M3ButtonColor.outlined,
                size: M3ButtonSize.medium,
                child: const Text('Отмена'),
              ),
            ),
            const SizedBox(width: AppSpacing.space150),
            Expanded(
              child: Semantics(
                // Пока идёт сохранение, кнопка не принимает нажатий, но не
                // выглядит отключённой: индикатор внутри должен иметь
                // контраст ≥ 3:1 к кнопке (loading indicator → Accessibility).
                enabled: photo != null && !_saving,
                child: M3Button(
                  // Без фото сохранять нечего — кнопка отключена.
                  onPressed: photo == null ? null : _save,
                  size: M3ButtonSize.medium,
                  child: _saving
                      ? M3LoadingIndicator(
                          size: 24,
                          color: colors.onPrimary,
                          semanticsLabel: 'Сохранение справки',
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
