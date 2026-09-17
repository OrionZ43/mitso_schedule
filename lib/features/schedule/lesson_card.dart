import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/lesson.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/status_colors.dart';
import '../../widgets/m3_wavy_linear_progress.dart';
import 'lesson_timing.dart';

/// Карточка пары.
///
/// Одна карточка на время: если у подгрупп в это время разные преподаватели
/// и аудитории, они идут строками внутри карточки, а не отдельными парами.
///
/// Будущая — outlined card (`surface`, обводка `outlineVariant`) радиусом
/// 28dp; идущая — залитая `primary` радиусом 32dp с меткой «Сейчас идёт» и
/// волнистой шкалой прогресса; прошедшая — `surfaceContainerLow` без обводки.
/// Аудитория — крупный номер в форме «печенье» из библиотеки форм M3
/// Expressive, которая выходит из правого верхнего угла; у подгрупп — плашки
/// в их строках. Нажатие открывает подробности.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.slot,
    required this.status,
    required this.onTap,
  });

  final LessonSlot slot;
  final SlotStatus status;
  final VoidCallback onTap;

  /// Зазор между карточками пар.
  static const double gap = AppSpacing.space150;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final bool isNow =
        status.timing == SlotTiming.now && status.progress != null;
    final bool past = status.timing == SlotTiming.past;

    final Color container = isNow
        ? colors.primary
        : past
        ? colors.surfaceContainerLow
        : colors.surface;
    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: AppShapes.all(
        isNow ? AppShapes.cardEmphasized : AppShapes.card,
      ),
      // Outlined card: фон surface, обводка outlineVariant.
      side: !isNow && !past
          ? BorderSide(color: colors.outlineVariant)
          : BorderSide.none,
    );

    // Рябь нажатия перерисовывает слой Material на каждом кадре: карточка в
    // своём слое, чтобы не перерисовывать соседние, а текст — в своём, чтобы
    // не записывать его заново.
    return Semantics(
      container: true,
      label: isNow ? 'Текущая пара' : null,
      child: RepaintBoundary(
        child: Material(
          color: container,
          shape: shape,
          // Идущая пара приподнята над остальными, как в макете.
          elevation: isNow ? 3 : 0,
          shadowColor: colors.shadow,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          animationDuration: Duration.zero,
          child: InkWell(
            onTap: onTap,
            child: RepaintBoundary(
              child: _CardContent(
                slot: slot,
                isNow: isNow,
                past: past,
                progress: status.progress,
                startsInMinutes: status.startsIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.slot,
    required this.isNow,
    required this.past,
    required this.progress,
    required this.startsInMinutes,
  });

  final LessonSlot slot;
  final bool isNow;
  final bool past;
  final LessonProgress? progress;
  final int? startsInMinutes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color foreground = isNow ? colors.onPrimary : colors.onSurface;
    final Color secondary = isNow
        ? colors.onPrimary.withValues(alpha: 0.86)
        : colors.onSurfaceVariant;

    final Lesson single = slot.lessons.first;
    final String? title = slot.commonTitle;
    final bool oneRow = slot.lessons.length == 1;
    const List<FontFeature> tabular = [FontFeature.tabularFigures()];

    // Аудитория всей карточки — у одной строки; у подгрупп — в их строках.
    final String? room = oneRow ? single.room : null;
    final double padding = isNow ? 22 : 20;

    // Заголовок и название не заходят под форму с аудиторией; строки ниже
    // формы и шкала прогресса — во всю ширину.
    Widget besideShape(Widget child) => room == null
        ? child
        : Padding(
            padding: EdgeInsetsDirectional.only(
              end: _RoomShape.visibleSize - padding + AppSpacing.space100,
            ),
            child: child,
          );

    final Widget badges = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final Lesson lesson in slot.distinctTypes)
          LessonTypeBadge(
            type: lesson.type,
            label: lesson.typeLabel,
            onPrimarySurface: isNow,
          ),
        // Одна строка с номером — показана только своя подгруппа.
        if (oneRow && single.subgroup != null)
          _SubgroupBadge(number: single.subgroup!, onPrimarySurface: isNow),
      ],
    );

    final Widget content = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // minWidth, а не фиксированная ширина: при крупном шрифте
              // время не должно обрезаться.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.start,
                      style: context.text.titleMedium!.copyWith(
                        color: past ? colors.onSurfaceVariant : foreground,
                        fontFeatures: tabular,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space50),
                    Text(
                      slot.end,
                      style: context.text.bodySmall!.copyWith(
                        color: isNow
                            ? colors.onPrimary.withValues(alpha: 0.78)
                            : colors.onSurfaceVariant,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space200),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    besideShape(badges),
                    if (title != null) ...[
                      const SizedBox(height: 9),
                      besideShape(
                        Text(
                          title,
                          style: context.text.titleMedium!.emphasized.copyWith(
                            height: 1.5,
                            color: past ? colors.onSurfaceVariant : foreground,
                          ),
                        ),
                      ),
                    ],
                    if (oneRow) ...[
                      if (single.teacher != null) ...[
                        const SizedBox(height: 10),
                        _MetaRow(
                          icon: Symbols.person,
                          text: single.teacher!,
                          color: secondary,
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: AppSpacing.space150),
                      _SubgroupRows(
                        slot: slot,
                        isNow: isNow,
                        past: past,
                        showTitles: title == null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isNow) ...[
            const SizedBox(height: 18),
            _NowSection(progress: progress!),
          ] else if (startsInMinutes != null) ...[
            const SizedBox(height: 14),
            _StartsIn(minutes: startsInMinutes!),
          ],
        ],
      ),
    );

    if (room == null) return content;

    // Форма под содержимым, обрезана скруглением карточки.
    return Stack(
      children: [
        PositionedDirectional(
          top: -_RoomShape.overflow,
          end: -_RoomShape.overflow,
          child: _RoomShape(
            room: room,
            colors: _AccentColors.of(colors, isNow: isNow, past: past),
          ),
        ),
        content,
      ],
    );
  }
}

