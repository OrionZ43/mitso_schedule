import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mitso/mitso_client.dart';
import '../../data/models/group_ref.dart';
import '../../data/models/student_account.dart';
import '../../state/mitso_providers.dart';
import '../../state/student_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import '../group_picker/group_picker_sheet.dart';
import '../home/home_shell.dart';
import '../settings/settings_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<StudentAccount?> student = ref.watch(
      studentControllerProvider,
    );
    final StudentAccount? account = student.value;
    final GroupRef? group = ref.watch(selectedGroupProvider);
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
                icon: const Icon(Symbols.settings),
                color: M3IconButtonColor.standard,
                tooltip: 'Настройки',
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            sliver: SliverList.list(
              children: [
                // Группа — пункт списка с одним действием: открыть выбор.
                SegmentedList(
                  children: [
                    M3ListItem(
                      leading: const _Avatar(icon: Symbols.school),
                      headline: Text(group?.groupName ?? 'Группа не выбрана'),
                      supporting: Text(
                        group == null
                            ? 'Расписание загружается с apps.mitso.by'
                            : group.details,
                      ),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () => showGroupPicker(context),
                    ),
                  ],
                ),

                const SectionHeader('Лицевой счёт'),
                if (account == null)
                  _LinkCard(loading: student.isLoading, error: student.error)
                else ...[
                  _BalanceCard(
                    account: account,
                    refreshing: _refreshing,
                    onRefresh: _refresh,
                  ),
                  const SizedBox(height: AppSpacing.space150),
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
                ],

                if (account?.moodle != null) ...[
                  const SectionHeader('Дистанционное обучение'),
                  _MoodleCard(moodle: account!.moodle!),
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

  /// «1,61 Br»: на сайте суммы в белорусских рублях.
  static String money(double value) => NumberFormat.currency(
    locale: 'ru',
    symbol: 'Br',
    decimalDigits: 2,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool debt = account.inDebt;
    final Color accent = debt ? colors.error : colors.primary;

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Баланс на ${DateFormat('d MMMM', 'ru').format(account.asOf)}',
              style: context.text.bodyMedium!.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space50),
            Text(
              money(account.balance),
              style: context.text.displaySmall!.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (debt) ...[
              const SizedBox(height: AppSpacing.space100),
              Row(
                children: [
                  Icon(Symbols.warning, size: 18, color: colors.error),
                  const SizedBox(width: AppSpacing.space100),
                  Expanded(
                    child: Text(
                      'Есть задолженность',
                      style: context.text.labelLarge!.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (account.debt != 0 || account.penalty != 0) ...[
              const SizedBox(height: AppSpacing.space150),
              _Amount(label: 'Основной долг', value: account.debt),
              _Amount(label: 'Пеня и проценты', value: account.penalty),
            ],
            const SizedBox(height: AppSpacing.space150),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сайт обновляет счёт раз в сутки в 13:00',
                    style: context.text.bodySmall!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space100),
                M3Button(
                  onPressed: refreshing ? null : onRefresh,
                  color: M3ButtonColor.tonal,
                  size: M3ButtonSize.small,
                  child: refreshing
                      ? M3LoadingIndicator(
                          size: 18,
                          color: colors.onSecondaryContainer,
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
  const _Amount({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space50),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            _BalanceCard.money(value),
            style: context.text.bodyMedium!.copyWith(
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
