import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitso_schedule/theme/status_colors.dart';

/// Относительная яркость по WCAG 2.1.
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrastRatio(Color foreground, Color background) {
  final double a = _luminance(foreground);
  final double b = _luminance(background);
  final double lighter = math.max(a, b);
  final double darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  /// https://m3.material.io/foundations/accessible-design/patterns
  const double minimumBodyContrast = 4.5;

  void check(String name, StatusColors colors) {
    test('контраст статусов >= 4.5:1 — $name', () {
      final pairs = <String, (Color, Color)>{
        'В обработке': (colors.onPending, colors.pending),
        'Одобрено': (colors.onApproved, colors.approved),
        'Отклонено': (colors.onRejected, colors.rejected),
      };

      pairs.forEach((label, pair) {
        final double ratio = contrastRatio(pair.$1, pair.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(minimumBodyContrast),
          reason: '$label: ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });
  }

  check('светлая тема', StatusColors.light);
  check('тёмная тема', StatusColors.dark);
}
