import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../design/caption_tokens.dart';
import '../drafts/draft.dart';
import '../providers/capabilities.dart';
import '../providers/x_text_counter.dart';

/// "218 / 280" against the destination's documented limit, measured with the
/// same counter Review uses (X's official twitter-text, Bluesky graphemes).
/// Instagram has no limit here, and nothing shows if measuring fails: Review
/// still checks before anything is sent.
class DestinationLength extends StatefulWidget {
  const DestinationLength({
    super.key,
    required this.destination,
    required this.text,
  });
  final Destination destination;
  final String text;

  @override
  State<DestinationLength> createState() => _DestinationLengthState();
}

class _DestinationLengthState extends State<DestinationLength> {
  TextMeasurement? _measured;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(DestinationLength old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.destination != widget.destination) {
      _measure();
    }
  }

  Future<void> _measure() async {
    if (widget.destination == Destination.instagram) return;
    final request = ++_request;
    final TextCounter counter = widget.destination == Destination.x
        ? const XTextCounter()
        : const BlueskyTextCounter();
    try {
      final measured = await counter.measure(widget.text);
      if (mounted && request == _request) setState(() => _measured = measured);
    } catch (_) {
      if (mounted && request == _request) setState(() => _measured = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final measured = _measured;
    if (widget.destination == Destination.instagram || measured == null) {
      return const SizedBox.shrink();
    }
    final t = CaptionTokens.of(context);
    final limit = ProviderCapabilities.documented(widget.destination)
        .maxTextUnits;
    final over = measured.units - limit;
    return Text(
      over > 0
          ? '${measured.units} / $limit · over by $over'
          : '${measured.units} / $limit',
      style: TextStyle(
        fontSize: 14,
        fontWeight: over > 0 ? FontWeight.w700 : FontWeight.w400,
        color: over > 0 ? t.error : t.secondary,
      ),
    );
  }
}
