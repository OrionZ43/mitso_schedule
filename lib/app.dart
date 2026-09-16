import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/boot/boot_screen.dart';
import 'features/home/home_shell.dart';
import 'state/mitso_providers.dart';
import 'state/settings_controller.dart';
import 'theme/app_button_styles.dart';
import 'theme/app_color_schemes.dart';
import 'theme/app_shapes.dart';
import 'theme/app_transitions.dart';
import 'theme/app_typography.dart';
import 'theme/status_colors.dart';

/// Подготовка при старте: клиент сайта и его сертификаты. Пока не
/// завершится, показывается [BootScreen]. Искусственной задержки нет — по
/// гайдлайну индикатор загрузки только для настоящего ожидания.
final appBootProvider = FutureProvider<void>((ref) async {
  ref.watch(settingsControllerProvider);
  try {
    await ref.read(mitsoApiProvider.future);
  } catch (_) {
    // Ошибку клиента покажет экран расписания; запуск она не блокирует.
  }
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

    // Экран загрузки и главный не связаны пространственно — fade through.
    return PageTransitionSwitcher(
      duration: AppTransitions.fadeThroughDuration,
      transitionBuilder: (child, animation, secondaryAnimation) =>
          M3FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
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

    // Navigation bar по токенам MDC Expressive (bottomnavigation/tokens.xml):
    // высота 64dp, индикатор 56×32 secondaryContainer, подпись активного
    // пункта — secondary.
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: scheme.surfaceContainer,
      indicatorShape: const NavigationIndicatorBorder(),
      indicatorColor: scheme.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium!.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.secondary
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

    // Filter chip по chip/res из MDC: 32dp, углы 8dp, labelLarge. Выбранный —
    // secondaryContainer без обводки, невыбранный — прозрачный с обводкой outline.
    chipTheme: ChipThemeData(
      shape: AppShapes.rounded(AppShapes.chip),
      labelStyle: textTheme.labelLarge!.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.secondaryContainer
            : Colors.transparent,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide.none
            : BorderSide(color: scheme.outline),
      ),
      showCheckmark: true,
      checkmarkColor: scheme.onSecondaryContainer,
    ),

    // Outlined card по card/tokens.xml: фон surface, обводка outlineVariant 1dp.
    // Радиус 28dp вместо medium — согласованное отступление.
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.all(AppShapes.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),

    // FAB и small extended FAB по fab_tokens.xml / efab_tokens.xml:
    // по умолчанию primaryContainer, тень level3 (6dp), углы 16dp, у extended —
    // titleMedium и отступы 16 / 8 / 16dp.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 6,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: AppShapes.rounded(AppShapes.fab),
      extendedTextStyle: textTheme.titleMedium,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 56),
      extendedPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      extendedIconLabelSpacing: 8,
    ),

    // Bottom sheet по bottomsheet/tokens.xml: фон surfaceContainerLow, верхние
    // углы extraLarge (28dp), ручка 32×4 onSurfaceVariant.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: AppShapes.bottomSheetShape,
      dragHandleColor: scheme.onSurfaceVariant,
      dragHandleSize: const Size(32, 4),
      showDragHandle: true,
    ),

    // Кнопки размера Small по button/tokens.xml; обводка outlined —
    // outlineVariant. Medium задаётся там, где нужна (шит справки).
    filledButtonTheme: FilledButtonThemeData(
      style: AppButtonStyles.small(textTheme),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: AppButtonStyles.small(textTheme).copyWith(
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: AppButtonStyles.small(textTheme),
    ),
    iconButtonTheme: IconButtonThemeData(style: AppButtonStyles.iconSmall()),

    // Plain tooltip по стилю Widget.Material3.Tooltip: primary / onPrimary,
    // bodySmall, отступ 4dp, минимум 28dp, углы extraSmall.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppShapes.all(AppShapes.extraSmall),
      ),
      textStyle: textTheme.bodySmall!.copyWith(color: scheme.onPrimary),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
