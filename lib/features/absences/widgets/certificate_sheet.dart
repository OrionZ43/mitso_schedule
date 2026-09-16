import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../state/absences_controller.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/m3_loading_indicator.dart';

/// Боттом-шит отправки справки.
///
/// https://m3.material.io/components/bottom-sheets/specs
Future<void> showCertificateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CertificateSheet(),
  );
}

class _CertificateSheet extends ConsumerStatefulWidget {
  const _CertificateSheet();

  @override
  ConsumerState<_CertificateSheet> createState() => _CertificateSheetState();
}

class _CertificateSheetState extends ConsumerState<_CertificateSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await ref.read(absencesControllerProvider.notifier).submit();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Справка отправлена куратору')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Оправдать пропуск',
            style: context.text.headlineSmall!.emphasized,
          ),
          const SizedBox(height: 8),
          Text(
            'Прикрепи фото справки — бот отправит её куратору и обновит статистику.',
            style: context.text.bodyMedium!.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          const _PhotoDropZone(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 14,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? M3LoadingIndicator(
                            contained: false,
                            size: 24,
                            color: colors.onPrimary,
                            semanticsLabel: 'Отправка справки',
                          )
                        : const Text('Отправить'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Зона загрузки фото: пунктирная рамка поверх диагональной штриховки.
class _PhotoDropZone extends StatelessWidget {
  const _PhotoDropZone();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colors;

    return Semantics(
      button: true,
      label: 'Прикрепить фото справки',
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colors.outlineVariant,
          radius: AppShapes.large + 8,
        ),
        child: Container(
          height: 148,
          decoration: BoxDecoration(
            borderRadius: AppShapes.all(AppShapes.large + 8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              tileMode: TileMode.repeated,
              colors: [
                colors.surfaceContainerHigh,
                colors.surfaceContainerHigh,
                colors.surfaceContainerLow,
                colors.surfaceContainerLow,
              ],
              stops: const [0.0, 0.5, 0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Symbols.add_a_photo,
                size: 28,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                'фото справки',
                style: context.text.labelMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 7;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final Path source = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
