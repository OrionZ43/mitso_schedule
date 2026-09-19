import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app_platform.dart';
import '../../data/photo_picker.dart';
import '../../state/avatar_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_bottom_sheet.dart';
import '../../widgets/segmented_list.dart';

/// Нижний лист «Фото профиля»: снять, выбрать или убрать.
///
/// https://m3.material.io/components/bottom-sheets — модальный лист для
/// короткого дополнительного действия.
Future<void> showAvatarSheet(BuildContext context) {
  return showM3ModalBottomSheet<void>(
    context: context,
    builder: (context, scrollController) =>
        _AvatarSheet(scrollController: scrollController),
  );
}

class _AvatarSheet extends ConsumerStatefulWidget {
  const _AvatarSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends ConsumerState<_AvatarSheet> {
  String? _error;
  bool _busy = false;

  Future<void> _pick(PhotoSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bool picked = await ref
          .read(avatarControllerProvider.notifier)
          .pick(source);
      if (!mounted) return;
      // Вернулись без снимка — лист остаётся открытым.
      if (picked) Navigator.of(context).pop();
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _error = source == PhotoSource.camera
            ? 'Не удалось открыть камеру.'
            : 'Не удалось открыть галерею.',
      );
    } on MissingPluginException {
      // Платформа без фотовыбора: перестраховка.
      if (!mounted) return;
      setState(() => _error = 'Фото добавляется в приложении на телефоне.');
    } on FileSystemException {
      if (!mounted) return;
      setState(() => _error = 'Не удалось сохранить фото.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    await ref.read(avatarControllerProvider.notifier).remove();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool hasPhoto = ref.watch(avatarControllerProvider) != null;

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
          child: Text('Фото профиля', style: context.text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.space100),
        Text(
          'Фото остаётся на устройстве: приложение никуда его не отправляет.',
          style: context.text.bodyMedium!.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space200),
        SegmentedList(
          children: [
            // На компьютере камеры нет — остаётся готовый файл.
            if (AppPlatform.isPhone)
              M3ListItem(
                leading: const Icon(Symbols.photo_camera),
                headline: const Text('Сделать снимок'),
                onTap: () => _pick(PhotoSource.camera),
                enabled: !_busy,
              ),
            M3ListItem(
              leading: Icon(
                AppPlatform.isPhone
                    ? Symbols.photo_library
                    : Symbols.folder_open,
              ),
              headline: Text(
                AppPlatform.isPhone ? 'Выбрать из галереи' : 'Выбрать файл',
              ),
              onTap: () => _pick(PhotoSource.gallery),
              enabled: !_busy,
            ),
            if (hasPhoto)
              M3ListItem(
                leading: const Icon(Symbols.delete),
                headline: const Text('Убрать фото'),
                supporting: const Text('Останутся инициалы'),
                onTap: _busy ? null : _remove,
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
      ],
    );
  }
}
