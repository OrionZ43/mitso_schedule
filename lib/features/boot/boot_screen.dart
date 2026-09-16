import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_loading_indicator.dart';

/// Экран, который виден, пока грузятся настройки и данные.
///
/// Это не брендовый сплэш: по гайдлайну loading indicator предназначен для
/// коротких ожиданий, а не для показа логотипа на несколько секунд
/// (https://m3.material.io/components/loading-indicator/guidelines).
/// Роль сплэша выполняет штатный Android splash screen, описанный в
/// `android/app/src/main/res/values/styles.xml`.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  /// Ожидания короче 200 мс индикатор не показывают (loading indicator →
  /// Guidelines → Usage, таблица длительностей; в MDC — `app:showDelay`).
  static const Duration indicatorDelay = Duration(milliseconds: 200);

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _showIndicator = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(BootScreen.indicatorDelay, () {
      if (mounted) setState(() => _showIndicator = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Место под индикатор занято сразу, чтобы текст не прыгал.
            SizedBox.square(
              dimension: M3LoadingIndicator.containerSize,
              child: _showIndicator
                  ? const M3LoadingIndicator(
                      semanticsLabel: 'Загрузка расписания',
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.space300),
            Text('Расписание', style: context.text.headlineMedium),
            const SizedBox(height: AppSpacing.space100),
            Text(
              'Международный университет «МИТСО»',
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