/// Цвета выделения аудитории на карточке каждого состояния.
@immutable
class _AccentColors {
  const _AccentColors({required this.container, required this.content});

  final Color container;
  final Color content;

  factory _AccentColors.of(
    ColorScheme colors, {
    required bool isNow,
    required bool past,
  }) {
    if (isNow) {
      return _AccentColors(
        container: colors.onPrimary.withValues(alpha: 0.2),
        content: colors.onPrimary,
      );
    }
    if (past) {
      return _AccentColors(
        container: colors.surfaceContainerHighest,
        content: colors.onSurfaceVariant,
      );
    }
    return _AccentColors(
      container: colors.secondaryContainer,
      content: colors.onSecondaryContainer,
    );
  }
}

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Подпись аудитории для TalkBack.
String _roomSemantics(String room) =>
    RegExp(r'^\d').hasMatch(room) ? 'аудитория $room' : room;

/// Аудитория подгруппы — тональная плашка в конце строки.
class _RoomPill extends StatelessWidget {
  const _RoomPill({required this.room, required this.colors});

  final String room;
  final _AccentColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _roomSemantics(room),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
        decoration: ShapeDecoration(
          color: colors.container,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.door_front, size: 16, color: colors.content),
            const SizedBox(width: AppSpacing.space50),
            Flexible(
              child: Text(
                room,
                style: context.text.labelLarge!.copyWith(
                  color: colors.content,
                  fontFeatures: _tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Номер аудитории в expressive-форме из правого верхнего угла.
class _RoomShape extends StatelessWidget {
  const _RoomShape({required this.room, required this.colors});

  final String room;
  final _AccentColors colors;

  /// Сторона формы.
  static const double size = 148;

  /// Насколько форма выходит за край карточки.
  static const double overflow = 28;

  /// Видимая часть формы.
  static const double visibleSize = size - overflow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _roomSemantics(room),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ShapePainter(
                  MaterialShapes.cookie9Sided,
                  colors.container,
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: visibleSize,
              height: visibleSize,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space150),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.door_front,
                          size: 20,
                          color: colors.content,
                        ),
                        // Номер — главное в форме: крупный и жирный; длинные
                        // названия («409 чжф») FittedBox уменьшает.
                        Text(
                          room,
                          style: context.text.displaySmall!.copyWith(
                            color: colors.content,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.polygon, this.color);

  final RoundedPolygon polygon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path unit = polygon.normalized().toPath();
    final Matrix4 scale = Matrix4.diagonal3Values(size.width, size.height, 1);
    canvas.drawPath(unit.transform(scale.storage), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.polygon != polygon || oldDelegate.color != color;
}

/// Строки подгрупп внутри карточки — segmented-список в миниатюре:
/// крайние углы 16dp, стыки 4dp, зазор 2dp.
class _SubgroupRows extends StatelessWidget {
  const _SubgroupRows({
    required this.slot,
    required this.isNow,
    required this.past,
    required this.showTitles,
  });

  final LessonSlot slot;
  final bool isNow;
  final bool past;

  /// У подгрупп разные предметы — название в каждой строке.
  final bool showTitles;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color rowColor = isNow
        ? colors.onPrimary.withValues(alpha: 0.14)
        : past
        ? colors.surfaceContainerHigh
        : colors.surfaceContainer;
    final Color foreground = isNow ? colors.onPrimary : colors.onSurface;
    final int count = slot.lessons.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          Semantics(
            container: true,
            label: lessonDetailsLine(slot.lessons[i], withTitle: showTitles),
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    i == 0 ? AppShapes.large : AppShapes.extraSmall,
                  ),
                  bottom: Radius.circular(
                    i == count - 1 ? AppShapes.large : AppShapes.extraSmall,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SubgroupNumber(
                    number: slot.lessons[i].subgroup,
                    onPrimarySurface: isNow,
                  ),
                  const SizedBox(width: 10),
                  // Wrap: плашка аудитории прижата вправо, а при крупном
                  // шрифте переносится под преподавателя.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.space100,
                      runSpacing: AppSpacing.space50,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTitles)
                              Text(
                                slot.lessons[i].title,
                                style: context.text.titleSmall!.emphasized
                                    .copyWith(color: foreground),
                              ),
                            Text(
                              slot.lessons[i].teacher ??
                                  'Преподаватель не указан',
                              style: context.text.bodyMedium!.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (slot.lessons[i].room != null)
                          _RoomPill(
                            room: slot.lessons[i].room!,
                            colors: _AccentColors.of(
                              colors,
                              isNow: isNow,
                              past: past,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Номер подгруппы в круге; без номера — значок человека.
class _SubgroupNumber extends StatelessWidget {
  const _SubgroupNumber({required this.number, required this.onPrimarySurface});

  final int? number;
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final Color foreground = onPrimarySurface
        ? colors.onPrimary
        : colors.onSecondaryContainer;
    final double size = MediaQuery.textScalerOf(context).scale(28);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onPrimarySurface
            ? colors.onPrimary.withValues(alpha: 0.22)
            : colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: number == null
          ? Icon(Symbols.person, size: 18, color: foreground)
          : Text(
              '$number',
              style: context.text.labelLarge!.emphasized.copyWith(
                color: foreground,
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.space100),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// «Начнётся через 25 мин» у ближайшей сегодняшней пары.
class _StartsIn extends StatelessWidget {
  const _StartsIn({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final Color color = context.colors.primary;
    return Row(
      children: [
        Icon(Symbols.schedule, size: 18, color: color),
        const SizedBox(width: AppSpacing.space100),
        Expanded(
          child: Text(
            'Начнётся ${startsInLabel(minutes)}',
            style: context.text.labelLarge!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Блок текущей пары: метка с пульсирующей точкой, остаток и шкала прогресса.
class _NowSection extends StatelessWidget {
  const _NowSection({required this.progress});

  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, а не Row: при крупном системном шрифте метка и остаток
        // переносятся на вторую строку вместо переполнения.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(),
                const SizedBox(width: 7),
                Text(
                  'СЕЙЧАС ИДЁТ',
                  style: context.text.labelMedium!.emphasized.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'осталось ${progress.minutesLeft} мин',
              style: context.text.labelMedium!.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.85),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space100),
        // Карточка залита primary, поэтому токенные цвета шкалы (primary на
        // secondaryContainer) здесь не читаются — onPrimary, как в макете.
        M3WavyLinearProgress(
          value: progress.fraction,
          color: colors.onPrimary,
          trackColor: colors.onPrimary.withValues(alpha: 0.32),
          semanticsLabel: 'Прогресс пары',
        ),
      ],
    );
  }
}

/// Пульсирующая точка у метки «Сейчас идёт» — элемент макета.
///
/// Пульсация — прозрачность, поэтому анимация относится к effects и идёт
/// без перелёта. `FadeTransition` меняет только прозрачность слоя: карточка
/// при этом не перерисовывается.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: 1.0,
    end: 0.3,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // При уменьшении движения точка не пульсирует.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: context.colors.onPrimary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Бейдж типа занятия на карточке пары.
class LessonTypeBadge extends StatelessWidget {
  const LessonTypeBadge({
    super.key,
    required this.type,
    required this.label,
    this.onPrimarySurface = false,
  });

  final LessonType type;

  /// Подпись: «Лекция», «Лаб» или сокращение с сайта для прочих типов.
  final String label;

  /// Карточка текущей пары залита `primary` — бейдж становится полупрозрачным.
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    final StatusColors status = StatusColors.of(context);

    final (Color background, Color foreground) = onPrimarySurface
        ? (colors.onPrimary.withValues(alpha: 0.22), colors.onPrimary)
        : switch (type) {
            LessonType.lecture => (
              colors.primaryContainer,
              colors.onPrimaryContainer,
            ),
            LessonType.practice => (status.approved, status.onApproved),
            LessonType.lab => (
              colors.tertiaryContainer,
              colors.onTertiaryContainer,
            ),
            LessonType.other => (
              colors.secondaryContainer,
              colors.onSecondaryContainer,
            ),
          };

    return _Badge(background: background, foreground: foreground, label: label);
  }
}

/// «1 подгруппа» — когда показана только своя подгруппа.
class _SubgroupBadge extends StatelessWidget {
  const _SubgroupBadge({required this.number, required this.onPrimarySurface});

  final int number;
  final bool onPrimarySurface;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;
    return _Badge(
      background: onPrimarySurface
          ? colors.onPrimary.withValues(alpha: 0.22)
          : colors.surfaceContainerHigh,
      foreground: onPrimarySurface ? colors.onPrimary : colors.onSurfaceVariant,
      label: '$number подгруппа',
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Высота не фиксируется: при масштабе шрифта до 200% бейдж растёт вместе
    // с текстом.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppShapes.all(AppShapes.chip),
      ),
      child: Text(
        label,
        style: context.text.labelSmall!.copyWith(color: foreground),
      ),
    );
  }
}
