import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/boot/boot_screen.dart';
import 'features/home/home_shell.dart';
import 'state/settings_controller.dart';
import 'theme/app_color_schemes.dart';
import 'theme/app_motion.dart';
import 'theme/app_shapes.dart';
import 'theme/app_typography.dart';
import 'theme/status_colors.dart';

/// Загрузка настроек и моков. Показывается [BootScreen], пока не завершится.
final appBootProvider = FutureProvider<void>((ref) async {
  ref.watch(settingsControllerProvider);
  await Future<void>.delayed(const Duration(milliseconds: 1200));
});

class ScheduleApp extends ConsumerWidget {
  const ScheduleApp({super.key});

  static const Locale locale = Locale('ru', 'RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsControllerProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme scheme(Brightness brightness) => AppColorSchemes.resolve(
          palette: settings.palette,
          brightness: brightness,
          dynamicEnabled: settings.dynamicColor,
          deviceScheme: brightness == Brightness.light
              ? lightDynamic
              : darkDynamic,
        );

        return MaterialApp(
          title: 'Расписание',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: buildTheme(scheme(Brightness.light)),
          darkTheme: buildTheme(scheme(Brightness.dark)),
          locale: locale,
          supportedLocales: const [locale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _BootGate(),
        );
      },
    );
  }
}

class _BootGate extends ConsumerWidget {
  const _BootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool ready = ref.watch(appBootProvider).hasValue;

    // Переход с экрана загрузки — fade through.
    return AnimatedSwitcher(
      duration: AppMotion.slowEffects.duration,
      switchInCurve: AppMotion.slowEffects.curve,
      child: ready ? const HomeShell() : const BootScreen(),
    );
  }
}

/// Сборка темы из готовой [ColorScheme].
ThemeData buildTheme(ColorScheme scheme) {
  final bool isLight = scheme.brightness == Brightness.light;
  final TextTheme textTheme = AppTypography.textTheme(
    scheme.brightness,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [isLight ? StatusColors.light : StatusColors.dark],

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      indicatorShape: AppShapes.stadium,
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium!.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    searchBarTheme: SearchBarThemeData(
      constraints: const BoxConstraints(minHeight: 56),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      shape: const WidgetStatePropertyAll(AppShapes.stadium),
      textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      ),
    ),

    searchViewTheme: SearchViewThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      elevation: 0,
      headerHintStyle: textTheme.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      headerTextStyle: textTheme.bodyLarge,
    ),

    chipTheme: ChipThemeData(
      // Чипы по спеке: высота 32dp, радиус 8dp.
      shape: AppShapes.rounded(AppShapes.chip),
      labelStyle: textTheme.labelLarge,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: Colors.transparent,
      selectedColor: scheme.primaryContainer,
      showCheckmark: true,
      checkmarkColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: AppShapes.rounded(AppShapes.card),
      margin: EdgeInsets.zero,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: textTheme.titleMedium,
      shape: AppShapes.rounded(AppShapes.fab),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 56),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: AppShapes.bottomSheetShape,
      dragHandleColor: scheme.outlineVariant,
      showDragHandle: true,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        // Высота 40dp и радиус full — по спеке segmented buttons.
        minimumSize: const Size(0, 40),
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(textStyle: textTheme.titleMedium),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.titleMedium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: AppShapes.rounded(2),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 2),
    ),

    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      iconColor: scheme.onSurfaceVariant,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: AppShapes.rounded(AppShapes.extraSmall),
    ),
  );
}
