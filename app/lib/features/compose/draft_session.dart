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
  });
  final DraftController controller;
  final Widget child;
  @override
  State<DraftSession> createState() => _DraftSessionState();
}

class _DraftSessionState extends State<DraftSession>
    with WidgetsBindingObserver {
  bool _allowPop = false;
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

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final saved = await widget.controller.flush();
    if (mounted && saved) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
    }
    _leaving = false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
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
            Expanded(child: widget.child),
          ],
        );
      },
    ),
  );
}
