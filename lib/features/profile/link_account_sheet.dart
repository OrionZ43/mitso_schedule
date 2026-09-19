import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mitso/mitso_client.dart';
import '../../state/student_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_bottom_sheet.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_loading_indicator.dart';

/// Лист подключения лицевого счёта: номер счёта — он же логин на
/// student.mitso.by.
Future<void> showLinkAccountSheet(BuildContext context) {
  return showM3ModalBottomSheet<void>(
    context: context,
    builder: (context, scrollController) =>
        _LinkAccountSheet(scrollController: scrollController),
  );
}

class _LinkAccountSheet extends ConsumerStatefulWidget {
  const _LinkAccountSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends ConsumerState<_LinkAccountSheet> {
  final TextEditingController _number = TextEditingController();
  final FocusNode _focus = FocusNode();
  String? _error;
  bool _linking = false;

  @override
  void dispose() {
    _number.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final String number = _number.text.trim();
    if (number.isEmpty || _linking) return;
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      await ref.read(studentControllerProvider.notifier).link(number);
      final Object? error = ref.read(studentControllerProvider).error;
      if (error != null) throw error;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _linking = false;
        _error = error is MitsoException
            ? error.message
            : 'Не удалось подключить счёт.';
      });
    }
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
          child: Text('Лицевой счёт', style: context.text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.space100),
        Text(
          'Номер счёта указан в договоре. Приложение открывает '
          'student.mitso.by только вашим номером и хранит данные на телефоне.',
          style: context.text.bodyMedium!.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space200),
        TextField(
          controller: _number,
          focusNode: _focus,
          autofocus: true,
          enabled: !_linking,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _link(),
          decoration: InputDecoration(
            labelText: 'Номер лицевого счёта',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            helperText: 'Шесть цифр из договора',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.space300),
        Row(
          children: [
            Expanded(
              child: M3Button(
                onPressed: _linking ? null : () => Navigator.of(context).pop(),
                color: M3ButtonColor.outlined,
                size: M3ButtonSize.medium,
                child: const Text('Отмена'),
              ),
            ),
            const SizedBox(width: AppSpacing.space150),
            Expanded(
              child: ListenableBuilder(
                listenable: _number,
                builder: (context, _) => Semantics(
                  enabled: !_linking && _number.text.trim().isNotEmpty,
                  child: M3Button(
                    onPressed: _number.text.trim().isEmpty ? null : _link,
                    size: M3ButtonSize.medium,
                    child: _linking
                        ? M3LoadingIndicator(
                            size: 24,
                            color: colors.onPrimary,
                            semanticsLabel: 'Подключение счёта',
                          )
                        : const Text('Подключить'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
