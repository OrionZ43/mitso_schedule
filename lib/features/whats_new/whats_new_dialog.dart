import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/release_notes.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_bottom_sheet.dart' show M3BottomSheetDefaults;
import '../../widgets/m3_buttons.dart';

/// Окно «Что нового» после обновления.
///
/// Basic dialog по спеке (https://m3.material.io/components/dialogs):
/// контейнер `surfaceContainerHigh` 28dp, иконка 24dp `secondary`, заголовок
/// `headlineSmall` по центру (так выравнивают диалог с иконкой), текст
/// `onSurfaceVariant`, поля 24dp, ширина 280–560dp, одна подтверждающая
/// кнопка.
Future<void> showWhatsNewDialog(
  BuildContext context,
  List<ReleaseNotes> releases,
) {
  if (releases.isEmpty) return Future<void>.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    // Scrim — тот же, что у модальных листов (32%).
    barrierColor: Colors.black.withValues(
      alpha: M3BottomSheetDefaults.scrimOpacity,
    ),
    transitionDuration: AppMotion.defaultSpatial.duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _WhatsNewDialog(releases: releases),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Затухание — effects-пружина, масштаб — spatial: «Enter and exit».
      final Widget faded = FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.defaultEffects.curve,
        ),
        child: child,
      );
      if (reduceMotionOf(context)) return faded;
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppMotion.defaultSpatial.curve,
          ),
        ),
        child: faded,
      );
    },
  );
}

class _WhatsNewDialog extends StatefulWidget {
  const _WhatsNewDialog({required this.releases});

  final List<ReleaseNotes> releases;

  /// Ширина basic dialog — Specs → Basic dialog measurements.
  static const double minWidth = 280;
  static const double maxWidth = 560;

  /// Через сколько появляется следующая строка. Движение по очереди, от
  /// важного к мелкому: https://m3.material.io/styles/motion/transitions
  /// → «Sequencing».
  static const Duration stagger = Duration(milliseconds: 60);

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog>
    with SingleTickerProviderStateMixin {
  late final List<ReleaseNote> _notes = [
    for (final ReleaseNotes release in widget.releases) ...release.notes,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        AppMotion.defaultSpatial.duration +
        _WhatsNewDialog.stagger * _notes.length,
  );

  bool _started = false;

  // Движение зависит от системной настройки, а её видно только в
  // didChangeDependencies: в initState MediaQuery спрашивать нельзя.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Интервал появления строки [index] внутри общей анимации.
  Animation<double> _slot(int index) {
    final double step =
        _WhatsNewDialog.stagger.inMilliseconds /
        _controller.duration!.inMilliseconds;
    final double begin = step * index;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, (begin + 1 - step * _notes.length).clamp(0, 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final String headline = widget.releases.first.headline;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Что нового',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space300),
          child: ConstrainedBox(
            // Длинный список не должен вырасти за пределы экрана: окно
            // перестало бы закрываться кнопкой.
            constraints: BoxConstraints(
              minWidth: _WhatsNewDialog.minWidth,
              maxWidth: _WhatsNewDialog.maxWidth,
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Material(
              color: colors.surfaceContainerHigh,
              elevation: 6,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: AppShapes.rounded(AppShapes.extraLarge),
              clipBehavior: Clip.antiAlias,
              // Заголовок и кнопка закреплены, прокручивается только список:
              // в Compose `AlertDialogContent` устроен так же.
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Symbols.auto_awesome,
                      color: colors.secondary,
                      fill: 1,
                    ),
                    const SizedBox(height: AppSpacing.space200),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall!.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space100),
                    Text(
                      'Версия ${widget.releases.first.version}',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space200),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < _notes.length; i++)
                              _NoteRow(note: _notes[i], progress: _slot(i)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space100),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: M3Button(
                        onPressed: () => Navigator.of(context).pop(),
                        color: M3ButtonColor.text,
                        child: const Text('Понятно'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка списка: значок в кружке, заголовок и пояснение.
///
/// Появляется со сдвигом снизу и затуханием — мелкое движение внутри уже
/// открытого окна.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.progress});

  final ReleaseNote note;
  final Animation<double> progress;

  /// Кружок значка — как `ListTokens.ItemLeadingAvatar*`: 40dp.
  static const double avatarSize = 40;

  /// Своя картинка — в живой области значка (20dp из 24dp), чтобы по весу не
  /// выбивалась из Material Symbols.
  static const double imageSize = 20;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) => Opacity(
        opacity: progress.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - progress.value) * AppSpacing.space200),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: note.image != null
                  ? Center(
                      child: SvgPicture.asset(
                        note.image!,
                        width: imageSize,
                        height: imageSize,
                        excludeFromSemantics: true,
                        colorFilter: ColorFilter.mode(
                          colors.onSecondaryContainer,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : Icon(
                      note.icon,
                      color: colors.onSecondaryContainer,
                      fill: 1,
                    ),
            ),
            const SizedBox(width: AppSpacing.space200),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: context.text.titleMedium!.emphasized.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space25),
                  Text(
                    note.text,
                    style: context.text.bodyMedium!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
