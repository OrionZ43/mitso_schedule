import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/group_ref.dart';
import '../../state/mitso_providers.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_color_schemes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/m3_filter_chip.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_switch.dart';
import '../../widgets/section_header.dart';
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
    final GroupRef? group = ref.watch(selectedGroupProvider);
    final double margin = AppSpacing.screenMargin(context);

    return M3AppBarSettle(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          const SliverMediumFlexibleAppBar(title: 'Профиль'),
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

                const SectionHeader('Подгруппа'),
                ConnectedButtonGroup<int>(
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
                _Hint(
                  settings.subgroup == null
                      ? 'Лабораторные и языки показываются для обеих подгрупп.'
                      : 'Занятия другой подгруппы скрыты из расписания.',
                ),

                // Три взаимоисключающих варианта — connected button group,
                // а не переключатель (switch → Guidelines → Usage).
                const SectionHeader('Тема'),
                ConnectedButtonGroup<ThemeMode>(
                  values: const [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark,
                  ],
                  labelOf: (mode) => switch (mode) {
                    ThemeMode.light => 'Светлая',
                    ThemeMode.dark => 'Тёмная',
                    ThemeMode.system => 'Системная',
                  },
                  selected: settings.themeMode,
                  onSelected: controller.setThemeMode,
                ),

                const SectionHeader('Цвета'),
                SegmentedList(
                  children: [
                    // Строка списка с переключателем: нажатие по всей строке
                    // переключает (lists → selection modes).
                    M3ListItem(
                      leading: const Icon(Symbols.palette),
                      headline: const Text('Динамические цвета'),
                      supporting: const Text('Цвета из обоев'),
                      trailing: ExcludeSemantics(
                        child: M3Switch(
                          value: settings.dynamicColor,
                          onChanged: controller.setDynamicColor,
                        ),
                      ),
                      onTap: () =>
                          controller.setDynamicColor(!settings.dynamicColor),
                      semanticsLabel:
                          'Динамические цвета, цвета из обоев, '
                          '${settings.dynamicColor ? 'включено' : 'выключено'}',
                    ),
                  ],
                ),
                _PalettePicker(
                  selected: settings.palette,
                  enabled: !settings.dynamicColor,
                  onSelected: controller.setPalette,
                ),
                const SizedBox(height: AppSpacing.space800),
              ],
            ),
          ),
        ],
      ),
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

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space200,
        AppSpacing.space100,
        AppSpacing.space200,
        0,
      ),
      child: Text(
        text,
        style: context.text.bodyMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Статичная палитра — фильтр-чипы с одиночным выбором (chips → Filter:
/// «single-select replaces radio buttons»). Образец цвета — ведущая иконка
/// 18dp. Пока включены динамические цвета, палитра не применяется и чипы
/// отключены.
class _PalettePicker extends StatelessWidget {
  const _PalettePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final AppPalette selected;
  final bool enabled;
  final ValueChanged<AppPalette> onSelected;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space150),
      child: Wrap(
        spacing: AppSpacing.space100,
        runSpacing: AppSpacing.space100,
        children: [
          for (final AppPalette palette in AppPalette.values)
            M3FilterChip(
              label: Text(palette.label),
              selected: palette == selected,
              onSelected: enabled ? (_) => onSelected(palette) : null,
              // Кружок — итоговый primary палитры, а не сид.
              leading: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColorSchemes.primaryOf(
                    palette,
                    brightness,
                  ).withValues(alpha: enabled ? 1 : 0.38),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
