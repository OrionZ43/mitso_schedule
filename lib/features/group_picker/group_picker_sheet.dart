import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mitso/mitso_client.dart';
import '../../data/models/group_ref.dart';
import '../../state/mitso_providers.dart';
import '../../theme/app_typography.dart';
import '../../widgets/m3_loading_indicator.dart';
import '../../widgets/segmented_list.dart';

/// Выбор группы: факультет → форма обучения → курс → группа.
///
/// Списки — те же, что в форме на apps.mitso.by, и загружаются по мере выбора.
Future<void> showGroupPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _GroupPickerSheet(),
  );
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
  const _GroupPickerSheet();

  @override
  ConsumerState<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends ConsumerState<_GroupPickerSheet> {
  MitsoOption? _faculty;
  MitsoOption? _form;
  MitsoOption? _course;

  /// Запрос текущего шага; хранится, чтобы перестроение не дёргало сайт.
  late Future<List<MitsoOption>> _options = _load();

  _Step get _step => _course != null
      ? _Step.group
      : _form != null
      ? _Step.course
      : _faculty != null
      ? _Step.form
      : _Step.faculty;

  Future<List<MitsoOption>> _load() async {
    final MitsoApi api = await ref.read(mitsoApiProvider.future);
    return switch (_step) {
      _Step.faculty => api.faculties(),
      _Step.form => api.forms(_faculty!.id),
      _Step.course => api.courses(_faculty!.id, _form!.id),
      _Step.group => api.groups(_faculty!.id, _form!.id, _course!.id),
    };
  }

  // Блок, а не стрелка: стрелка вернула бы Future из setState.
  void _reload() {
    setState(() {
      _options = _load();
    });
  }

  void _choose(MitsoOption option) {
    switch (_step) {
      case _Step.faculty:
        _faculty = option;
      case _Step.form:
        _form = option;
      case _Step.course:
        _course = option;
      case _Step.group:
        ref
            .read(selectedGroupProvider.notifier)
            .select(
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
            );
        Navigator.of(context).pop();
        return;
    }
    _reload();
  }

  void _back() {
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
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final GroupRef? current = ref.watch(selectedGroupProvider);
    final String breadcrumb = [
      _faculty?.name,
      _form?.name,
      _course?.name,
    ].whereType<String>().join(' · ');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
            child: Row(
              children: [
                if (_step != _Step.faculty)
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Symbols.arrow_back),
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
                          _step.title,
                          style: context.text.headlineSmall!.emphasized,
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
          Flexible(
            child: FutureBuilder<List<MitsoOption>>(
              future: _options,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(
                    message: snapshot.error is MitsoException
                        ? (snapshot.error! as MitsoException).message
                        : 'Не удалось загрузить список.',
                    onRetry: _reload,
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: M3LoadingIndicator(
                        semanticsLabel: 'Загрузка списка',
                      ),
                    ),
                  );
                }
                final List<MitsoOption> options = snapshot.data!;
                if (options.isEmpty) {
                  return _LoadError(message: 'Список пуст.', onRetry: _reload);
                }
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    SegmentedList(
                      children: [
                        for (final MitsoOption option in options)
                          ListTile(
                            title: Text(option.name),
                            trailing: Icon(
                              _step == _Step.group &&
                                      current?.groupId == option.id &&
                                      current?.courseId == _course?.id
                                  ? Symbols.check
                                  : Symbols.chevron_right,
                            ),
                            onTap: () => _choose(option),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

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
            size: 32,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
