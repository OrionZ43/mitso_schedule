import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Одна строка в окне «Что нового».
@immutable
class ReleaseNote {
  const ReleaseNote({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;

  /// Коротко: «Расписание под присмотром».
  final String title;

  /// Одно-два предложения о том, что изменилось.
  final String text;
}

/// Что нового в версии.
@immutable
class ReleaseNotes {
  const ReleaseNotes({
    required this.version,
    required this.headline,
    required this.notes,
  });

  /// «1.3.0» — без номера сборки.
  final String version;

  /// Заголовок окна: о чём версия.
  final String headline;

  final List<ReleaseNote> notes;
}

/// Что нового по версиям — новые сверху.
///
/// Тот же текст, что в описании релиза на GitHub, только короче: окно
/// показывается один раз после обновления.
const List<ReleaseNotes> kReleaseNotes = [
  ReleaseNotes(
    version: '1.3.0',
    headline: 'Расписание под присмотром',
    notes: [
      ReleaseNote(
        icon: Symbols.edit_calendar,
        title: 'Пару добавили — вы узнаете',
        text:
            'Приложение само проверяет расписание раз в три часа и сообщает, '
            'что изменилось: пару добавили, перенесли или убрали.',
      ),
      ReleaseNote(
        icon: Symbols.event_available,
        title: 'Новая неделя',
        text:
            'Как только сайт выкладывает следующую неделю, приходит '
            'уведомление: сколько пар и есть ли зачёты.',
      ),
      ReleaseNote(
        icon: Symbols.priority_high,
        title: 'Зачёты и экзамены видно',
        text:
            'На карточке у них свой цвет и значок, день подписан в ленте, '
            'а накануне вечером приходит напоминание.',
      ),
      ReleaseNote(
        icon: Symbols.account_balance_wallet,
        title: 'Счёт честно говорит, когда проверялся',
        text:
            'В карточке баланса видно, когда приложение последний раз '
            'ходило на сайт и получилось ли.',
      ),
    ],
  ),
  ReleaseNotes(
    version: '1.2.0',
    headline: 'Фото профиля и напоминания',
    notes: [
      ReleaseNote(
        icon: Symbols.notifications_active,
        title: 'Напоминание о паре',
        text: 'За 5, 10, 15, 30 минут, за час или за свой срок до начала.',
      ),
      ReleaseNote(
        icon: Symbols.account_circle,
        title: 'Профиль',
        text:
            'Крупная шапка с аватаром и группой; фото можно поставить своё — '
            'оно остаётся на устройстве.',
      ),
    ],
  ),
];

/// Заметки о версиях новее [lastSeen] и не новее [current].
///
/// Пользователь мог перескочить через версию — тогда покажем всё, что он
/// пропустил, одним окном.
List<ReleaseNotes> notesSince(
  String lastSeen, {
  required String current,
  List<ReleaseNotes> notes = kReleaseNotes,
}) => [
  for (final ReleaseNotes release in notes)
    if (compareVersions(release.version, lastSeen) > 0 &&
        compareVersions(release.version, current) <= 0)
      release,
];

/// Сравнение версий «1.10.0» и «1.9.0» по числам, а не по строкам.
int compareVersions(String a, String b) {
  final List<int> left = _parts(a);
  final List<int> right = _parts(b);
  for (int i = 0; i < 3; i++) {
    final int diff =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (diff != 0) return diff.sign;
  }
  return 0;
}

List<int> _parts(String version) => [
  for (final String part in version.split('.')) int.tryParse(part.trim()) ?? 0,
];
