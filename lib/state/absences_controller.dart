import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/certificate.dart';
import '../data/photo_picker.dart';
import 'mitso_providers.dart';
import 'settings_controller.dart';

/// Сводка пропусков. Её будет присылать Telegram-бот; пока он не подключён,
/// сводки нет.
final absenceSummaryProvider = Provider<AbsenceSummary?>((ref) => null);

/// Зарегистрированные справки, новые — первыми.
final absencesControllerProvider =
    NotifierProvider<AbsencesController, List<Certificate>>(
      AbsencesController.new,
    );

class AbsencesController extends Notifier<List<Certificate>> {
  static const String _key = 'absences.certificates';

  @override
  List<Certificate> build() {
    final String? raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final Object? item in jsonDecode(raw) as List<Object?>)
          Certificate.fromJson(item! as Map<String, Object?>),
      ];
    } catch (_) {
      // Повреждённая запись — начинаем с пустого списка.
      return const [];
    }
  }

  /// Сохраняет справку по фото [photoPath]: она встаёт в начало списка со
  /// статусом «Не отправлено».
  Future<void> register(String photoPath) async {
    final DateTime now = ref.read(clockProvider)();
    final String id = now.microsecondsSinceEpoch.toString();
    final String kept = await ref
        .read(photoPickerProvider)
        .keep(photoPath, folder: 'certificates', name: id);
    state = [Certificate(id: id, photoPath: kept, createdAt: now), ...state];
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode([for (final c in state) c.toJson()]));
  }
}
