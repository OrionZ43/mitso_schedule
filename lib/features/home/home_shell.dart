import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_motion.dart';
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
/// https://m3.material.io/styles/motion/transitions/transition-patterns
///
/// Состояние вкладок сохраняется, как у [IndexedStack]: все страницы остаются
/// в дереве, меняются только прозрачность и масштаб.
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.defaultEffects.duration,
    value: 1,
  );

  late int _previousIndex = widget.index;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double t = _controller.value;
        return Stack(
          children: [
            for (int i = 0; i < widget.children.length; i++) _buildLayer(i, t),
          ],
        );
      },
    );
  }

  Widget _buildLayer(int i, double t) {
    final bool isCurrent = i == widget.index;
    final bool isOutgoing = i == _previousIndex && !isCurrent;
    if (!isCurrent && !isOutgoing) {
      return const SizedBox.shrink();
    }

    // Уходящая страница гаснет в первой трети, приходящая проявляется
    // в оставшихся двух третях — это и есть fade through.
    final double opacity = isCurrent
        ? Curves.easeIn.transform((t.clamp(0.35, 1.0) - 0.35) / 0.65)
        : 1 - Curves.easeOut.transform((t.clamp(0.0, 0.35)) / 0.35);

    final double scale = isCurrent ? 0.92 + 0.08 * opacity : 1.0;

    return IgnorePointer(
      ignoring: !isCurrent,
      child: ExcludeSemantics(
        excluding: !isCurrent,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: widget.children[i]),
        ),
      ),
    );
  }
}
