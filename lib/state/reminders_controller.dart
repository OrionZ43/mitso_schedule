import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_platform.dart';
import '../data/lesson_reminders.dart';
import 'mitso_providers.dart';
import 'schedule_controller.dart';
import 'settings_controller.dart';

/// Планировщик напоминаний. В тестах подменяется.
final lessonReminderPortProvider = Provider<LessonReminderPort>(
  (ref) => const SystemLessonReminders(),
);

/// Держит запланированные напоминания в согласии с расписанием и настройками.
///
/// Перепланирует при любом изменении: включили напоминания, сменили срок,
/// подтянулось свежее расписание, выбрали другую группу. Уведомления живут в
/// системе, поэтому приложению не нужно просыпаться в фоне.
final reminderSchedulerProvider = AsyncNotifierProvider<ReminderScheduler, int>(
  ReminderScheduler.new,
);

class ReminderScheduler extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final Settings settings = ref.watch(settingsControllerProvider);
    final ScheduleState? schedule = ref.watch(scheduleControllerProvider).value;
    final LessonReminderPort port = ref.read(lessonReminderPortProvider);

    // На компьютере уведомлений по расписанию нет: плагин телефонный.
    if (!AppPlatform.isPhone || !settings.lessonReminders || schedule == null) {
      await port.replace(const []);
      return 0;
    }

    final List<LessonReminder> reminders = planLessonReminders(
      days: schedule.days,
      before: settings.reminderLead,
      now: ref.read(clockProvider)(),
    );
    await port.replace(reminders);
    return reminders.length;
  }
}

/// Сколько пар в расписании ждёт напоминания — для подписи в настройках.
final plannedRemindersProvider = Provider<int>(
  (ref) => ref.watch(reminderSchedulerProvider).value ?? 0,
);
