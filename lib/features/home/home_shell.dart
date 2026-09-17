import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../state/tasks_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_transitions.dart';
import '../../widgets/m3_fab.dart';
import '../../widgets/m3_navigation_bar.dart';
import '../../widgets/m3_snackbar.dart';
import '../absences/absences_screen.dart';
import '../absences/widgets/certificate_sheet.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

/// Хост снекбаров над navigation bar. Глобальный, потому что сообщения
/// приходят и из шитов, которые живут в отдельных маршрутах.
final GlobalKey<M3SnackbarHostState> appSnackbarHost = GlobalKey();

/// Каркас приложения: четыре раздела, navigation bar и FAB раздела.
///
/// FAB живёт здесь, а не внутри раздела: гайдлайн FAB «Moving across tabs» —
/// FAB не анимируется вместе с содержимым, а коротко исчезает и появляется,
/// когда новый раздел встал на место (`Modifier.animateFloatingActionButton`).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  /// Раздел, чей FAB показан. Меняется после перехода между разделами.
  int _fabIndex = 0;

  final List<ScrollController> _scrollControllers = [
    for (int i = 0; i < 4; i++) ScrollController(),
  ];

  static const List<M3NavigationDestination> _destinations = [
    M3NavigationDestination(icon: Symbols.calendar_month, label: 'Расписание'),
    M3NavigationDestination(icon: Symbols.event_busy, label: 'Пропуски'),
    M3NavigationDestination(icon: Symbols.checklist, label: 'Заметки'),
    M3NavigationDestination(icon: Symbols.person, label: 'Профиль'),
  ];

  /// Отступ FAB от краёв окна.
  static const double fabMargin = AppSpacing.space200;

  @override
  void dispose() {
    for (final ScrollController c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// Повторный выбор раздела возвращает его к началу (navigation bar →
  /// Guidelines → Behavior). Прокрутка — `spring()` Compose по умолчанию.
  void _reselect(int index) {
    final ScrollController controller = _scrollControllers[index];
    if (!controller.hasClients || controller.offset == 0) return;
    if (reduceMotionOf(context)) {
      controller.jumpTo(0);
      return;
    }
    controller.animateTo(
      0,
      duration: AppMotion.composeDefault.duration,
      curve: AppMotion.composeDefault.curve,
    );
  }

  /// FAB раздела; `null` — у раздела его нет.
  ({Widget fab, double height})? _fabFor(int index) => switch (index) {
    // Главное действие длинного списка справок с подписью — extended FAB
    // (стиль primary, как в макете; разрешён спекой).
    1 => (
      fab: M3ExtendedFab(
        onPressed: () => showCertificateSheet(context),
        icon: const Icon(Symbols.document_scanner, fill: 1),
        label: 'Зарегистрировать пропуск',
        color: M3FabColor.primary,
      ),
      height: 56,
    ),
    // «Use a medium FAB for mobile layouts» — FAB guidelines.
    2 => (
      fab: M3Fab(
        onPressed: ref.read(tasksControllerProvider.notifier).add,
        icon: const Icon(Symbols.add, fill: 1),
        size: M3FabSize.medium,
        tooltip: 'Добавить задачу',
      ),
      height: M3FabSize.medium.containerSize,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final fab = _fabFor(_fabIndex);
    final bool fabVisible = _fabIndex == _index && fab != null;

    return Scaffold(
      body: M3SnackbarHost(
        key: appSnackbarHost,
        bottomPadding: fabVisible ? fab.height + fabMargin : 0,
        child: Stack(
          children: [
            FadeThroughStack(
              index: _index,
              onSettled: (index) => setState(() => _fabIndex = index),
              children: [
                ScheduleScreen(scrollController: _scrollControllers[0]),
                AbsencesScreen(scrollController: _scrollControllers[1]),
                NotesScreen(scrollController: _scrollControllers[2]),
                ProfileScreen(scrollController: _scrollControllers[3]),
              ],
            ),
            if (fab != null)
              PositionedDirectional(
                end: fabMargin,
                bottom: fabMargin,
                child: M3AnimatedFabVisibility(
                  visible: fabVisible,
                  alignment: AlignmentDirectional.bottomEnd,
                  child: KeyedSubtree(key: ValueKey(_fabIndex), child: fab.fab),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: M3NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onSelected: _select,
        onReselected: _reselect,
      ),
    );
  }
}

/// Переключение вкладок паттерном fade through.
///
/// MDC Motion.md, «Fade through»: пример применения — «Tapping destinations
/// in a bottom navigation bar». Параметры — [M3FadeThroughEnter] /
/// [M3FadeThroughExit] (порт `MaterialFadeThrough`).
///
/// Состояние вкладок сохраняется, как у [IndexedStack]: все страницы остаются
/// в дереве с одинаковой обёрткой, скрытые — за [Offstage] с выключенными
/// тикерами.
class FadeThroughStack extends StatefulWidget {
  const FadeThroughStack({
    super.key,
    required this.index,
    required this.children,
    this.onSettled,
  });

  final int index;
  final List<Widget> children;

  /// Переход завершён, раздел [index] на месте.
  final ValueChanged<int>? onSettled;

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: AppTransitions.fadeThroughDuration,
        value: 1,
      )..addStatusListener((status) {
        // Уходящая вкладка прячется, когда переход закончен.
        if (status == AnimationStatus.completed) {
          setState(() {});
          widget.onSettled?.call(widget.index);
        }
      });

  int? _previousIndex;

  @override
  void didUpdateWidget(FadeThroughStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previousIndex = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animating = _controller.isAnimating;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _layer(
            i,
            isCurrent: i == widget.index,
            isOutgoing: animating && i == _previousIndex && i != widget.index,
          ),
      ],
    );
  }

  Widget _layer(int i, {required bool isCurrent, required bool isOutgoing}) {
    final bool visible = isCurrent || isOutgoing;
    // Обёртка у всех слоёв одинаковая, меняются только аргументы: иначе
    // Flutter пересоздал бы поддерево и вкладка потеряла бы состояние.
    return M3FadeThroughEnter(
      progress: isCurrent ? _controller : kAlwaysCompleteAnimation,
      child: M3FadeThroughExit(
        progress: isOutgoing ? _controller : kAlwaysDismissedAnimation,
        child: Offstage(
          offstage: !visible,
          child: TickerMode(
            enabled: visible,
            child: ExcludeSemantics(
              excluding: !isCurrent,
              child: widget.children[i],
            ),
          ),
        ),
      ),
    );
  }
}
