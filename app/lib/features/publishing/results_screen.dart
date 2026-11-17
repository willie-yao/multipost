import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../accounts/account.dart';
import '../drafts/draft.dart';
import '../instagram/instagram_package.dart';
import '../instagram/instagram_repository.dart';
import '../instagram/instagram_screen.dart';
import '../media/media_strip.dart';
import '../review/review.dart';
import 'attempt.dart';
import 'attempt_repository.dart';
import 'publish_coordinator.dart';
import 'publishing_boundary.dart';

String outcomeLabel(PublishOutcome outcome) => switch (outcome.status) {
  PublishStatus.pending => 'Not sent',
  PublishStatus.preparing => 'Preparing',
  PublishStatus.sending => 'Sending',
  PublishStatus.processing => 'Processing',
  PublishStatus.published => 'Published',
  PublishStatus.notPublished => 'Not published',
  PublishStatus.connectionNeeded => 'Connection needed',
  PublishStatus.unknown => 'Unknown',
  PublishStatus.userReported => 'Marked posted',
};

String outcomeDetail(PublishOutcome outcome) {
  if (outcome.status == PublishStatus.userReported) {
    return 'You marked this as posted · not verified by the app';
  }
  if (outcome.status == PublishStatus.published) {
    return 'Provider confirmation received.';
  }
  return outcome.message ??
      switch (outcome.status) {
        PublishStatus.pending => 'Not sent — continue when ready.',
        PublishStatus.preparing =>
          'Preparing the reviewed version. No publication is confirmed.',
        PublishStatus.sending =>
          'Sending the reviewed version. No publication is confirmed yet.',
        PublishStatus.processing => 'Media is still processing. Check status; publishing continues only when you choose.',
        PublishStatus.notPublished =>
          'This version was not published. Review it before another attempt.',
        PublishStatus.connectionNeeded =>
          'Connect this destination and review this version again.',
        PublishStatus.unknown =>
          'This destination may have published it. Check before sending again.',
        _ => '',
      };
}

String resultTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatShortDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.groupId,
    required this.attempts,
    required this.coordinator,
    required this.instagram,
    this.onRetry,
    this.onManageAccounts,
    this.openExternal,
    this.openPreparedInstagramOnEntry = false,
  });
  final String groupId;
  final bool openPreparedInstagramOnEntry;
  final AttemptRepository attempts;
  final PublishCoordinator coordinator;
  final InstagramRepository instagram;
  final Future<void> Function(DestinationAttempt)? onRetry;
  final Future<void> Function()? onManageAccounts;
  final Future<bool> Function(Destination, Uri)? openExternal;
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  AttemptGroup? _group;
  List<DestinationAttempt> _effective = [], _history = [];
  InstagramPreparation? _preparation;
  InstagramPackage? _package;
  InstagramProgress? _instagramProgress;
  bool _busy = false, _showHistory = false;
  String? _notice;
  final _expandedVersions = <String>{};
  bool _openedInitialInstagram = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final group = await widget.attempts.getGroup(widget.groupId);
      if (group == null) {
        throw StateError(
          'This saved result is unavailable. Keep its local data.',
        );
      }
      final effective = await widget.attempts.effectiveAttempts(widget.groupId);
      final history = await widget.attempts.attempts(widget.groupId);
      final preparation = await widget.attempts.instagramPreparation(
        widget.groupId,
      );
      final package = preparation?.packageId == null
          ? null
          : await widget.instagram.get(preparation!.packageId!);
      final progress = package == null
          ? null
          : await widget.instagram.progress(package.id);
      if (mounted) {
        setState(() {
          _group = group;
          _effective = effective;
          _history = history;
          _preparation = preparation;
          _package = package;
          _instagramProgress = progress;
        });
        if (widget.openPreparedInstagramOnEntry &&
            package != null &&
            !_openedInitialInstagram) {
          _openedInitialInstagram = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _instagram();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Saved results could not load. Keep the local data and try again.',
        );
      }
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice = error is PublishReviewRejected ? error.toString() : 'This action could not finish. Your saved results and reviewed versions are kept.',
        );
      }
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry(DestinationAttempt attempt) =>
      _act(() => widget.onRetry!(attempt));

  Future<void> _check(DestinationAttempt attempt) => _act(() async {
    await widget.coordinator.check(attempt.id);
    final current = await widget.attempts.getAttempt(attempt.id);
    if (current == null) return;
    final url = officialAttemptUrl(current, profileFallback: true);
    if (url == null ||
        !await (widget.openExternal ?? const PublishingBoundary().open)(
          current.snapshot.destination,
          url,
        )) {
      if (mounted) {
        setState(
          () => _notice = 'The official post or profile could not open. Check it in your browser; no publication has been inferred.',
        );
      }
    }
  });

  Future<void> _view(DestinationAttempt attempt) => _act(() async {
    final url = officialAttemptUrl(attempt);
    if (url == null ||
        !await (widget.openExternal ?? const PublishingBoundary().open)(
          attempt.snapshot.destination,
          url,
        )) {
      if (mounted) {
        setState(
          () => _notice =
              'The official post could not open. Your receipt stays here.',
        );
      }
    }
  });

  Future<void> _instagram() => _act(() async {
    if (_package == null) {
      await widget.coordinator.continueInstagram(
        widget.groupId,
        _group!.snapshot,
      );
      await _load();
    }
    final package = _package;
    if (package == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InstagramScreen(
          package: package,
          service: widget.coordinator.instagram,
        ),
      ),
    );
  });

  Future<void> _continue(DestinationAttempt attempt) => _act(() async {
    final frozen = await widget.attempts.reviewForAttempt(attempt.id);
    await widget.coordinator.continuePending(
      widget.groupId,
      frozen,
      attemptIds: {attempt.id},
    );
  });

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final instagramPending =
        _preparation != null &&
        _instagramProgress?.state != InstagramState.userMarked;
    // Effective direct snapshots win; Instagram stays tied to its frozen group.
    // A text-only or video-first destination must not hide a later photo.
    Attachment? headerPhoto;
    for (final destination in Destination.values) {
      final post =
          _effective
              .where((attempt) => attempt.snapshot.destination == destination)
              .firstOrNull
              ?.snapshot ??
          group?.snapshot.posts[destination];
      if (post == null) continue;
      for (final asset in post.assets) {
        if (!asset.mimeType.startsWith('image/')) continue;
        headerPhoto = post.content.media
            .where((attachment) => attachment.assetId == asset.id)
            .firstOrNull;
        if (headerPhoto != null) break;
      }
      if (headerPhoto != null) break;
    }
    final outstanding = _effective
        .where(
          (a) => !{
            PublishStatus.published,
            PublishStatus.userReported,
          }.contains(a.outcome.status),
        )
        .firstOrNull;
    var primaryLabel = 'Back to library';
    VoidCallback? primary = () => Navigator.maybePop(context);
    if (instagramPending) {
      primaryLabel = _package == null
          ? 'Continue preparing Instagram'
          : 'Finish in Instagram';
      primary = _instagram;
    } else if (outstanding != null) {
      final name = destinationName(outstanding.snapshot.destination);
      if (outstanding.outcome.status == PublishStatus.unknown) {
        primaryLabel = 'Check $name publication';
        primary = () => _check(outstanding);
      } else if (ordinaryRetryAllowed(outstanding.outcome) &&
          widget.onRetry != null) {
        primaryLabel = 'Review $name retry';
        primary = () => _retry(outstanding);
      } else if (outstanding.outcome.status == PublishStatus.pending ||
          outstanding.outcome.status == PublishStatus.processing &&
              outstanding.outcome.reasonCode == 'preparation-ready') {
        primaryLabel = 'Continue publishing $name';
        primary = () => _continue(outstanding);
      } else if (outstanding.outcome.status == PublishStatus.processing) {
        primaryLabel = 'Check $name preparation';
        primary = () => _act(() => widget.coordinator.check(outstanding.id));
      } else {
        primaryLabel = 'Publication not confirmed yet';
        primary = null;
      }
    }
    return CaptionScaffold(
      title: 'Posting results',
      bodyPadding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: 'Back to library',
        onPressed: _busy ? null : () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      primaryAction: group == null
          ? null
          : FilledButton(
              onPressed: _busy ? null : primary,
              child: Text(primaryLabel),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group == null && _notice == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Loading saved results…'),
            ),
          if (group != null) ...[
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                if (headerPhoto != null)
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: MediaPreview(
                      attachment: headerPhoto,
                      media: widget.coordinator.review.media,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final attempt in _effective)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ColoredBox(
                            color: CaptionTokens.stage,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: CaptionText(
                                '${destinationName(attempt.snapshot.destination)} · ${outcomeLabel(attempt.outcome)}',
                              ),
                            ),
                          ),
                        ),
                      if (_preparation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ColoredBox(
                            color: CaptionTokens.stage,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: CaptionText(
                                'Instagram · ${_instagramLabel()}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Reviewed ${resultTime(context, group.createdAt)} · each result is kept on this device.',
                style: const TextStyle(color: CaptionTokens.secondary),
              ),
            ),
          ],
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(liveRegion: true, child: Text(_notice!)),
            ),
          if (_busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Working on this explicit action',
            ),
          for (final attempt in _effective) _destination(attempt),
          if (_preparation != null) _instagramRow(),
          if (_history.length > _effective.length)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _showHistory = !_showHistory),
                    child: Text(
                      _showHistory
                          ? 'Hide attempt history'
                          : 'Attempt history (${_history.length})',
                    ),
                  ),
                  if (_showHistory)
                    for (final attempt in _history) _historyRow(attempt),
                ],
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: _busy ? null : () => _act(_load),
                child: const Text('Retry loading saved results'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _destination(DestinationAttempt attempt) {
    final outcome = attempt.outcome;
    final name = destinationName(attempt.snapshot.destination);
    final completed = {
      PublishStatus.published,
      PublishStatus.userReported,
    }.contains(outcome.status);
    final receipts = _history
        .where(
          (a) =>
              a.snapshot.destination == attempt.snapshot.destination &&
              a.outcome.status == PublishStatus.published,
        )
        .toList();
    return ColoredBox(
      color: completed ? CaptionTokens.ground : CaptionTokens.raised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                if (attempt.snapshot.account != null)
                  Text(
                    attempt.snapshot.account!.handle,
                    style: const TextStyle(color: CaptionTokens.secondary),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      outcome.status == PublishStatus.unknown
                          ? Icons.help_outline
                          : completed
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: completed
                          ? CaptionTokens.success
                          : outcome.status == PublishStatus.unknown
                          ? CaptionTokens.warning
                          : ordinaryRetryAllowed(outcome)
                          ? CaptionTokens.error
                          : CaptionTokens.secondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        outcomeLabel(outcome),
                        style: TextStyle(
                          color: completed
                              ? CaptionTokens.success
                              : outcome.status == PublishStatus.unknown
                              ? CaptionTokens.warning
                              : CaptionTokens.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              outcome.status == PublishStatus.published
                  ? 'Confirmed by $name · ${resultTime(context, outcome.at)}'
                  : outcomeDetail(outcome),
            ),
            if (outcome.retryAfter != null)
              Text('Try again ${resultTime(context, outcome.retryAfter!)}.'),
            if (!completed) _frozenContent(attempt.snapshot),
            if (completed && receipts.length <= 1) _reviewedVersion(attempt),
            if (outcome.status == PublishStatus.published &&
                officialAttemptUrl(attempt) != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _view(attempt),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('View $name post'),
                ),
              ),
            if (receipts.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                '${receipts.length} provider-confirmed publications. More than one post may be visible.',
              ),
              for (var index = 0; index < receipts.length; index++) ...[
                Text(
                  'Confirmed by $name · ${resultTime(context, receipts[index].outcome.at)}',
                ),
                _reviewedVersion(receipts[index]),
                TextButton(
                  onPressed:
                      _busy || officialAttemptUrl(receipts[index]) == null
                      ? null
                      : () => _view(receipts[index]),
                  child: Text('View $name receipt ${index + 1}'),
                ),
              ],
            ],
            if (ordinaryRetryAllowed(outcome))
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy || widget.onRetry == null
                      ? null
                      : () => _retry(attempt),
                  child: Text('Retry $name'),
                ),
              ),
            if (outcome.status == PublishStatus.connectionNeeded &&
                widget.onManageAccounts != null)
              TextButton(
                onPressed: _busy ? null : () => _act(widget.onManageAccounts!),
                child: Text('Manage $name connection'),
              ),
            if (outcome.status == PublishStatus.unknown) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _check(attempt),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('Check $name'),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => widget.coordinator.reportFound(attempt.id),
                          ),
                    child: const Text('I found the post'),
                  ),
                  TextButton(
                    onPressed: _busy || widget.onRetry == null
                        ? null
                        : () => _retry(attempt),
                    child: const Text('Send again…'),
                  ),
                ],
              ),
            ],
            if (outcome.status == PublishStatus.processing)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(() => widget.coordinator.check(attempt.id)),
                  child: Text('Check $name status'),
                ),
              ),
            if (outcome.status == PublishStatus.pending ||
                outcome.status == PublishStatus.processing &&
                    outcome.reasonCode == 'preparation-ready')
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _continue(attempt),
                  child: Text('Continue publishing $name'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewedVersion(DestinationAttempt attempt, {bool history = false}) {
    final key = (history ? 'history-' : '') + attempt.id;
    final expanded = _expandedVersions.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: ValueKey('reviewed-version-$key'),
            onPressed: () => setState(() {
              if (expanded) {
                _expandedVersions.remove(key);
              } else {
                _expandedVersions.add(key);
              }
            }),
            child: Text(
              expanded ? 'Hide reviewed version' : 'View reviewed version',
            ),
          ),
        ),
        if (expanded) _frozenContent(attempt.snapshot),
      ],
    );
  }

  Widget _frozenContent(ResolvedPost post) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          post.ownCaption
              ? 'Own caption · reviewed version'
              : 'Shared caption · reviewed version',
          style: const TextStyle(color: CaptionTokens.secondary),
        ),
        const SizedBox(height: 6),
        CaptionText(
          post.content.text.isEmpty ? 'No caption' : post.content.text,
          own: post.ownCaption,
        ),
        if (post.content.media.isNotEmpty) ...[
          const SizedBox(height: 12),
          MediaStrip(
            items: post.content.media,
            media: widget.coordinator.review.media,
          ),
          for (var index = 0; index < post.content.media.length; index++)
            Text(
              'Media ${index + 1} · ${post.content.media[index].altText.isEmpty ? 'No description' : post.content.media[index].altText}',
              style: const TextStyle(color: CaptionTokens.secondary),
            ),
        ],
      ],
    ),
  );

  String _instagramLabel() => _package != null
      ? switch (_instagramProgress?.state) {
          InstagramState.preparing => 'Preparing photos',
          InstagramState.ready => 'Ready to share',
          InstagramState.handedOff => 'Handed off',
          InstagramState.userMarked => 'Marked posted',
          null => 'Prepared package status unavailable',
        }
      : switch (_preparation!.state) {
          InstagramPreparationState.pending => 'Not prepared',
          InstagramPreparationState.preparing => 'Preparing photos',
          InstagramPreparationState.failed => 'Preparation needs attention',
          InstagramPreparationState.ready => 'Prepared package unavailable',
        };

  Widget _instagramRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('Instagram', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_instagramLabel()),
          Text(
            _instagramProgress?.state == InstagramState.userMarked
                ? 'Your confirmation on this phone · not verified by the app'
                : _instagramProgress?.state == InstagramState.handedOff
                ? 'Photos handed to Instagram. Posting is not confirmed.'
                : _package == null
                ? _preparation!.reason ?? 'Prepare the frozen photos and caption on this device, then finish in Instagram.'
                : 'Photos and caption prepared. You publish it in Instagram.',
          ),
          if (_package != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _instagram,
                child: const Text('View Instagram record'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyRow(DestinationAttempt attempt) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${destinationName(attempt.snapshot.destination)} · ${outcomeLabel(attempt.outcome)} · ${resultTime(context, attempt.outcome.at)}',
        ),
        if ({
          PublishStatus.published,
          PublishStatus.userReported,
        }.contains(attempt.outcome.status))
          _reviewedVersion(attempt, history: true)
        else
          _frozenContent(attempt.snapshot),
        Text(outcomeDetail(attempt.outcome)),
        if (attempt.outcome.status == PublishStatus.unknown)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _check(attempt),
                child: const Text('Check this earlier attempt'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(
                        () => widget.coordinator.reportFound(attempt.id),
                      ),
                child: const Text('I found this earlier post'),
              ),
            ],
          ),
      ],
    ),
  );
}
