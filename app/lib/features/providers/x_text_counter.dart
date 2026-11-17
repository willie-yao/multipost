import 'dart:async';

import 'package:flutter/services.dart';

import 'capabilities.dart';

/// Official twitter-text 3.1.0, native Android implementation. Platform/channel
/// failures propagate to the blocking requirements-unverified validation issue.
class XTextCounter implements TextCounter {
  const XTextCounter();
  static const _channel = MethodChannel('crossposting/x-text');
  @override
  FutureOr<TextMeasurement> measure(String text) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'measure',
      text,
    );
    if (result == null ||
        result['units'] is! int ||
        result['valid'] is! bool ||
        (result['units'] as int) < 0) {
      throw const FormatException('Official text measurement unavailable');
    }
    return TextMeasurement(
      units: result['units'] as int,
      valid: result['valid'] as bool,
    );
  }
}
