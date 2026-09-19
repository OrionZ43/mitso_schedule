import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/wear_sync.dart';
import 'features/boot/boot_screen.dart';
import 'features/home/home_shell.dart';
import 'features/widget_mode/app_window.dart';
import 'features/widget_mode/compact_screen.dart';
import 'state/mitso_providers.dart';
import 'state/reminders_controller.dart';
import 'state/schedule_controller.dart';
import 'state/settings_controller.dart';
import 'state/student_controller.dart';
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
    // Напоминания о парах перепланируются сами, когда меняется расписание
    // или настройки.
    ref.listenManual<AsyncValue<int>>(
      reminderSchedulerProvider,
      (AsyncValue<int>? previous, AsyncValue<int> next) {},
      fireImmediately: true,
    );
    // Часы получают расписание при каждом его изменении — и сразу то, что
    // уже загружено.
    ref.listenManual<AsyncValue<ScheduleState?>>(
      scheduleControllerProvider,
      (AsyncValue<ScheduleState?>? previous, AsyncValue<ScheduleState?> next) =>
          _syncWatch(next.value),
      fireImmediately: true,
    );
  }

  void _syncWatch(ScheduleState? schedule) {
    final ScheduleTarget? target = ref.read(scheduleTargetProvider);
    if (schedule == null || target == null) return;
    ref.read(wearSyncProvider).push(target.title, schedule.weeks);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Обои или контраст могли смениться, пока приложение было в фоне; счёт на
  // сайте мог обновиться.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dynamicColorsProvider);
      ref.read(studentControllerProvider.notifier).refreshIfStale();
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
      // Compose `MaterialTheme` меняет схему сразу, без анимации. Твин темы
      // Flutter перестраивал бы на каждом кадре всё приложение.
      themeAnimationDuration: Duration.zero,
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
    // Компактное окно на рабочем столе — то же приложение, только целиком в
    // одном экране (features/widget_mode).
    final bool compact = ref.watch(widgetModeProvider);

    // Экран загрузки и главный не связаны пространственно — fade through.
    return PageTransitionSwitcher(
      duration: AppTransitions.fadeThroughDuration,
      transitionBuilder: (child, animation, secondaryAnimation) =>
          M3FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
      child: !ready
          ? const BootScreen()
          : compact
          ? const CompactScreen()
          : const HomeShell(),
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
    extensions: [StatusColors.fromScheme(scheme)],

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

    // Чипы и карточки: умолчания Flutter M3 совпадают с токенами
    // (`FilterChipTokens`: обводка outlineVariant; карточки 12dp, filled
    // surfaceContainerHighest, outlined surface + outlineVariant).
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),

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
