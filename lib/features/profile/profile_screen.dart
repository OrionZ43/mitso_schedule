import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mitso/mitso_client.dart';
import '../../data/models/student_account.dart';
import '../../state/avatar_controller.dart';
import '../../data/models/lesson.dart';
import '../../data/teacher_load.dart';
import '../../state/mitso_providers.dart';
import '../../state/schedule_controller.dart';
import '../../state/season_controller.dart';
import '../../state/student_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/seasons.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/season_decor.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import '../../widgets/shape_avatar.dart';
import '../group_picker/group_picker_sheet.dart';
import '../home/home_shell.dart';
import '../settings/settings_screen.dart';
import '../updater/update_provider.dart';
import 'avatar_sheet.dart';
import 'link_account_sheet.dart';

/// Профиль: кто пользуется приложением, чьё расписание открыто, баланс
/// лицевого счёта и доступ к СДО.
///
/// Переключатели счёта (уведомление о долге, отключение) живут в настройках,
/// за шестерёнкой в app bar: в профиле — сведения, в настройках — управление.
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
    final ScheduleTarget? target = ref.watch(scheduleTargetProvider);
    // Лицевой счёт — студенческий: преподавателю он ни к чему.
    final bool isStudent = target is! TeacherTarget;
    final bool hasUpdate = ref.watch(updateBadgeProvider);
    final double margin = AppSpacing.screenMargin(context);
    final Season? season = ref.watch(activeSeasonProvider);

    return M3AppBarSettle(
      child: Stack(
        children: [
          // Картина сезона — на весь фон, позади профиля.
          if (season != null)
            Positioned.fill(
              child: SeasonBackdrop(season: season, page: SeasonPage.profile),
            ),
          CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverMediumFlexibleAppBar(
                title: 'Профиль',
                // Картина лежит под баром: в покое контейнер прозрачный.
                containerColor: season != null ? Colors.transparent : null,
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
                    _ProfileHero(
                      target: target,
                      account: account,
                      onPick: () => showGroupPicker(context),
                    ),

                    // Преподавателю — его нагрузка; счёта у него нет.
                    if (!isStudent) const _TeacherLoadSection(),

                    if (isStudent) ...[
                      const SectionHeader('Лицевой счёт'),
                      if (account == null)
                        _LinkCard(
                          loading: student.isLoading,
                          error: student.error,
                        )
                      else ...[
                        _BalanceCard(
                          account: account,
                          now: ref.watch(nowProvider),
                          refreshing: _refreshing,
                          onRefresh: _refresh,
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
        ],
      ),
    );
  }
}

/// Шапка профиля: кто пользуется приложением и чьё расписание он смотрит.
///
/// Единственный «hero moment» приложения
/// (https://m3.material.io/building-with-m3-expressive, «Combine tactics to
/// create hero moments»: их в продукте должно быть один-два). Собран из
/// четырёх тактик оттуда же: фигура из библиотеки форм на аватаре («Use a
/// variety of shapes»), контраст ролей primary и primaryContainer («Apply
/// rich and nuanced colors»), emphasized-заголовок («Guide attention with
/// typography») и вложенный контейнер с расписанием («Contain content for
/// emphasis»).
class _ProfileHero extends ConsumerWidget {
  const _ProfileHero({
    required this.target,
    required this.account,
    required this.onPick,
  });

  final ScheduleTarget? target;
  final StudentAccount? account;

  /// Открыть выбор группы или преподавателя.
  final VoidCallback onPick;

  /// Аватар крупный: это главный элемент экрана. Ряд 96 = 4 × 24dp,
  /// в шкале `ListTokens` таких размеров нет — аватар не пункт списка.
  static const double avatarSize = 96;

  /// Радиус шапки — `extra-large-increased`; отступ 20dp даёт вложенному
  /// контейнеру 32 − 20 = 12dp (medium) по правилу оптической скруглённости.
  static const double padding = AppSpacing.space250;

  /// Фамилия и имя одной буквой: «ИИ». У преподавателя инициалов нет —
  /// в шапке его расписание, а не он сам.
  String? initialsOf(StudentAccount? account) {
    final String? name = account?.fullName;
    if (name == null) return null;
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = context.colors;
    final ScheduleTarget? target = this.target;
    final bool teacher = target is TeacherTarget;
    // Открыто расписание преподавателя — в шапке он, а не владелец счёта:
    // счёт студенческий и к этому расписанию отношения не имеет.
    final StudentAccount? account = teacher ? null : this.account;
    final String? photo = ref.watch(avatarControllerProvider);

    return Card.filled(
      color: colors.primaryContainer,
      shape: AppShapes.rounded(AppShapes.extraLargeIncreased),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          children: [
            Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                ShapeAvatar(
                  // Круглая фигура с мягкими зубцами: аватар остаётся
                  // аватаром, но выбивается из прямоугольников экрана («Break
                  // from the surrounding shape style to draw attention»).
                  polygon: MaterialShapes.cookie9Sided,
                  size: avatarSize,
                  color: colors.primary,
                  onColor: colors.onPrimary,
                  image: photo == null
                      ? null
                      // Фото в файле крупнее аватара: декодируем под него.
                      : ResizeImage(
                          FileImage(File(photo)),
                          width:
                              (avatarSize *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                  initials: initialsOf(account),
                  icon: teacher ? Symbols.co_present : Symbols.school,
                ),
                // Сама фигура неинтерактивна (гайд: формы библиотеки — для
                // «non-interactive elements»), меняет фото кнопка рядом.
                M3IconButton(
                  onPressed: () => showAvatarSheet(context),
                  icon: const Icon(Symbols.photo_camera, fill: 1),
                  size: M3ButtonSize.extraSmall,
                  // Tonal: filled повторил бы цвет аватара и слился с ним.
                  color: M3IconButtonColor.tonal,
                  tooltip: photo == null
                      ? 'Добавить фото профиля'
                      : 'Сменить фото профиля',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space200),
            Text(
              account?.fullName ?? target?.title ?? 'Группа не выбрана',
              textAlign: TextAlign.center,
              style: context.text.headlineSmall!.emphasized.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space50),
            Text(
              target?.subtitle ?? 'Выберите группу или преподавателя',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space250),
            // Имя в заголовке — расписание отдельной плиткой; иначе группа
            // уже в заголовке, и остаётся только кнопка выбора.
            if (account != null && target != null)
              _HeroTarget(target: target, onTap: onPick)
            else
              M3Button(
                onPressed: onPick,
                icon: Icon(
                  target == null ? Symbols.add : Symbols.swap_horiz,
                  fill: 1,
                ),
                size: M3ButtonSize.medium,
                child: Text(
                  target == null
                      ? 'Выбрать расписание'
                      : teacher
                      ? 'Другой преподаватель'
                      : 'Другая группа',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Плитка внутри шапки: чьё расписание показывает приложение.
class _HeroTarget extends StatelessWidget {
  const _HeroTarget({required this.target, required this.onTap});

  final ScheduleTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool teacher = target is TeacherTarget;
    final String kind = teacher
        ? 'Расписание преподавателя'
        : 'Расписание группы';

    return Semantics(
      button: true,
      label: '$kind ${target.title}, сменить',
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: AppShapes.rounded(AppShapes.medium),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space200,
                vertical: AppSpacing.space150,
              ),
              child: Row(
                children: [
                  Icon(
                    teacher ? Symbols.co_present : Symbols.school,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.space150),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.title,
                          style: context.text.titleMedium!.emphasized,
                        ),
                        Text(
                          kind,
                          style: context.text.bodySmall!.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Symbols.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Нагрузка преподавателя за неделю: пар, групп, свободные дни.
///
/// У преподавателя нет лицевого счёта и СДО, поэтому профиль был пустым —
/// теперь там то, ради чего он сюда и зайдёт.
class _TeacherLoadSection extends ConsumerWidget {
  const _TeacherLoadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScheduleState? schedule = ref.watch(scheduleControllerProvider).value;
    if (schedule == null) return const SizedBox.shrink();

    final ScheduleWeek? week = weekOf(schedule.weeks, ref.watch(nowProvider));
    if (week == null) return const SizedBox.shrink();

    final TeacherLoad load = teacherLoadOf(week);
    if (load.isEmpty) return const SizedBox.shrink();

    final ColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Нагрузка'),
        Card.filled(
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  week.label,
                  style: context.text.bodyMedium!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space50),
                Text(
                  '${load.pairs} ${ScheduleDay.pairsWord(load.pairs)} · '
                  '${load.groups.length} ${_groupsWord(load.groups.length)}',
                  style: context.text.headlineSmall!.emphasized,
                ),
                if (load.busiestDay != null) ...[
                  const SizedBox(height: AppSpacing.space150),
                  _LoadLine(
                    icon: Symbols.trending_up,
                    text:
                        'Самый плотный день — '
                        '${load.busiestDay!.title.toLowerCase()}, '
                        '${load.busiestDay!.pairCount} '
                        '${ScheduleDay.pairsWord(load.busiestDay!.pairCount)}',
                  ),
                ],
                if (load.freeDays.isNotEmpty)
                  _LoadLine(
                    icon: Symbols.weekend,
                    text:
                        'Без пар: '
                        '${load.freeDays.map((d) => d.title.toLowerCase()).join(', ')}',
                  ),
              ],
            ),
          ),
        ),
        if (load.groups.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space150),
          SegmentedList(
            children: [
              for (final GroupLoad group in load.groups)
                M3ListItem(
                  leading: const Icon(Symbols.groups),
                  headline: Text(group.group),
                  trailing: Text(
                    '${group.pairs} ${ScheduleDay.pairsWord(group.pairs)}',
                    style: context.text.labelLarge!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _groupsWord(int n) {
    final int mod100 = n % 100;
    final int mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'групп';
    if (mod10 == 1) return 'группа';
    if (mod10 >= 2 && mod10 <= 4) return 'группы';
    return 'групп';
  }
}

/// Строка сводки: значок и текст.
class _LoadLine extends StatelessWidget {
  const _LoadLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = context.colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.space100),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium!.copyWith(color: color),
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
    required this.now,
    required this.refreshing,
    required this.onRefresh,
  });

  final StudentAccount account;

  /// Текущее время — чтобы написать, когда счёт проверяли.
  final DateTime now;

  final bool refreshing;
  final VoidCallback onRefresh;

  /// «проверено сегодня в 11:32», «проверено 3 дня назад».
  ///
  /// Дата в шапке — это дата сайта: он считает счёт раз в сутки и отстаёт на
  /// день-два. Когда приложение последний раз ходило на сайт — совсем другое
  /// дело, и раньше этого нигде не было видно.
  static String checkedLabel(DateTime fetchedAt, DateTime now) {
    final DateTime day = DateTime(
      fetchedAt.year,
      fetchedAt.month,
      fetchedAt.day,
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int days = today.difference(day).inDays;
    final String time = DateFormat.Hm('ru').format(fetchedAt);
    return switch (days) {
      <= 0 => 'Проверено сегодня в $time',
      1 => 'Проверено вчера в $time',
      _ => 'Проверено ${DateFormat('d MMMM', 'ru').format(fetchedAt)}',
    };
  }

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Счёт № ${account.number}',
                    style: context.text.bodyMedium!.copyWith(color: secondary),
                  ),
                ),
                Text(
                  'на ${DateFormat('d MMMM', 'ru').format(account.asOf)}',
                  style: context.text.bodyMedium!.copyWith(color: secondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space50),
            Text(
              money(account.balance),
              style: context.text.displaySmall!.emphasized.copyWith(
                color: onContainer,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkedLabel(account.fetchedAt, now),
                        style: context.text.bodySmall!.copyWith(
                          color: secondary,
                        ),
                      ),
                      Text(
                        'Сайт считает счёт раз в сутки в 13:00',
                        style: context.text.bodySmall!.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
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
