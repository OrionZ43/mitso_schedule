import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_platform.dart';
import '../../data/wear_sync.dart';
import '../../state/app_icon_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_color_schemes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/m3_buttons.dart';
import '../../widgets/m3_filter_chip.dart';
import '../../widgets/m3_flexible_app_bar.dart';
import '../../widgets/m3_switch.dart';
import '../../theme/app_typography.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_list.dart';
import '../updater/update_section.dart';
import '../widget_mode/app_window.dart';

/// Настройки приложения: вид, устройства рядом и сведения о приложении.
///
/// Всё, что относится к лицевому счёту, живёт в профиле — там же, где
/// сам счёт.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final bool autostart = ref.watch(autostartProvider).value ?? false;
    final List<String> watches =
        ref.watch(connectedWatchesProvider).value ?? const <String>[];
    final double margin = AppSpacing.screenMargin(context);

    return Scaffold(
      appBar: M3SmallAppBar(
        title: 'Настройки',
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
                  // ─── Вид: всё, что меняет внешность приложения.
                  const SectionHeader('Вид'),
                  // Три взаимоисключающих варианта — connected button group,
                  // а не переключатель (switch → Guidelines → Usage).
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
                  const SizedBox(height: AppSpacing.space150),
                  SegmentedList(
                    children: [
                      // Строка списка с переключателем: нажатие по всей
                      // строке переключает (lists → selection modes).
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
                  // Значок меняется переключением activity-alias — это есть
                  // только в Android.
                  if (AppPlatform.isPhone) const _AppIconPicker(),

                  // ─── Устройства: это окно, компьютер и часы рядом.
                  if (AppPlatform.isDesktop || watches.isNotEmpty) ...[
                    const SectionHeader('Устройства'),
                    SegmentedList(
                      children: [
                        if (AppPlatform.isDesktop) ...[
                          M3ListItem(
                            leading: const Icon(Symbols.picture_in_picture),
                            headline: const Text('Компактное окно'),
                            supporting: const Text(
                              'Часы и ближайшая пара в углу экрана, поверх '
                              'других окон',
                            ),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () {
                              ref.read(widgetModeProvider.notifier).set(true);
                              Navigator.of(context).pop();
                            },
                          ),
                          M3ListItem(
                            leading: const Icon(Symbols.rocket_launch),
                            headline: const Text('Запускать вместе с Windows'),
                            supporting: const Text(
                              'При входе в систему приложение открывается '
                              'компактным окном',
                            ),
                            trailing: ExcludeSemantics(
                              child: M3Switch(
                                value: autostart,
                                onChanged: (value) => ref
                                    .read(autostartProvider.notifier)
                                    .set(value),
                              ),
                            ),
                            onTap: () => ref
                                .read(autostartProvider.notifier)
                                .set(!autostart),
                            semanticsLabel:
                                'Запускать вместе с Windows, '
                                '${autostart ? 'включено' : 'выключено'}',
                          ),
                        ],
                        // Часы показываются, только когда они рядом.
                        for (final String watch in watches)
                          M3ListItem(
                            leading: const Icon(Symbols.watch),
                            headline: Text(watch),
                            supporting: const Text(
                              'Расписание уходит на часы само, как только '
                              'обновится на телефоне',
                            ),
                          ),
                      ],
                    ),
                  ],

                  // ─── О приложении: версия, обновления и кто сделал.
                  const SectionHeader('О приложении'),
                  const UpdateSection(),
                  const SizedBox(height: AppSpacing.space300),
                  const _StudioSignature(),
                  const SizedBox(height: AppSpacing.space800),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор значка приложения: образцы с подписями, выбранный обведён.
///
/// Значок меняет система, поэтому в лаунчере он обновляется не мгновенно — об
/// этом говорит снекбар после выбора.
class _AppIconPicker extends ConsumerStatefulWidget {
  const _AppIconPicker();

  static const double size = 64;

  @override
  ConsumerState<_AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends ConsumerState<_AppIconPicker> {
  static const double size = _AppIconPicker.size;

  String? _message;

  Future<void> _select(AppIcon icon) async {
    final bool ok = await ref
        .read(appIconControllerProvider.notifier)
        .select(icon);
    if (!mounted) return;
    setState(
      () => _message = ok
          ? 'Значок сменится в лаунчере через пару секунд'
          : 'Не удалось сменить значок',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppIcon? selected = ref.watch(appIconControllerProvider).value;
    final ColorScheme colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Значок приложения',
            style: context.text.labelLarge!.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.space150),
          Wrap(
            spacing: AppSpacing.space100,
            runSpacing: AppSpacing.space150,
            children: [
              for (final AppIcon icon in AppIcon.values)
                Semantics(
                  selected: icon == selected,
                  button: true,
                  label: 'Значок «${icon.title}»',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _select(icon),
                    borderRadius: BorderRadius.circular(size),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space50),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: icon == selected
                                    ? colors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Image.asset(icon.asset, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space50),
                          SizedBox(
                            width: size + AppSpacing.space200,
                            child: Text(
                              icon.title,
                              textAlign: TextAlign.center,
                              style: context.text.labelSmall!.copyWith(
                                color: icon == selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space100),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: context.text.bodySmall!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
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

/// Подпись внизу настроек: нажатие открывает сайт студии.
class _StudioSignature extends StatelessWidget {
  const _StudioSignature();

  static final Uri _site = Uri.parse('https://z43-studios.vercel.app/');

  @override
  Widget build(BuildContext context) => Center(
    child: M3Button(
      onPressed: () => launchUrl(_site, mode: LaunchMode.externalApplication),
      color: M3ButtonColor.text,
      icon: const Icon(Symbols.favorite, fill: 1),
      child: const Text('Сделано в Z43 Studios'),
    ),
  );
}
