import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../data/models/certificate.dart';

final absencesControllerProvider =
    NotifierProvider<AbsencesController, List<Certificate>>(
      AbsencesController.new,
    );

class AbsencesController extends Notifier<List<Certificate>> {
  @override
  List<Certificate> build() => MockData.certificates;

  /// Отправляет справку: она встаёт в начало списка со статусом «В обработке».
  ///
  /// Задержка имитирует отправку боту — на это время показывается
  /// `M3LoadingIndicator` в шите.
  Future<void> submit() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    state = [
      Certificate(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Новая справка',
        period: '16 сентября · 2 ч',
        status: CertificateStatus.pending,
        note: 'Отправлено только что',
      ),
      ...state,
    ];
  }
}
