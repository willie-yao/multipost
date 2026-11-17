import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../compose/draft_session.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import '../media/media_strip.dart';
import 'review.dart';
import 'review_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.controller,
    required this.service,
    required this.onConfirm,
    this.directOnline,
    this.onEdit,
    this.onManageAccounts,
  });
  final DraftController controller;
  final ReviewService service;

  /// Invoked only after flush, fresh revalidation and final local stale checks.
  final Future<void> Function(ReviewedPost) onConfirm;
  final ValueListenable<bool?>? directOnline;

  /// null edits shared content; a destination edits only its own version.
  final Future<void> Function(Destination?)? onEdit;
  final Future<void> Function()? onManageAccounts;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReviewResult? _result;
  late Draft _observedDraft;
  bool _busy = false;
  bool _exitPending = false;
  bool _refreshPending = false;
  int _generation = 0;
  String? _notice;
  bool get _blocked => _busy || _exitPending;

  @override
  void initState() {
    super.initState();
    _observedDraft = widget.controller.draft;
    widget.controller.addListener(_changed);
    widget.directOnline?.addListener(_readinessChanged);
    unawaited(_loadReview(_generation));
  }

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directOnline != widget.directOnline) {
      oldWidget.directOnline?.removeListener(_readinessChanged);
      widget.directOnline?.addListener(_readinessChanged);
      _requestReview();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.directOnline?.removeListener(_readinessChanged);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_observedDraft != widget.controller.draft) {
      _observedDraft = widget.controller.draft;
      _notice = 'This post changed. Review it again.';
      _requestReview();
    } else {
      setState(() {});
    }
  }

  void _readinessChanged() => _requestReview();

  void _requestReview({bool clearNotice = false}) {
    if (!mounted) return;
    _generation++;
    setState(() {
      _result = null;
      if (clearNotice) _notice = null;
    });
    if (_busy || _exitPending) {
      _refreshPending = true;
    } else {
      unawaited(_loadReview(_generation));
    }
  }

  Future<void> _loadReview(int generation) async {
    setState(() => _busy = true);
    try {
      if (!await widget.controller.flush()) {
        if (mounted && generation == _generation) {
          setState(() => _notice = 'Save this draft before reviewing.');
        }
        return;
      }
      if (!mounted || generation != _generation) return;
      final draft = widget.controller.draft;
      final result = await widget.service.review(
        draft,
        directOnline: widget.directOnline?.value,
      );
      if (!mounted || generation != _generation) return;
      if (widget.controller.draft != draft ||
          widget.controller.savedRevision != draft.revision ||
          widget.controller.saveState != SaveState.saved) {
        setState(() => _notice = 'This post changed. Review it again.');
        return;
      }
      setState(() => _result = result);
    } on StaleReviewException {
      if (mounted && generation == _generation) {
        setState(() => _notice = 'This post changed. Review it again.');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _notice = "Couldn't check current requirements");
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_refreshPending && !_exitPending) {
          _refreshPending = false;
          unawaited(_loadReview(_generation));
        }
      }
    }
  }

  Future<void> _edit(Destination? destination) async {
    if (_blocked || widget.onEdit == null) return;
    await _navigate(() => widget.onEdit!(destination), allowMediaRepair: true);
  }

  Future<void> _navigate(
    Future<void> Function() action, {
    bool allowMediaRepair = false,
  }) async {
    if (_blocked) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.controller.flush();
      if (!saved &&
          !(allowMediaRepair &&
              widget.controller.lastError is MediaFileException)) {
        return;
      }
      if (!mounted) return;
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshPending = false;
        _requestReview();
      }
    }
  }

  Future<void> _leaveOut(Destination destination) async {
    if (_blocked) return;
    setState(() => _busy = true);
    try {
      widget.controller.change(
        setDestination(
          widget.controller.draft,
          destination,
          false,
          DateTime.now().toUtc(),
        ),
      );
      await widget.controller.flush();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshPending = false;
        _requestReview();
      }
    }
  }

  bool _canPrepare(ReviewResult? result) =>
      result != null &&
      result.canProceed &&
      result.snapshot.posts.length == 1 &&
      result.snapshot.posts.containsKey(Destination.instagram);

  Future<void> _confirm() async {
    if (_blocked) return;
    final reviewed = _result;
    if (!_canPrepare(reviewed)) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      if (!await widget.controller.flush()) return;
      if (!mounted || generation != _generation) return;
      final draft = widget.controller.draft;
      final readiness = widget.directOnline?.value;
      final checked = await widget.service.revalidate(
        reviewed!.snapshot,
        draft,
        directOnline: readiness,
      );
      if (!mounted || generation != _generation) return;
      if (widget.controller.draft != draft ||
          widget.controller.savedRevision != draft.revision ||
          widget.controller.saveState != SaveState.saved ||
          widget.directOnline?.value != readiness) {
        throw const StaleReviewException();
      }
      setState(() => _result = checked);
      if (!_canPrepare(checked)) return;
      await widget.onConfirm(checked.snapshot);
    } on StaleReviewException {
      if (mounted) {
        setState(() => _notice = 'This post changed. Review it again.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice =
              'Instagram could not be prepared on this device. Your draft and earlier prepared versions are kept. $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_refreshPending && !_exitPending) {
          _refreshPending = false;
          unawaited(_loadReview(_generation));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.controller.draft;
    final result = _result;
    return DraftSession(
      controller: widget.controller,
      exitBlocked: _busy,
      onExitPendingChanged: (pending) {
        if (!mounted) return;
        setState(() => _exitPending = pending);
        if (!pending && _refreshPending && !_busy) {
          _refreshPending = false;
          unawaited(_loadReview(_generation));
        }
      },
      child: CaptionScaffold(
        title: 'New post',
        stageIndicator: const CaptionStageIndicator(currentStage: 3),
        actions: [
          IconButton(
            tooltip: 'Back to library',
            onPressed: _blocked ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
        primaryAction: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              draft.selected.any((d) => d != Destination.instagram)
                  ? 'Publishing setup required'
                  : 'Prepare a local photo package; finish in Instagram.',
              style: const TextStyle(
                fontSize: 14,
                color: CaptionTokens.secondary,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _blocked || !_canPrepare(result) ? null : _confirm,
              child: Text(
                draft.selected.isEmpty
                    ? 'Choose destinations'
                    : reviewActionLabel(draft.selected),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice != null) ...[
              Semantics(liveRegion: true, child: Text(_notice!)),
              const SizedBox(height: 8),
            ],
            if (_busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking this saved post',
              ),
            if (draft.selected.isEmpty)
              const Text('Choose at least one destination before continuing.'),
            if (result != null) ...[
              for (final group in [false, true])
                if (result.snapshot.posts.keys.any(
                  (d) => (d == Destination.instagram) == group,
                )) ...[
                  const SizedBox(height: 16),
                  Text(
                    group ? 'Prepare only' : 'Publish now',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (group)
                    const Text(
                      'You finish it in Instagram · choose the account there',
                    ),
                  for (final post in result.snapshot.posts.values.where(
                    (post) =>
                        (post.destination == Destination.instagram) == group,
                  ))
                    _destination(post, result),
                ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _blocked
                      ? null
                      : () => _requestReview(clearNotice: true),
                  child: const Text('Review again'),
                ),
                if (widget.onEdit != null)
                  TextButton(
                    onPressed: _blocked ? null : () => _edit(null),
                    child: const Text('Edit shared caption'),
                  ),
                if (widget.onManageAccounts != null)
                  TextButton(
                    onPressed: _blocked
                        ? null
                        : () => _navigate(widget.onManageAccounts!),
                    child: const Text('Manage accounts'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your draft stays on this device. Instagram preparation keeps a reviewed local copy; you select and check the photos and finish in Instagram.',
              style: TextStyle(fontSize: 14, color: CaptionTokens.secondary),
            ),
            const SizedBox(height: 8),
            DraftSaveStatus(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  Widget _destination(ResolvedPost post, ReviewResult result) {
    final destination = post.destination;
    final version = widget.controller.draft.versions[destination];
    final issues = result.issues
        .where((issue) => issue.destination == destination)
        .toList();
    final expired = issues.any((issue) => issue.code == 'connection-expired');
    final connectionNeeded = issues.any(
      (issue) => issue.code == 'connection-needed',
    );
    final instagramVideo = issues.any(
      (issue) => issue.code == 'instagram-photos-only',
    );
    return Column(
      key: ValueKey('review-${destination.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              destinationName(destination),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (post.account != null) Text(post.account!.handle),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          post.ownCaption ? 'Own caption' : 'Shared caption',
          style: const TextStyle(fontSize: 14, color: CaptionTokens.secondary),
        ),
        const Text(
          'Approximate preview',
          style: TextStyle(fontSize: 14, color: CaptionTokens.secondary),
        ),
        const SizedBox(height: 8),
        if (post.content.text.isEmpty)
          const Text('No caption')
        else
          _ReviewCaption(text: post.content.text, own: post.ownCaption),
        const SizedBox(height: 8),
        Text(
          version?.ownMedia != null ? 'Own media' : 'Shared media',
          style: const TextStyle(fontSize: 14, color: CaptionTokens.secondary),
        ),
        if (post.content.media.isEmpty) const Text('No media'),
        for (var index = 0; index < post.content.media.length; index++) ...[
          const SizedBox(height: 8),
          Text('Media ${index + 1} of ${post.content.media.length}'),
          SizedBox(
            height: 144,
            child: MediaPreview(
              attachment: post.content.media[index],
              media: widget.service.media,
            ),
          ),
          Text(
            post.content.media[index].altText.isEmpty
                ? 'No description'
                : post.content.media[index].altText,
          ),
        ],
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          ColoredBox(
            color: CaptionTokens.raised,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(issue.message),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if ((expired || connectionNeeded) &&
                          widget.onManageAccounts != null)
                        OutlinedButton(
                          onPressed: _blocked
                              ? null
                              : () => _navigate(widget.onManageAccounts!),
                          child: Text(expired ? 'Reconnect' : 'Connect'),
                        ),
                      if (instagramVideo && widget.onEdit != null)
                        OutlinedButton(
                          onPressed: _blocked
                              ? null
                              : () => _edit(Destination.instagram),
                          child: const Text('Choose own photos for Instagram'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _blocked ? null : () => _leaveOut(destination),
            child: Text('Leave ${destinationName(destination)} out'),
          ),
        ),
        if (widget.onEdit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _blocked ? null : () => _edit(destination),
              child: Text('Edit ${destinationName(destination)} version'),
            ),
          ),
      ],
    );
  }
}

class _ReviewCaption extends StatefulWidget {
  const _ReviewCaption({required this.text, required this.own});
  final String text;
  final bool own;
  @override
  State<_ReviewCaption> createState() => _ReviewCaptionState();
}

class _ReviewCaptionState extends State<_ReviewCaption> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: widget.text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
      )..layout(maxWidth: constraints.maxWidth);
      final truncated = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CaptionText(
            widget.text,
            own: widget.own,
            maxLines: _expanded ? null : 3,
          ),
          if (truncated)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Collapse caption' : 'Show full caption',
                ),
              ),
            ),
        ],
      );
    },
  );
}
