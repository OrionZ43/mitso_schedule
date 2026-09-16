import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/group_ref.dart';
import '../../state/mitso_providers.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_color_schemes.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/segmented_list.dart';
import '../group_picker/group_picker_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.scrollController});

  /// Прокрутка раздела — оболочка возвращает её к началу при повторном
  /// выборе раздела в navigation bar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Text(
            'Профиль',
            style: context.text.headlineMedium!.emphasized,
          ),
        ),
        const SizedBox(height: 18),
        _GroupHeader(group: ref.watch(selectedGroupProvider)),
        _SectionTitle('Подгруппа'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConnectedButtonGroup<int>(
            values: const [0, 1, 2],
            labelOf: (value) => switch (value) {
              1 => '1-я',
              2 => '2-я',
              _ => 'Обе',
            },
            selected: settings.subgroup ?? 0,
            onSelected: (value) =>
                controller.setSubgroup(value == 0 ? null : value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 10, 26, 0),
          child: Text(
            settings.subgroup == null
                ? 'Лабораторные и языки показываются для обеих подгрупп.'
                : 'Занятия другой подгруппы скрыты из расписания.',
            style: context.text.bodyMedium!.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        _SectionTitle('Настройки'),
        _SegmentedSection(
          children: [
            SwitchListTile(
              secondary: const Icon(Symbols.dark_mode),
              title: const Text('Тёмная тема'),
              subtitle: Text(settings.themeSubtitle),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: controller.setDark,
            ),
            SwitchListTile(
              secondary: const Icon(Symbols.palette),
              title: const Text('Динамические цвета'),
              subtitle: const Text('Material You · из обоев'),
              value: settings.dynamicColor,
              onChanged: controller.setDynamicColor,
            ),
            SwitchListTile(
              secondary: const Icon(Symbols.notifications),
              title: const Text('Напоминать о паре'),
              subtitle: const Text('За 15 минут до начала'),
              value: settings.lessonReminder,
              onChanged: controller.setLessonReminder,
            ),
          ],
        ),
        _SectionTitle('Палитра'),
        _PalettePicker(
          selected: settings.palette,
          enabled: !settings.dynamicColor,
          onSelected: controller.setPalette,
        ),
      ],
    );
  }
}

/// Выбранная группа: её расписание показывается на главной.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final GroupRef? group;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppShapes.all(AppShapes.extraLargeIncreased),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.school, size: 36, color: colors.onPrimary),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group?.groupName ?? 'Группа не выбрана',
                      style: context.text.titleLarge!.emphasized.copyWith(
                        height: 1.25,
                      ),
                    ),
                    if (group != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: group!.courseName,
                            background: colors.primaryContainer,
                            foreground: colors.onPrimaryContainer,
                          ),
                          _InfoChip(
                            label: group!.facultyName,
                            background: colors.surface,
                            foreground: colors.onSurfaceVariant,
                          ),
                          _InfoChip(
                            label: group!.formName,
                            background: colors.surface,
                            foreground: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => showGroupPicker(context),
            icon: const Icon(Symbols.groups),
            label: Text(group == null ? 'Выбрать группу' : 'Сменить группу'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.all(AppShapes.chip),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: context.text.bodyMedium!.copyWith(
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final AppPalette selected;

  /// Палитра применяется, только когда динамические цвета выключены.
  final bool enabled;

  final ValueChanged<AppPalette> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final AppPalette palette in AppPalette.values)
              ChoiceChip(
                label: Text(palette.label),
                selected: palette == selected,
                onSelected: enabled ? (_) => onSelected(palette) : null,
                // Кружок — итоговый primary, а не сид: вариант expressive
                // поворачивает оттенок, и сид ввёл бы в заблуждение.
                avatar: CircleAvatar(
                  backgroundColor: AppColorSchemes.primaryOf(
                    palette,
                    Theme.of(context).brightness,
                  ),
                  radius: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 12),
      child: Text(
        title,
        style: context.text.bodyMedium!.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _SegmentedSection extends StatelessWidget {
  const _SegmentedSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedList(children: children),
    );
  }
}
