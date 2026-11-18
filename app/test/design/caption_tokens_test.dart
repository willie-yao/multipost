import 'dart:math' as math;

import 'package:cross_posting_app/design/caption_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, t) in [
    ('light', CaptionTokens.light),
    ('dark', CaptionTokens.dark),
  ]) {
    test('$name scheme text and state colours meet WCAG AA', () {
      final textPairs = {
        'text/ground': (t.text, t.ground),
        'text/sheet': (t.text, t.sheet),
        'text/raised': (t.text, t.raised),
        'secondary/ground': (t.secondary, t.ground),
        'secondary/sheet': (t.secondary, t.sheet),
        'secondary/raised': (t.secondary, t.raised),
        'own/ground': (t.own, t.ground),
        'own/sheet': (t.own, t.sheet),
        'error/ground': (t.error, t.ground),
        'error/sheet': (t.error, t.sheet),
        'warning/ground': (t.warning, t.ground),
        'warning/sheet': (t.warning, t.sheet),
        'onSuccess/success': (t.onSuccess, t.success),
        'onAction/action': (t.onAction, t.action),
        'ground/text (your mark)': (t.ground, t.text),
        'onAction/own (selected own chip)': (t.onAction, t.own),
      };
      for (final MapEntry(:key, :value) in textPairs.entries) {
        expect(
          contrast(value.$1, value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '$name $key',
        );
      }
      for (final (key, fg, bg) in [
        ('boundary/ground', t.boundary, t.ground),
        ('boundary/sheet', t.boundary, t.sheet),
        ('success/ground', t.success, t.ground),
        ('success/sheet', t.success, t.sheet),
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(3), reason: '$name $key');
      }
    });
  }
}
