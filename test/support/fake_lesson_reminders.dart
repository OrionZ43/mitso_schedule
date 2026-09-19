import 'package:mitso_schedule/data/lesson_reminders.dart';

/// Вместо системных уведомлений — запись того, что было бы запланировано.
class FakeLessonReminders implements LessonReminderPort {
  FakeLessonReminders({this.granted = true});

  /// Пользователь разрешает уведомления.
  final bool granted;

  int permissionRequests = 0;
  int replaceCalls = 0;
  List<LessonReminder> planned = const [];

  @override
  Future<void> replace(List<LessonReminder> reminders) async {
    replaceCalls++;
    planned = reminders;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }
}
