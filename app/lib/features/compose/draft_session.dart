import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/caption_tokens.dart';
import '../accounts/account.dart';
import '../drafts/draft_controller.dart';

/// Shared editor exit/lifecycle guard. L6/L7 keep this around the active editor.
class DraftSession extends StatefulWidget {
  const DraftSession({
    super.key,
    required this.controller,
    required this.child,
    this.onExitPendingChanged,
  });
  final DraftController controller;
  final Widget child;
  final ValueChanged<bool>? onExitPendingChanged;
  @override
  State<DraftSession> createState() => _DraftSessionState();
}

class _DraftSessionState extends State<DraftSession>
    with WidgetsBindingObserver {
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
    }
  }

  void _setExitPending(bool pending) {
    setState(() => _leaving = pending);
    widget.onExitPendingChanged?.call(pending);
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final route = ModalRoute.of(context);
    _setExitPending(true);
    final saved = await widget.controller.flush();
    if (!mounted) return;
    if (!saved) {
      _setExitPending(false);
      return;
    }
    final revision = widget.controller.savedRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (identical(ModalRoute.of(context), route) &&
          route?.isCurrent == true &&
          widget.controller.saveState == SaveState.saved &&
          widget.controller.savedRevision == revision &&
          widget.controller.draft.revision == revision) {
        Navigator.of(context).pop();
      }
      if (mounted) _setExitPending(false);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
    },
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final captions = <String, String>{
          'Shared caption': widget.controller.draft.shared.text,
          for (final entry in widget.controller.draft.versions.entries)
            if (entry.value.ownText != null)
              '${destinationName(entry.key)} own caption': entry.value.ownText!,
        };
        return Column(
          children: [
            if (widget.controller.saveState == SaveState.failed)
              Flexible(
                child: Material(
                  color: CaptionTokens.raised,
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Couldn't save — keep this screen open",
                              style: TextStyle(color: CaptionTokens.error),
                            ),
                            Text('${widget.controller.lastError}'),
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(
                                      text: captions.entries
                                          .map(
                                            (entry) =>
                                                '${entry.key}:\n${entry.value}',
                                          )
                                          .join('\n\n'),
                                    ),
                                  ),
                                  child: const Text('Copy text'),
                                ),
                                TextButton(
                                  onPressed: widget.controller.retrySave,
                                  child: const Text('Retry saving'),
                                ),
                              ],
                            ),
                            for (final entry in captions.entries) ...[
                              const SizedBox(height: 12),
                              Text(entry.key),
                              SelectableText(entry.value),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: AbsorbPointer(absorbing: _leaving, child: widget.child),
            ),
          ],
        );
      },
    ),
  );
}
