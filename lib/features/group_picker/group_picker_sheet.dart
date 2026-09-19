import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mitso/mitso_client.dart';
import '../../data/models/group_ref.dart';
import '../../state/mitso_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_transitions.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/m3_bottom_sheet.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/segmented_list.dart';

/// Выбор расписания: группы (факультет → форма обучения → курс → группа) или
/// преподавателя (поиск по списку сайта).
///
/// Списки — те же, что в формах на apps.mitso.by, и загружаются по мере
/// выбора.
///
/// Модальный нижний лист открывается на половину экрана и тянется до полного
/// (bottom sheets → Guidelines → Visibility): списки длинные.
Future<void> showGroupPicker(BuildContext context) {
  return showM3ModalBottomSheet<void>(
    context: context,
    halfExpandedFirst: true,
    builder: (context, scrollController) =>
        _GroupPickerSheet(scrollController: scrollController),
  );
}

/// Чьё расписание выбирают.
enum _Mode {
  group('Группа'),
  teacher('Преподаватель');

  const _Mode(this.label);

  final String label;
}

enum _Step {
  faculty('Факультет'),
  form('Форма обучения'),
  course('Курс'),
  group('Группа');

  const _Step(this.title);

  final String title;
}

class _GroupPickerSheet extends ConsumerStatefulWidget {
  const _GroupPickerSheet({required this.scrollController});

  /// Прокрутка содержимого, общая с перетаскиванием листа.
  final ScrollController scrollController;

  @override
  ConsumerState<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends ConsumerState<_GroupPickerSheet> {
  late _Mode _mode = ref.read(scheduleTargetProvider) is TeacherTarget
      ? _Mode.teacher
      : _Mode.group;

  MitsoOption? _faculty;
  MitsoOption? _form;
  MitsoOption? _course;

  /// Список преподавателей и строка поиска по нему.
  Future<List<String>>? _teachers;
  String _query = '';

  /// Последний переход был назад — для направления shared axis.
  bool _backward = false;

  /// Запросы по шагам. Хранятся, чтобы перестроение и возврат назад не
  /// дёргали сайт повторно.
  final Map<String, Future<List<MitsoOption>>> _requests = {};

  _Step get _step => _course != null
      ? _Step.group
      : _form != null
      ? _Step.course
      : _faculty != null
      ? _Step.form
      : _Step.faculty;

  /// Шаг вместе с выбором до него: форма обучения другого факультета — уже
  /// другая страница.
  String get _pageKey =>
      '${_step.name}|${_faculty?.id}|${_form?.id}|${_course?.id}';

  Future<List<MitsoOption>> get _options =>
      _requests.putIfAbsent(_pageKey, _load);

  Future<List<MitsoOption>> _load() async {
    final MitsoApi api = await ref.read(mitsoApiProvider.future);
    return switch (_step) {
      _Step.faculty => api.faculties(),
      _Step.form => api.forms(_faculty!.id),
      _Step.course => api.courses(_faculty!.id, _form!.id),
      _Step.group => api.groups(_faculty!.id, _form!.id, _course!.id),
    };
  }

  void _retry() {
    setState(() {
      _requests.remove(_pageKey);
    });
  }

  void _choose(MitsoOption option) {
    if (_step == _Step.group) {
      ref
          .read(scheduleTargetProvider.notifier)
          .select(
            GroupTarget(
              GroupRef(
                facultyId: _faculty!.id,
                facultyName: _faculty!.name,
                formId: _form!.id,
                formName: _form!.name,
                courseId: _course!.id,
                courseName: _course!.name,
                groupId: option.id,
                groupName: option.name,
              ),
            ),
          );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _backward = false;
      switch (_step) {
        case _Step.faculty:
          _faculty = option;
        case _Step.form:
          _form = option;
        case _Step.course:
          _course = option;
        case _Step.group:
      }
    });
  }

  void _back() {
    setState(() {
      _backward = true;
      switch (_step) {
        case _Step.faculty:
          return;
        case _Step.form:
          _faculty = null;
        case _Step.course:
          _form = null;
        case _Step.group:
          _course = null;
      }
    });
  }

