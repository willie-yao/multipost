import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/caption_tokens.dart';
import '../../core/safe_errors.dart';
import '../../storage/local_database.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_repository.dart';

/// Shared editor exit/lifecycle guard. L6/L7 keep this around the active editor.
class DraftSession extends StatefulWidget {
  const DraftSession({
    super.key,
    required this.controller,
    required this.child,
    this.onExitPendingChanged,
    this.exitBlocked = false,
    this.allowMediaRepairReturn = false,
    this.onStepBack,
  });
  final DraftController controller;

  /// When set, Back (the arrow or the system gesture) returns to the previous
  /// compose stage instead of leaving the draft.
  final Future<void> Function()? onStepBack;
  final Widget child;
  final ValueChanged<bool>? onExitPendingChanged;
  final bool exitBlocked;

  /// Only inner editor routes whose parent retains this same controller.
  /// A failed-media save may return to that editor to repair another target.
  /// Root library exits must always leave this false.
  final bool allowMediaRepairReturn;
  @override
  State<DraftSession> createState() => _DraftSessionState();
}

class _DraftSessionState extends State<DraftSession>
    with WidgetsBindingObserver {
  bool _leaving = false;
  bool _reloading = false;
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
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_leaving || _reloading || widget.exitBlocked) return;
    final route = ModalRoute.of(context);
    _setExitPending(true);
    final saved = await widget.controller.flush();
    if (!mounted) return;
    final repairReturn =
        !saved &&
        widget.allowMediaRepairReturn &&
        widget.controller.lastError is MediaFileException;
    if (!saved && !repairReturn) {
      _setExitPending(false);
      return;
    }
    final revision = widget.controller.draft.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (identical(ModalRoute.of(context), route) &&
          route?.isCurrent == true &&
          widget.controller.draft.revision == revision &&
          ((widget.controller.saveState == SaveState.saved &&
                  widget.controller.savedRevision == revision) ||
              (repairReturn &&
                  widget.controller.saveState == SaveState.failed &&
                  widget.controller.lastError is MediaFileException))) {
        Navigator.of(context).pop();
      }
      if (mounted) _setExitPending(false);
    });
  }

  Future<void> _stepBack() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_leaving || _reloading || widget.exitBlocked) return;
    // Like leaving, stepping back waits for a successful save, so a failed
    // save never bounces between stages.
    if (!await widget.controller.flush() || !mounted) return;
    await widget.onStepBack!();
  }

  Future<void> _reload() async {
    if (_leaving || _reloading || widget.exitBlocked) return;
    final local = widget.controller.draft;
    setState(() => _reloading = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reload the saved draft?'),
          content: const Text(
            'This replaces your unsaved captions and media edits with the saved copy. Use Copy text first to keep your words.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace with saved copy'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await widget.controller.reloadAfterConflict(
          expectedLocalRevision: local.revision,
        );
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        unawaited(widget.onStepBack == null ? _leave() : _stepBack());
      }
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
                  color: CaptionTokens.of(context).raised,
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              userSafeMessage('storage-failed'),
                              style: TextStyle(
                                color: CaptionTokens.of(context).error,
                              ),
                            ),
                            // Only feature-owned, sanitized exception types may add detail.
                            if (widget.controller.lastError
                                case DraftConflict() ||
                                    DraftRecoveryException() ||
                                    MediaFileException() ||
                                    LocalStorageException())
                              Text(widget.controller.lastError.toString()),
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
                                  onPressed: _reloading
                                      ? null
                                      : widget.controller.retrySave,
                                  child: const Text('Retry saving'),
                                ),
                                if (widget.controller.lastError
                                    is DraftConflict)
                                  TextButton(
                                    onPressed: _reloading ? null : _reload,
                                    child: const Text('Reload saved draft'),
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
              child: AbsorbPointer(
                absorbing: _leaving || _reloading,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class DraftSaveStatus extends StatelessWidget {
  const DraftSaveStatus({super.key, required this.controller});
  final DraftController controller;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      switch (controller.saveState) {
        SaveState.saving => 'Saving…',
        SaveState.saved => 'Saved',
        SaveState.failed => 'Unsaved changes',
      },
      style: TextStyle(
        fontSize: 14,
        color: controller.saveState == SaveState.failed
            ? CaptionTokens.of(context).error
            : CaptionTokens.of(context).secondary,
      ),
    ),
  );
}
