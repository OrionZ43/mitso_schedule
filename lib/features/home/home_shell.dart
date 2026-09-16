import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_transitions.dart';
import '../absences/absences_screen.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

/// Каркас приложения: четыре вкладки и navigation bar.
///
/// https://m3.material.io/components/navigation-bar/specs
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<({IconData icon, String label})> _destinations = [
    (icon: Symbols.calendar_month, label: 'Расписание'),
    (icon: Symbols.event_busy, label: 'Пропуски'),
    (icon: Symbols.checklist, label: 'Заметки'),
    (icon: Symbols.person, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeThroughStack(
          index: _index,
          children: const [
            ScheduleScreen(),
            AbsencesScreen(),
            NotesScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.icon, fill: 1),
              label: destination.label,
            ),
        ],
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
  });

  final int index;
  final List<Widget> children;

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
        if (status == AnimationStatus.completed) setState(() {});
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