  /// Выбранный преподаватель — его строка отмечена в списке.
  void _chooseTeacher(String name) {
    ref.read(scheduleTargetProvider.notifier).select(TeacherTarget(name));
    Navigator.of(context).pop();
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      // Список преподавателей грузится только когда он понадобился.
      if (mode == _Mode.teacher) {
        _teachers ??= Future<List<String>>(() async {
          final MitsoApi api = await ref.read(mitsoApiProvider.future);
          return api.teachers();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScheduleTarget? current = ref.watch(scheduleTargetProvider);
    final GroupRef? currentGroup = current is GroupTarget
        ? current.group
        : null;

    // Одна прокрутка на весь лист: шаги сменяются внутри неё, поэтому
    // контроллер листа всегда привязан к одному списку.
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        // Два взаимоисключающих варианта — connected button group, как
        // переключатель недели на расписании.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space200,
              0,
              AppSpacing.space200,
              AppSpacing.space150,
            ),
            child: ConnectedButtonGroup<_Mode>(
              values: _Mode.values,
              labelOf: (mode) => mode.label,
              selected: _mode,
              onSelected: _setMode,
            ),
          ),
        ),
        if (_mode == _Mode.group)
          SliverToBoxAdapter(
            child: PageTransitionSwitcher(
              duration: AppTransitions.sharedAxisDuration,
              reverse: _backward,
              layoutBuilder: (entries) =>
                  Stack(alignment: Alignment.topCenter, children: entries),
              transitionBuilder: (child, animation, secondaryAnimation) =>
                  M3SharedAxisTransition(
                    animation: animation,
                    secondaryAnimation: secondaryAnimation,
                    child: child,
                  ),
              child: _StepPage(
                key: ValueKey(_pageKey),
                step: _step,
                breadcrumb: [
                  _faculty?.name,
                  _form?.name,
                  _course?.name,
                ].whereType<String>().join(' · '),
                options: _options,
                isCurrent: (option) =>
                    _step == _Step.group &&
                    currentGroup?.groupId == option.id &&
                    currentGroup?.courseId == _course?.id,
                onBack: _step == _Step.faculty ? null : _back,
                onChoose: _choose,
                onRetry: _retry,
              ),
            ),
          )
        else
          ..._teacherSlivers(current),
      ],
    );
  }

  /// Поиск и список преподавателей: имён под две сотни, без поиска искать
  /// себя в них долго.
  List<Widget> _teacherSlivers(ScheduleTarget? current) {
    final String? selected = current is TeacherTarget ? current.name : null;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space200,
            0,
            AppSpacing.space200,
            AppSpacing.space150,
          ),
          child: TextField(
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Фамилия',
              prefixIcon: Icon(Symbols.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
      ),
      FutureBuilder<List<String>>(
        future: _teachers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: _PickerMessage(
                text: messageOf(snapshot.error!),
                onRetry: () => setState(() => _teachers = null),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.space600),
                child: Center(child: M3LoadingIndicator()),
              ),
            );
          }

          final String query = _query.toLowerCase();
          final List<String> names = [
            for (final String name in snapshot.data!)
              if (query.isEmpty || name.toLowerCase().contains(query)) name,
          ];
          if (names.isEmpty) {
            return const SliverToBoxAdapter(
              child: _PickerMessage(text: 'Никого не нашлось'),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space200,
              0,
              AppSpacing.space200,
              AppSpacing.space400,
            ),
            sliver: SliverList.builder(
              itemCount: names.length,
              itemBuilder: (context, index) => SegmentedList(
                children: [
                  M3ListItem(
                    headline: Text(names[index]),
                    trailing: names[index] == selected
                        ? const Icon(Symbols.check)
                        : null,
                    selected: names[index] == selected,
                    onTap: () => _chooseTeacher(names[index]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }
}

/// Сообщение в листе: ошибка загрузки или пустой поиск.
class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space200,
      vertical: AppSpacing.space400,
    ),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium!.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.space200),
          M3Button(
            onPressed: onRetry,
            color: M3ButtonColor.tonal,
            child: const Text('Повторить'),
          ),
        ],
      ],
    ),
  );
}

/// Один шаг выбора: заголовок и список вариантов.
class _StepPage extends StatelessWidget {
  const _StepPage({
    super.key,
    required this.step,
    required this.breadcrumb,
    required this.options,
    required this.isCurrent,
    required this.onBack,
    required this.onChoose,
    required this.onRetry,
  });

  final _Step step;
  final String breadcrumb;
  final Future<List<MitsoOption>> options;
  final bool Function(MitsoOption option) isCurrent;
  final VoidCallback? onBack;
  final ValueChanged<MitsoOption> onChoose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
          child: Row(
            children: [
              if (onBack != null)
                M3IconButton(
                  onPressed: onBack,
                  icon: const Icon(Symbols.arrow_back),
                  color: M3IconButtonColor.standard,
                  tooltip: 'Назад',
                )
              else
                const SizedBox(width: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        step.title,
                        style: context.text.headlineSmall,
                      ),
                    ),
                    if (breadcrumb.isNotEmpty)
                      Text(
                        breadcrumb,
                        style: context.text.labelLarge!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (context) => FutureBuilder<List<MitsoOption>>(
            future: options,
            builder: (context, snapshot) {
              final Widget body;
              if (snapshot.hasError) {
                body = _LoadError(
                  key: const ValueKey('error'),
                  message: snapshot.error is MitsoException
                      ? (snapshot.error! as MitsoException).message
                      : 'Не удалось загрузить список.',
                  onRetry: onRetry,
                );
              } else if (!snapshot.hasData) {
                body = const Padding(
                  key: ValueKey('loading'),
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: M3LoadingIndicator(
                      semanticsLabel: 'Загрузка списка',
                    ),
                  ),
                );
              } else if (snapshot.data!.isEmpty) {
                body = _LoadError(
                  key: const ValueKey('empty'),
                  message: 'Список пуст.',
                  onRetry: onRetry,
                );
              } else {
                body = Padding(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space200,
                    AppSpacing.space50,
                    AppSpacing.space200,
                    AppSpacing.space300,
                  ),
                  child: SegmentedList(
                    children: [
                      // Текущая группа — выбранный пункт: цвет и галочка
                      // (lists → Accessibility, выбор не только цветом).
                      for (final MitsoOption option in snapshot.data!)
                        M3ListItem(
                          headline: Text(option.name),
                          trailing: Icon(
                            isCurrent(option)
                                ? Symbols.check
                                : Symbols.chevron_right,
                          ),
                          selected: isCurrent(option),
                          onTap: () => onChoose(option),
                        ),
                    ],
                  ),
                );
              }

              // Индикатор и список не связаны пространственно — fade through
              // (MDC Motion.md: «Tapping a refresh icon»).
              return PageTransitionSwitcher(
                duration: AppTransitions.fadeThroughDuration,
                layoutBuilder: (entries) =>
                    Stack(alignment: Alignment.topCenter, children: entries),
                transitionBuilder: (child, animation, secondaryAnimation) =>
                    M3FadeThroughTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      child: child,
                    ),
                child: body,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.cloud_off,
            size: 40,
            opticalSize: 40,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 16),
          M3Button(
            onPressed: onRetry,
            color: M3ButtonColor.tonal,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
