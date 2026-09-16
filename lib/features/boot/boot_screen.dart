import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_loading_indicator.dart';

/// Экран, который виден, пока грузятся настройки и данные.
///
/// Это не брендовый сплэш: по гайдлайну loading indicator предназначен для
/// коротких ожиданий, а не для показа логотипа на несколько секунд
/// (https://m3.material.io/components/loading-indicator/guidelines).
/// Роль сплэша выполняет штатный Android splash screen, описанный в
/// `android/app/src/main/res/values/styles.xml`.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const M3LoadingIndicator(semanticsLabel: 'Загрузка расписания'),
            const SizedBox(height: 26),
            Text(
              'Расписание',
              style: context.text.headlineMedium!.emphasized.copyWith(
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${MockData.profile.group} · ИКТиУ',
              style: context.text.labelLarge!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
