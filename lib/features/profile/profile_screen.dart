import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_platform.dart';
import '../../data/balance_alerts.dart';
import '../../data/balance_background.dart';
import '../../data/mitso/mitso_client.dart';
import '../../data/models/student_account.dart';
import '../../state/mitso_providers.dart';
import '../../state/settings_controller.dart';
import '../../state/student_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/m3_switch.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import '../group_picker/group_picker_sheet.dart';
import '../home/home_shell.dart';
import '../settings/settings_screen.dart';
import '../updater/update_provider.dart';
import 'link_account_sheet.dart';

/// Профиль: студент, группа, лицевой счёт и доступ к СДО. Настройки
/// приложения — за шестерёнкой в app bar.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(studentControllerProvider.notifier).refresh();
    } catch (error) {
      appSnackbarHost.currentState?.show(messageOf(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Метка переключателя для screen reader.
  String _alertsSemantics(Settings settings) {
    final String state = settings.balanceAlerts ? 'включено' : 'выключено';
    return 'Сообщать о задолженности, $state';
  }

  /// Уведомления требуют разрешения Android 13+; без него переключатель
  /// остаётся выключенным.
  Future<void> _setAlerts(bool value) async {
    if (value && !await BalanceAlerts.requestPermission()) return;
    ref.read(settingsControllerProvider.notifier).setBalanceAlerts(value);
    await BalanceBackground.sync(enabled: value);
  }

  /// Отключение счёта стирает сохранённые данные — спрашиваем подтверждение
  /// (dialogs → Usage: подтверждение действия, которое трудно отменить).
  Future<void> _confirmUnlink() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.link_off),
        title: const Text('Отключить лицевой счёт?'),
        content: const Text(
          'Баланс и доступ к СДО пропадут из профиля. Счёт можно подключить '
          'снова по номеру.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(studentControllerProvider.notifier).unlink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final AsyncValue<StudentAccount?> student = ref.watch(
      studentControllerProvider,
    );
    final StudentAccount? account = student.value;
    final ScheduleTarget? target = ref.watch(scheduleTargetProvider);
    // Лицевой счёт — студенческий: преподавателю он ни к чему.
    final bool isStudent = target is! TeacherTarget;
    final bool hasUpdate = ref.watch(updateBadgeProvider);
    final double margin = AppSpacing.screenMargin(context);

    return M3AppBarSettle(
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverMediumFlexibleAppBar(
            title: 'Профиль',
            subtitle: account?.shortName,
            actions: [
              M3IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
                // Точка на значке настроек, пока обновление не показано:
                // обновления живут в разделе «О приложении».
                icon: Badge(
                  isLabelVisible: hasUpdate,
                  child: const Icon(Symbols.settings),
                ),
                color: M3IconButtonColor.standard,
                tooltip: hasUpdate
                    ? 'Настройки, доступно обновление'
                    : 'Настройки',
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            sliver: SliverList.list(
              children: [
                // Чьё расписание показывает приложение — первым делом.
                const SectionHeader('Расписание'),
                SegmentedList(
                  children: [
                    M3ListItem(
                      leading: _Avatar(
                        icon: target is TeacherTarget
                            ? Symbols.co_present
                            : Symbols.school,
                      ),
                      overline: target == null
                          ? null
                          : Text(
                              target is TeacherTarget
                                  ? 'Преподаватель'
                                  : 'Группа',
                            ),
                      headline: Text(target?.title ?? 'Не выбрано'),
                      supporting: Text(
                        target is GroupTarget
                            ? target.group.details
                            : 'Расписание с apps.mitso.by',
                      ),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () => showGroupPicker(context),
                    ),
                  ],
                ),

                if (isStudent) ...[
                  const SectionHeader('Лицевой счёт'),
                  if (account == null)
                    _LinkCard(loading: student.isLoading, error: student.error)
                  else ...[
                    SegmentedList(
                      children: [
                        M3ListItem(
                          leading: const _Avatar(icon: Symbols.person),
                          overline: Text('Счёт № ${account.number}'),
                          headline: Text(account.fullName),
                          supporting: const Text('Данные с student.mitso.by'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space150),
                    _BalanceCard(
                      account: account,
                      refreshing: _refreshing,
                      onRefresh: _refresh,
                    ),
                    const SizedBox(height: AppSpacing.space150),
                    // Всё про счёт в одном месте, а не половина в настройках.
                    SegmentedList(
                      children: [
                        if (AppPlatform.isPhone)
                          M3ListItem(
                            leading: const Icon(Symbols.notifications),
                            headline: const Text('Сообщать о задолженности'),
                            supporting: const Text(
                              'Приложение проверяет счёт в фоне и присылает '
                              'уведомление, когда появляется долг',
                            ),
                            trailing: ExcludeSemantics(
                              child: M3Switch(
                                value: settings.balanceAlerts,
                                onChanged: _setAlerts,
                              ),
                            ),
                            onTap: () => _setAlerts(!settings.balanceAlerts),
                            semanticsLabel: _alertsSemantics(settings),
                          ),
                        M3ListItem(
                          leading: const Icon(Symbols.link_off),
                          headline: const Text('Отключить счёт'),
                          supporting: const Text(
                            'Баланс и доступ к СДО будут стёрты',
                          ),
                          onTap: _confirmUnlink,
                        ),
                      ],
                    ),
                  ],

                  if (account?.moodle != null) ...[
                    const SectionHeader('Дистанционное обучение'),
                    _MoodleCard(moodle: account!.moodle!),
                  ],
                ],
                const SizedBox(height: AppSpacing.space800),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Счёт не подключён: объяснение и кнопка.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.loading, required this.error});

  final bool loading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Баланс и доступ к СДО',
              style: context.text.titleMedium!.emphasized,
            ),
            const SizedBox(height: AppSpacing.space100),
            Text(
              error == null
                  ? 'Подключите лицевой счёт — приложение покажет баланс, '
                        'задолженность и логин с паролем от СДО.'
                  : messageOf(error!),
              style: context.text.bodyMedium!.copyWith(
                color: error == null ? colors.onSurfaceVariant : colors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.space200),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: M3Button(
                onPressed: loading ? null : () => showLinkAccountSheet(context),
                child: loading
                    ? M3LoadingIndicator(
                        size: 24,
                        color: colors.onPrimary,
                        semanticsLabel: 'Подключение счёта',
                      )
                    : const Text('Подключить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Баланс: крупная сумма, долг и пеня, дата и обновление.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.account,
    required this.refreshing,
    required this.onRefresh,
  });

  final StudentAccount account;
  final bool refreshing;
  final VoidCallback onRefresh;

  /// «1,61 BYN»: на сайте суммы в белорусских рублях.
  static String money(double value) => NumberFormat.currency(
    locale: 'ru',
    symbol: 'BYN',
    decimalDigits: 2,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool debt = account.inDebt;
    // Долг меняет всю карточку на роли error: цветом и текстом сразу видно,
    // что что-то не так (color → «Use error roles for critical states»).
    final Color container = debt
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    final Color onContainer = debt ? colors.onErrorContainer : colors.onSurface;
    final Color secondary = debt
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;

    return Card.filled(
      color: container,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Баланс на ${DateFormat('d MMMM', 'ru').format(account.asOf)}',
              style: context.text.bodyMedium!.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.space50),
            Text(
              money(account.balance),
              style: context.text.displaySmall!.copyWith(
                color: onContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (debt) ...[
              const SizedBox(height: AppSpacing.space100),
              Row(
                children: [
                  Icon(Symbols.warning, size: 18, color: onContainer),
                  const SizedBox(width: AppSpacing.space100),
                  Expanded(
                    child: Text(
                      'Есть задолженность',
                      style: context.text.labelLarge!.copyWith(
                        color: onContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (account.debt != 0 || account.penalty != 0) ...[
              const SizedBox(height: AppSpacing.space150),
              _Amount(
                label: 'Основной долг',
                value: account.debt,
                color: onContainer,
                labelColor: secondary,
              ),
              _Amount(
                label: 'Пеня и проценты',
                value: account.penalty,
                color: onContainer,
                labelColor: secondary,
              ),
            ],
            const SizedBox(height: AppSpacing.space150),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сайт обновляет счёт раз в сутки в 13:00',
                    style: context.text.bodySmall!.copyWith(color: secondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.space100),
                M3Button(
                  onPressed: refreshing ? null : onRefresh,
                  // На красной карточке tonal-кнопка спорила бы с фоном.
                  color: debt ? M3ButtonColor.outlined : M3ButtonColor.tonal,
                  size: M3ButtonSize.small,
                  child: refreshing
                      ? M3LoadingIndicator(
                          size: 18,
                          color: debt
                              ? onContainer
                              : colors.onSecondaryContainer,
                          semanticsLabel: 'Обновление баланса',
                        )
                      : const Text('Обновить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
    required this.labelColor,
  });

  final String label;
  final double value;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space50),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium!.copyWith(color: labelColor),
            ),
          ),
          Text(
            _BalanceCard.money(value),
            style: context.text.bodyMedium!.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Доступ к СДО: вход одной кнопкой и данные с возможностью скопировать.
class _MoodleCard extends StatefulWidget {
  const _MoodleCard({required this.moodle});

  final MoodleAccess moodle;

  @override
  State<_MoodleCard> createState() => _MoodleCardState();
}

class _MoodleCardState extends State<_MoodleCard> {
  bool _revealed = false;

  Future<void> _open() async {
    // Пароль в буфере: форма входа СДО его не подставляет.
    await Clipboard.setData(ClipboardData(text: widget.moodle.password));
    final bool opened = await launchUrl(
      Uri.parse(MoodleAccess.url),
      mode: LaunchMode.externalApplication,
    );
    appSnackbarHost.currentState?.show(
      opened
          ? 'Пароль скопирован — вставьте в форму входа'
          : 'Не удалось открыть сайт СДО',
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    appSnackbarHost.currentState?.show('$label скопирован');
  }

  @override
  Widget build(BuildContext context) {
    final MoodleAccess moodle = widget.moodle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedList(
          children: [
            M3ListItem(
              leading: const Icon(Symbols.person),
              overline: const Text('Логин'),
              headline: Text(moodle.login),
              trailing: const Icon(Symbols.content_copy),
              onTap: () => _copy('Логин', moodle.login),
              semanticsLabel: 'Логин СДО ${moodle.login}, скопировать',
            ),
            M3ListItem(
              leading: const Icon(Symbols.key),
              overline: const Text('Пароль'),
              headline: Text(
                _revealed ? moodle.password : '•' * moodle.password.length,
              ),
              trailing: Icon(
                _revealed ? Symbols.visibility_off : Symbols.visibility,
              ),
              onTap: () => setState(() => _revealed = !_revealed),
              onLongPress: () => _copy('Пароль', moodle.password),
              semanticsLabel: _revealed
                  ? 'Пароль СДО ${moodle.password}, скрыть'
                  : 'Пароль СДО скрыт, показать',
            ),
            if (moodle.group.isNotEmpty)
              M3ListItem(
                leading: const Icon(Symbols.groups),
                overline: const Text('Группа в СДО'),
                headline: Text(moodle.group),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space150),
        M3Button(
          onPressed: _open,
          icon: const Icon(Symbols.open_in_new),
          size: M3ButtonSize.medium,
          child: const Text('Войти в СДО'),
        ),
      ],
    );
  }
}

/// Аватар пункта списка: `ListTokens.ItemLeadingAvatar*` — 40dp,
/// primaryContainer / onPrimaryContainer.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.onPrimaryContainer),
    );
  }
}
