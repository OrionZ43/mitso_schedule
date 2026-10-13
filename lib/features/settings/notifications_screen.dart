import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/balance_alerts.dart';
import '../../data/balance_background.dart';
import '../../data/models/student_account.dart';
import '../../data/schedule_watch.dart';
import '../../state/reminders_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/student_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_filter_chip.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_switch.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';

/// Экран «Уведомления»: каждое сообщение включается отдельно.
///
/// Вынесен из настроек, чтобы их не загромождать: там остаётся одна строка с
/// перечислением включённого.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final StudentAccount? account = ref.watch(studentControllerProvider).value;
    final double margin = AppSpacing.screenMargin(context);

    /// Включение любого уведомления требует разрешения Android 13+.
    Future<bool> allowed(bool value) async =>
        !value ||
        await ref.read(lessonReminderPortProvider).requestPermission();

    return Scaffold(
      appBar: M3SmallAppBar(
        title: 'Уведомления',
        leading: M3IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Symbols.arrow_back),
          color: M3IconButtonColor.standard,
          tooltip: 'Назад',
        ),
      ),
      body: M3AppBarSettle(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              sliver: SliverList.list(
                children: [
                  // ─── Пары: напоминание перед началом занятия.
                  const SectionHeader('Пары'),
                  SegmentedList(
                    children: [
                      _Toggle(
                        icon: Symbols.notifications_active,
                        headline: 'Перед началом пары',
                        supporting: settings.lessonReminders
                            ? 'Уведомление '
                                  '${leadLabel(settings.reminderLead).toLowerCase()} '
                                  'до начала'
                            : 'Чтобы не прийти к шапочному разбору',
                        value: settings.lessonReminders,
                        onChanged: (value) async {
                          if (!await allowed(value)) return;
                          controller.setLessonReminders(value);
                        },
                      ),
                    ],
                  ),
                  if (settings.lessonReminders)
                    _LeadPicker(
                      selected: settings.reminderLead,
                      onSelected: controller.setReminderLead,
                    ),

                  // ─── Расписание: что приложение заметило на сайте.
                  const SectionHeader('Расписание'),
                  SegmentedList(
                    children: [
                      _Toggle(
                        icon: Symbols.edit_calendar,
                        headline: 'Расписание изменилось',
                        supporting:
                            'Пару добавили, перенесли или убрали — '
                            'приложение проверяет раз в три часа',
                        value: settings.scheduleChanges,
                        onChanged: (value) async {
                          if (!await allowed(value)) return;
                          controller.setScheduleChanges(value);
                          await _syncWatch(ref);
                        },
                      ),
                      _Toggle(
                        icon: Symbols.event_available,
                        headline: 'Новая неделя',
                        supporting:
                            'Сайт выложил следующую неделю: сколько пар и '
                            'есть ли зачёты',
                        value: settings.newWeekAlerts,
                        onChanged: (value) async {
                          if (!await allowed(value)) return;
                          controller.setNewWeekAlerts(value);
                          await _syncWatch(ref);
                        },
                      ),
                      _Toggle(
                        icon: Symbols.bedtime,
                        headline: 'Каким будет завтра',
                        supporting:
                            'Вечером в 20:00: сколько пар, во сколько начало '
                            'и есть ли окна',
                        value: settings.dayDigest,
                        onChanged: (value) async {
                          if (!await allowed(value)) return;
                          controller.setDayDigest(value);
                        },
                      ),
                      _Toggle(
                        icon: Symbols.priority_high,
                        headline: 'Зачёты и экзамены',
                        supporting: 'Накануне вечером, в 19:00',
                        value: settings.assessmentAlerts,
                        onChanged: (value) async {
                          if (!await allowed(value)) return;
                          controller.setAssessmentAlerts(value);
                          await _syncWatch(ref);
                        },
                      ),
                    ],
                  ),

                  // ─── Лицевой счёт: только когда он подключён.
                  if (account != null) ...[
                    const SectionHeader('Лицевой счёт'),
                    SegmentedList(
                      children: [
                        _Toggle(
                          icon: Symbols.account_balance_wallet,
                          headline: 'Задолженность',
                          supporting:
                              'Приложение проверяет счёт в фоне и присылает '
                              'уведомление, когда появляется долг',
                          value: settings.balanceAlerts,
                          onChanged: (value) async {
                            if (value &&
                                !await BalanceAlerts.requestPermission()) {
                              return;
                            }
                            controller.setBalanceAlerts(value);
                            await BalanceBackground.sync(enabled: value);
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.space200),
                  Text(
                    'Звук, вибрацию и важность каждого уведомления настраивает '
                    'Android — в настройках приложения.',
                    style: context.text.bodySmall!.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space800),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Фоновая проверка нужна, пока включено хоть одно уведомление о
  /// расписании.
  static Future<void> _syncWatch(WidgetRef ref) async {
    await ScheduleWatch.sync(
      enabled: ref.read(settingsControllerProvider).watchesSchedule,
    );
  }
}

/// Пункт-переключатель: одинаковый для всех уведомлений.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.headline,
    required this.supporting,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String headline;
  final String supporting;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return M3ListItem(
      leading: Icon(icon),
      headline: Text(headline),
      supporting: Text(supporting),
      trailing: ExcludeSemantics(
        child: M3Switch(value: value, onChanged: onChanged),
      ),
      onTap: () => onChanged(!value),
      semanticsLabel:
          '$headline, ${value ? 'включено' : 'выключено'}. $supporting',
    );
  }
}

/// «За 15 минут», «За час», «За 1 ч 30 мин».
String leadLabel(Duration lead) {
  final int minutes = lead.inMinutes;
  if (minutes == 60) return 'За час';
  if (minutes < 60) return 'За $minutes мин';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? 'За $hours ч' : 'За $hours ч $rest мин';
}

/// За сколько напоминать: готовые сроки и свой.
class _LeadPicker extends StatelessWidget {
  const _LeadPicker({required this.selected, required this.onSelected});

  final Duration selected;
  final ValueChanged<Duration> onSelected;

  static const List<int> _presets = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final bool custom = !_presets.contains(selected.inMinutes);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space150),
      child: Wrap(
        spacing: AppSpacing.space100,
        runSpacing: AppSpacing.space100,
        children: [
          for (final int minutes in _presets)
            M3FilterChip(
              label: Text(leadLabel(Duration(minutes: minutes))),
              selected: selected.inMinutes == minutes,
              onSelected: (_) => onSelected(Duration(minutes: minutes)),
            ),
          M3FilterChip(
            label: Text(custom ? leadLabel(selected) : 'Свой срок'),
            selected: custom,
            onSelected: (_) => _askCustom(context),
          ),
        ],
      ),
    );
  }

  Future<void> _askCustom(BuildContext context) async {
    final int? minutes = await showDialog<int>(
      context: context,
      builder: (context) => _CustomLeadDialog(minutes: selected.inMinutes),
    );
    if (minutes != null && minutes > 0) {
      onSelected(Duration(minutes: minutes));
    }
  }
}

/// Ввод своего срока. Поле принадлежит диалогу: закрывается он с анимацией,
/// и контроллер должен дожить до её конца.
class _CustomLeadDialog extends StatefulWidget {
  const _CustomLeadDialog({required this.minutes});

  final int minutes;

  @override
  State<_CustomLeadDialog> createState() => _CustomLeadDialogState();
}

class _CustomLeadDialogState extends State<_CustomLeadDialog> {
  late final TextEditingController _field = TextEditingController(
    text: '${widget.minutes}',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done([String? value]) =>
      Navigator.of(context).pop(int.tryParse(value ?? _field.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Symbols.timer),
      title: const Text('За сколько напоминать?'),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Минут до начала',
          helperText: 'От 1 до 180',
          border: OutlineInputBorder(),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        onSubmitted: _done,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(onPressed: () => _done(), child: const Text('Готово')),
      ],
    );
  }
}
