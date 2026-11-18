import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../design/impression.dart';
import '../../design/post_sheet.dart';
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
    this.observeOnline,
    this.actionLabel,
    this.contextNotice,
    this.onEdit,
    this.onManageAccounts,
    this.onChangeDestinations,
  });
  final DraftController controller;
  final ReviewService service;

  /// Invoked only after flush, fresh revalidation and final local stale checks.
  final Future<void> Function(ReviewedPost) onConfirm;
  final ValueListenable<bool?>? directOnline;
  final Future<bool?> Function()? observeOnline;
  final String? actionLabel, contextNotice;

  /// null edits shared content; a destination edits only its own version.
  final Future<void> Function(Destination?)? onEdit;
  final Future<void> Function()? onManageAccounts;

  /// Back to Choose, so an empty review is never a dead end.
  final Future<void> Function()? onChangeDestinations;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReviewResult? _result;
  late Draft _observedDraft;
  bool? _online;
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
      try {
        _online = widget.observeOnline == null
            ? widget.directOnline?.value
            : await widget.observeOnline!();
      } catch (_) {
        _online = null;
      }
      final result = await widget.service.review(draft, directOnline: _online);
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

  bool _canPrepare(ReviewResult? result) => result != null && result.canProceed;

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
      bool? readiness;
      try {
        readiness = widget.observeOnline == null
            ? widget.directOnline?.value
            : await widget.observeOnline!();
      } catch (_) {
        readiness = null;
      }
      final checked = await widget.service.revalidate(
        reviewed!.snapshot,
        draft,
        directOnline: readiness,
      );
      if (!mounted || generation != _generation) return;
      if (widget.controller.draft != draft ||
          widget.controller.savedRevision != draft.revision ||
          widget.controller.saveState != SaveState.saved ||
          widget.observeOnline == null &&
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
          () => _notice = 'This action could not finish. Your saved draft and earlier results are kept. Review current requirements and try again.',
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
      // Retry versions open from Results, so Back returns there instead.
      onStepBack: widget.onEdit == null || widget.onChangeDestinations == null
          ? null
          : () => _edit(null),
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
        stageIndicator: CaptionStageIndicator(
          currentStage: 3,
          onStep: widget.onEdit == null || widget.onChangeDestinations == null
              ? null
              : (step) => step == 1
                    ? _navigate(widget.onChangeDestinations!)
                    : _edit(null),
        ),
        leading: IconButton(
          tooltip: widget.onEdit == null || widget.onChangeDestinations == null
              ? 'Back to library'
              : 'Back to Write',
          onPressed: _blocked ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        primaryAction: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_firstBlocker(result) case final issue?) ...[
              Text(
                '${destinationName(issue.destination)} · ${issueLabel(issue.code)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CaptionTokens.of(context).error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: draft.selected.isEmpty
                  ? (_blocked || widget.onChangeDestinations == null
                        ? null
                        : () => _navigate(widget.onChangeDestinations!))
                  : _blocked || !_canPrepare(result)
                  ? null
                  : _confirm,
              child: Text(
                draft.selected.isEmpty
                    ? 'Choose destinations'
                    : widget.actionLabel ?? reviewActionLabel(draft.selected),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.contextNotice != null) ...[
              Text(widget.contextNotice!),
              const SizedBox(height: 12),
            ],
            if (_online == false &&
                widget.controller.saveState == SaveState.saved) ...[
              ColoredBox(
                color: CaptionTokens.of(context).raised,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "You're offline. Review again when connected; nothing sends automatically.",
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_notice != null) ...[
              Semantics(liveRegion: true, child: Text(_notice!)),
              const SizedBox(height: 8),
            ],
            if (_busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking this saved post',
              ),
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
                  if (group) const Text('You finish it in Instagram.'),
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
            DraftSaveStatus(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  ReviewIssue? _firstBlocker(ReviewResult? result) {
    if (result == null || widget.controller.draft.selected.isEmpty) return null;
    for (final issue in result.issues) {
      if (issue.blocking) return issue;
    }
    return null;
  }

  /// Ready, or the first blocking problem, as a mark under the name.
  ImpressionMark _readinessMark(
    Destination destination,
    List<ReviewIssue> issues,
  ) {
    final blocking = issues.where((issue) => issue.blocking).toList();
    if (blocking.isNotEmpty) {
      return ImpressionMark(
        label: issueLabel(blocking.first.code),
        tone: ImpressionTone.attention,
      );
    }
    return ImpressionMark(
      label: destination == Destination.instagram
          ? 'Ready to prepare'
          : 'Ready to publish',
      tone: ImpressionTone.waiting,
      icon: Icons.check_circle_outline,
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
            if (post.account != null)
              Text(
                post.account!.handle,
                style: TextStyle(color: CaptionTokens.of(context).secondary),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _readinessMark(destination, issues),
        ),
        const SizedBox(height: 12),
        CaptionSourceLabel(own: post.ownCaption),
        const SizedBox(height: 6),
        if (post.content.text.isEmpty)
          const Text('No caption')
        else
          _ReviewCaption(text: post.content.text, own: post.ownCaption),
        const SizedBox(height: 12),
        MediaSourceLabel(ownCount: version?.ownMedia?.length),
        const SizedBox(height: 6),
        if (post.content.media.isEmpty)
          const Text('No media')
        else ...[
          MediaStrip(items: post.content.media, media: widget.service.media),
          for (var index = 0; index < post.content.media.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${index + 1} · ${post.content.media[index].altText.isEmpty ? 'No description' : post.content.media[index].altText}',
                style: TextStyle(
                  fontSize: 14,
                  color: CaptionTokens.of(context).secondary,
                ),
              ),
            ),
        ],
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          ColoredBox(
            color: CaptionTokens.of(context).raised,
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

/// A short name for a review issue, used on marks and the footer.
String issueLabel(String code) => switch (code) {
  'connection-expired' => 'Connection expired',
  'connection-needed' => 'Connection needed',
  'assisted-sharing-off' => 'Assisted sharing off',
  'instagram-photos-only' || 'instagram-photos-required' => 'Photos only',
  'empty-post' => 'Nothing to post',
  'media-unavailable' => 'Media missing',
  'unsupported-media' ||
  'mixed-media' ||
  'multiple-videos' => 'Media not supported',
  'not-available' => 'Not available in this build',
  'offline' => 'Offline',
  'connectivity-unverified' => 'Connection not checked',
  'validation-unavailable' => "Couldn't check requirements",
  'requirements-unverified' => "Couldn't check the text",
  _ => 'Needs checking',
};

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
      final painter =
          TextPainter(
            text: TextSpan(text: widget.text, style: captionStyle(context)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 3,
          )..layout(
            maxWidth: constraints.maxWidth - (widget.own ? ownCaptionInset : 0),
          );
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
