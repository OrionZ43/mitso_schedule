import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Заголовок раздела над группой элементов.
///
/// Отдельного токена у M3 нет (lists → Anatomy не описывает подзаголовок),
/// поэтому стиль один на всё приложение: `titleSmall`, `onSurfaceVariant`,
/// роль заголовка для TalkBack. Отступы — токены spacing: 24 сверху, 12 снизу,
/// 16 слева — как у текста пункта списка.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space200,
        AppSpacing.space300,
        AppSpacing.space200,
        AppSpacing.space150,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: context.text.titleSmall!.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
