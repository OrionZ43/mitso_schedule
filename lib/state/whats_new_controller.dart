import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/release_notes.dart';
import '../features/updater/update_provider.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Что показать в окне «Что нового»: пусто — показывать нечего.
///
/// После первой установки окно не всплывает: человек ещё не видел старого,
/// чтобы ему объясняли новое.
final whatsNewProvider = FutureProvider<List<ReleaseNotes>>((ref) async {
  final String current = versionOf(await ref.watch(appVersionProvider.future));
  if (current.isEmpty) return const [];

  final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
  final String? seen = prefs.getString(WhatsNew.seenKey);
  if (seen == null) {
    await prefs.setString(WhatsNew.seenKey, current);
    // Сам ключ появился в 1.3.0: у тех, кто обновился с прежней версии, его
    // нет, но приложением уже пользовались — расписание выбрано. Им
    // показываем заметки этой версии, а новичкам — ничего.
    final bool used =
        prefs.containsKey('schedule.target') ||
        prefs.containsKey('group.selected');
    if (!used) return const [];
    return [
      for (final ReleaseNotes release in kReleaseNotes)
        if (compareVersions(release.version, current) == 0) release,
    ];
  }
  if (compareVersions(seen, current) >= 0) return const [];
  return notesSince(seen, current: current);
}, retry: noRetry);

abstract final class WhatsNew {
  /// Версия, о которой пользователю уже рассказали.
  static const String seenKey = 'app.lastSeenVersion';

  /// Окно закрыли — больше про эту версию не напоминаем.
  static Future<void> markSeen(WidgetRef ref) async {
    final String current = versionOf(await ref.read(appVersionProvider.future));
    if (current.isEmpty) return;
    await ref.read(sharedPreferencesProvider).setString(seenKey, current);
    ref.invalidate(whatsNewProvider);
  }
}

/// «1.3.0 (6)» → «1.3.0».
String versionOf(String appVersion) => appVersion.split(' ').first.trim();
