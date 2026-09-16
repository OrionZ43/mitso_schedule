import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_data.dart';
import '../../data/models/student_profile.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_color_schemes.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final StudentProfile profile = MockData.profile;

    return ListView(
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
        _ProfileHeader(profile: profile),
        _SectionTitle('LMS Moodle'),
        _Section(
          children: [
            _CredentialRow(
              icon: Symbols.badge,
              label: 'Логин',
              value: profile.moodleLogin,
              secret: false,
            ),
            const Divider(height: 1),
            _CredentialRow(
              icon: Symbols.key,
              label: 'Пароль',
              value: profile.moodlePassword,
              secret: true,
            ),
          ],
        ),
        _SectionTitle('Настройки'),
        _Section(
          children: [
            SwitchListTile(
              secondary: const Icon(Symbols.dark_mode),
              title: const Text('Тёмная тема'),
              subtitle: Text(settings.themeSubtitle),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: controller.setDark,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Symbols.palette),
              title: const Text('Динамические цвета'),
              subtitle: const Text('Material You · из обоев'),
              value: settings.dynamicColor,
              onChanged: controller.setDynamicColor,
            ),
            const Divider(height: 1),
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
          enabled: settings.dynamicColor,
          onSelected: controller.setPalette,
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final StudentProfile profile;

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
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Text(
                profile.initials,
                style: context.text.headlineSmall!.emphasized.copyWith(
                  fontSize: 26,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: context.text.titleLarge!.emphasized.copyWith(
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      label: profile.group,
                      background: colors.primaryContainer,
                      foreground: colors.onPrimaryContainer,
                    ),
                    _InfoChip(
                      label: profile.course,
                      background: colors.surface,
                      foreground: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
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

/// Строка с логином или паролем: значение, глаз и кнопка копирования.
class _CredentialRow extends StatefulWidget {
  const _CredentialRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.secret,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool secret;

  /// Сколько держится состояние «Скопировано».
  static const Duration copiedFeedback = Duration(milliseconds: 1600);

  @override
  State<_CredentialRow> createState() => _CredentialRowState();
}

class _CredentialRowState extends State<_CredentialRow> {
  bool _revealed = false;
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(_CredentialRow.copiedFeedback, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool hidden = widget.secret && !_revealed;
    final String display = hidden ? '••••••••••' : widget.value;

    // Wrap, а не Row: при системном шрифте 200% «глаз» и «Копировать»
    // переезжают на вторую строку вместо горизонтального переполнения.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: colors.onSurfaceVariant),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: context.text.bodySmall!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      display,
                      style: context.text.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: hidden ? 0.8 : 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.secret)
                IconButton(
                  onPressed: () => setState(() => _revealed = !_revealed),
                  icon: Icon(
                    _revealed ? Symbols.visibility_off : Symbols.visibility,
                  ),
                  tooltip: _revealed ? 'Скрыть пароль' : 'Показать пароль',
                ),
              TextButton(
                onPressed: _copy,
                style: _copied
                    ? TextButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      )
                    : null,
                child: Text(_copied ? 'Скопировано' : 'Копировать'),
              ),
            ],
          ),
        ],
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

  /// При выключенных динамических цветах приложение использует baseline-схему,
  /// поэтому выбор палитры ни на что не влияет.
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

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    // Именно Material, а не Container: ListTile рисует фон и ripple на
    // ближайшем Material-предке, и непрозрачный контейнер их бы перекрыл.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppShapes.all(AppShapes.card),
          side: BorderSide(color: colors.outlineVariant),
        ),
        // stretch, иначе строки с Wrap сжимаются по контенту и уезжают
        // в центр вместо того, чтобы занять всю ширину секции.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
