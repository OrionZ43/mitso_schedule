import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/seasons.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Сезон, который идёт сегодня; `null` — обычные дни или оформление
/// выключено.
///
/// Зависит только от даты: `nowProvider` тикает раз в полминуты, но пока день
/// тот же, подписчики не перестраиваются.
final activeSeasonProvider = Provider<Season?>((ref) {
  if (!ref.watch(
    settingsControllerProvider.select((Settings s) => s.seasonalTheme),
  )) {
    return null;
  }
  final DateTime today = ref.watch(
    nowProvider.select(
      (DateTime now) => DateTime(now.year, now.month, now.day),
    ),
  );
  return seasonOn(today);
});

/// Сезон без оглядки на настройку — чтобы в настройках написать, что сейчас
/// идёт, даже когда оформление выключено.
final seasonTodayProvider = Provider<Season?>((ref) {
  final DateTime today = ref.watch(
    nowProvider.select(
      (DateTime now) => DateTime(now.year, now.month, now.day),
    ),
  );
  return seasonOn(today);
});
