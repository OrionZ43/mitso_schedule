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
import 'theme/app_state_layer.dart';
import 'theme/app_transitions.dart';
import 'theme/app_typography.dart';
import 'theme/status_colors.dart';
import 'theme/system_color_roles.dart';

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

/// Цвета обоев с устройства.
///
/// Android 14+ — готовые системные роли ([SystemColorRoles]); Android 12–13 —
/// только палитры обоев из `dynamic_color`, из них берётся акцент.
final dynamicColorsProvider =
    FutureProvider<({ColorScheme? light, ColorScheme? dark, Color? seed})>((
      ref,
    ) async {
      final system = await SystemColorRoles.load();
      if (system != null) {
        return (light: system.light, dark: system.dark, seed: null);
      }
      try {
        final palette = await DynamicColorPlugin.getCorePalette();
        final Color? seed = palette == null
            ? null
            : Color(palette.primary.get(40));
        return (light: null, dark: null, seed: seed);
      } catch (_) {
        return (light: null, dark: null, seed: null);
      }
    }, retry: noRetry);

class ScheduleApp extends ConsumerStatefulWidget {
  const ScheduleApp({super.key});

  static const Locale locale = Locale('ru', 'RU');

  @override
  ConsumerState<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends ConsumerState<ScheduleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Обои или контраст могли смениться, пока приложение было в фоне.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dynamicColorsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Settings settings = ref.watch(settingsControllerProvider);
    final dynamicColors = ref.watch(dynamicColorsProvider).value;

    ColorScheme scheme(Brightness brightness) => AppColorSchemes.resolve(
      palette: settings.palette,
      brightness: brightness,
      dynamicEnabled: settings.dynamicColor,
      systemScheme: brightness == Brightness.light
          ? dynamicColors?.light
          : dynamicColors?.dark,
      wallpaperSeed: dynamicColors?.seed,
    );

    return MaterialApp(
      title: 'Расписание',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(scheme(Brightness.light)),
      darkTheme: buildTheme(scheme(Brightness.dark)),
      locale: ScheduleApp.locale,
      supportedLocales: const [ScheduleApp.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _BootGate(),
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
  final TextTheme textTheme = AppTypography.textTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [isLight ? StatusColors.light : StatusColors.dark],

    // Material Symbols: https://m3.material.io/styles/icons — вес 400,
    // оптический размер по размеру иконки (24dp), grade 0 для тёмных иконок
    // на светлом фоне и −25 для светлых на тёмном.
    iconTheme: IconThemeData(
      size: 24,
      opticalSize: 24,
      weight: 400,
      grade: isLight ? 0 : -25,
      fill: 0,
      color: scheme.onSurface,
    ),

    // State layer цветом содержимого: https://m3.material.io/foundations/interaction/states,
    // `StateTokens.kt` — pressed/focus 10%, hover 8%. Базовые значения для
    // виджетов без своего overlayColor; содержимое на surface-ролях — onSurface.
    // Ripple — как `ripple()` в Compose, без эффекта InkSparkle.
    splashFactory: InkRipple.splashFactory,
    splashColor: scheme.onSurface.withValues(
      alpha: AppStateLayer.pressedOpacity,
    ),
    highlightColor: scheme.onSurface.withValues(
      alpha: AppStateLayer.pressedOpacity,
    ),
    hoverColor: scheme.onSurface.withValues(alpha: AppStateLayer.hoverOpacity),
    focusColor: scheme.onSurface.withValues(alpha: AppStateLayer.focusOpacity),

    // App bar: `AppBarTokens` — контейнер surface, при прокрутке под ним —
    // surfaceContainer, без тени; заголовок titleLarge, отступ действий 4dp.
    appBarTheme: AppBarTheme(
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? scheme.surfaceContainer
            : scheme.surface,
      ),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
      actionsPadding: const EdgeInsetsDirectional.only(end: 4),
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

    // Чипы и карточки: умолчания Flutter M3 совпадают с токенами
    // (`FilterChipTokens`: обводка outlineVariant; карточки 12dp, filled
    // surfaceContainerHighest, outlined surface + outlineVariant).
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),

    // Small extended FAB (`ExtendedFabSmallTokens`): titleMedium, 56dp,
    // отступы 16 / 8 / 16dp. Цвета и тень FAB — умолчания M3.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
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
      // Scrim: роль scrim с непрозрачностью 32% (`ScrimTokens`).
      modalBarrierColor: scheme.scrim.withValues(alpha: 0.32),
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

    // Plain tooltip: `PlainTooltipTokens` — inverseSurface / inverseOnSurface,
    // bodySmall, углы 4dp; Compose `Tooltip.kt` — поля 8×4, минимум 40×24,
    // ширина до 200dp.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: AppShapes.all(AppShapes.extraSmall),
      ),
      textStyle: textTheme.bodySmall!.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 24,
        maxWidth: 200,
      ),
    ),

    // Пункт списка: `ListTokens` — поля 16 / 16, сверху и снизу 10, между
    // слотами 12.
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      minVerticalPadding: 10,
      horizontalTitleGap: 12,
      minLeadingWidth: 24,
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
      // Compose `SnackbarHost`: поле 12dp вокруг снекбара.
      insetPadding: const EdgeInsets.all(12),
    ),
  );
}
