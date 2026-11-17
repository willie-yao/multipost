import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/services.dart';
import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../../storage/local_database.dart';
import '../drafts/draft_repository.dart';
import '../accounts/account.dart';
import '../accounts/accounts_screen.dart';
import '../compose/choose_screen.dart';
import '../compose/draft_session.dart';
import '../compose/version_screen.dart';
import '../compose/write_screen.dart';
import '../compose/compose_stage.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../instagram/instagram_package.dart';
import '../instagram/instagram_screen.dart';
import '../media/picker_imports.dart';
import '../review/review.dart';
import '../review/review_screen.dart';
import '../publishing/attempt.dart';
import '../publishing/results_screen.dart';
import 'library_repository.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Draft>? _drafts;
  List<AttemptGroup> _groups = [];
  List<LibraryAttention> _attention = [];
  List<InstagramPackage> _packages = [];
  List<InstagramPackage> _markedPackages = [];
  Object? _error;
  bool _results = false;
  bool _busy = false;
  bool _recovering = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _drafts = null;
      _error = null;
    });
    try {
      await widget.services.refreshPicker();
      final repository = LibraryRepository(
        widget.services.drafts,
        widget.services.instagramRepo,
        attempts: widget.services.attempts,
      );
      final drafts = await repository.listDrafts();
      final groups = await repository.listGroups();
      final attention = await repository.listAttention();
      final packages = await repository.pendingInstagram();
      final markedPackages = await repository.markedInstagram();
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _groups = groups;
          _attention = attention;
          _packages = packages;
          _markedPackages = markedPackages;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _retryRecovery() async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      await widget.services.recoverPicker(ImagePicker());
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final draft = Draft(
        id: widget.services.ids.next(),
        updatedAt: widget.services.clock.now(),
      );
      await widget.services.drafts.save(draft, expectedRevision: -1);
      if (mounted) await _routeDraft(draft);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Draft draft) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _routeDraft(draft);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _routeDraft(Draft draft) async {
    final parentId = draft.retryParentAttemptId;
    if (parentId != null) {
      final child = await widget.services.attempts.childForOperation(
        parentId,
        draft.retryOperationId!,
      );
      if (child != null) {
        final attempt = await widget.services.attempts.getAttempt(child);
        if (attempt != null) return _openResults(attempt.groupId);
      }
    } else {
      final group = await widget.services.attempts.getGroupForDraft(draft.id);
      if (group != null) return _openResults(group.id);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ComposeHost(services: widget.services, initial: draft),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openResults(String groupId) async {
    if (!mounted) return;
    await Navigator.of(context).push(_resultsRoute(widget.services, groupId));
    if (mounted) await _load();
  }

  Future<void> _openPackage(InstagramPackage package) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstagramScreen(
          package: package,
          service: widget.services.instagram,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _accounts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountsScreen(
          accounts: widget.services.accounts,
          connections: widget.services.connections,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(Draft draft) async {
    try {
      await widget.services.drafts.setDeleted(
        draft.id,
        widget.services.clock.now(),
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Draft deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await widget.services.drafts.setDeleted(draft.id, null);
                if (mounted) await _load();
              } catch (error) {
                if (mounted) setState(() => _error = error);
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _recover(
    PickerImportOperation operation, {
    required bool attach,
  }) async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            attach ? 'Attach recovered media?' : 'Discard this selection?',
          ),
          content: Text(
            attach
                ? 'Attach to the original ${operation.destination == null ? 'shared media' : destinationName(operation.destination!)} in draft ${operation.draftId}. A changed draft will be kept without attaching.'
                : 'The original draft and existing prepared packages stay available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep selection'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                attach ? 'Attach to original draft' : 'Discard selection',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (attach) {
        await widget.services.attachRecovered(operation);
      } else {
        await widget.services.discardRecovered(operation);
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _drafts?.isEmpty ?? false;
    final operation = widget.services.recoveredPicker;
    final firstRun =
        empty &&
        !_results &&
        _groups.isEmpty &&
        _packages.isEmpty &&
        _markedPackages.isEmpty;
    return CaptionScaffold(
      title: 'Your posts',
      bodyPadding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: 'Accounts',
          onPressed: _accounts,
          icon: const Icon(Icons.person_outline),
        ),
      ],
      primaryAction:
          _drafts != null &&
              !_results &&
              (!empty ||
                  _groups.isNotEmpty ||
                  _packages.isNotEmpty ||
                  _markedPackages.isNotEmpty)
          ? FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('New post'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (firstRun)
            const ColoredBox(
              color: CaptionTokens.stage,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CaptionText('Write once.'),
                    SizedBox(height: 6),
                    CaptionText('Review each destination.'),
                    SizedBox(height: 6),
                    CaptionText('Finish Instagram yourself.'),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_drafts == null && _error == null) ...[
                  const Center(child: CircularProgressIndicator()),
                  const Text('Loading drafts…'),
                ],
                if (operation != null ||
                    widget.services.pickerRecoveryError != null) ...[
                  const CaptionText('A media selection needs your attention.'),
                  const SizedBox(height: 8),
                  if (widget.services.pickerRecoveryError != null)
                    Text(switch (widget.services.pickerRecoveryError) {
                      MediaFileException(:final message) => message,
                      _ => 'Media recovery could not finish. Keep this data and retry recovery.',
                    }),
                  if (widget.services.pickerRecoveryError != null)
                    TextButton(
                      onPressed: _recovering ? null : _retryRecovery,
                      child: const Text('Retry media recovery'),
                    ),
                  if (operation != null) ...[
                    Text(
                      'Original draft: ${operation.draftId} · ${operation.destination == null ? 'Shared media' : destinationName(operation.destination!)}',
                    ),
                    Text(
                      operation.isComplete
                          ? '${operation.assets.length} recovered item(s). Nothing has been attached automatically.'
                          : 'Selection interrupted. Nothing has been attached automatically.',
                    ),
                    if (operation.isComplete)
                      OutlinedButton(
                        onPressed: _recovering
                            ? null
                            : () => _recover(operation, attach: true),
                        child: const Text('Review recovered selection'),
                      ),
                    TextButton(
                      onPressed: _recovering
                          ? null
                          : () => _recover(operation, attach: false),
                      child: const Text('Discard recovered selection'),
                    ),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                if (_error != null) ...[
                  Text(switch (_error) {
                    DraftConflict() ||
                    DraftRecoveryException() => _error.toString(),
                    MediaFileException(:final message) ||
                    LocalStorageException(:final message) => message,
                    _ => 'This action could not finish. Keep this library open and retry.',
                  }),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
                if (_drafts != null) ...[
                  for (final item in _attention.where(
                    (item) => item.group != null,
                  )) ...[
                    const CaptionText('Needs your attention'),
                    const SizedBox(height: 8),
                    Text(item.destinations.map(destinationName).join(' · ')),
                    Text(
                      item.group!.snapshot.posts.values.first.content.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _openResults(item.group!.id),
                      child: const Text('Review posting results'),
                    ),
                    const Divider(height: 32),
                  ],
                  if (_packages.isNotEmpty) ...[
                    const CaptionText('Instagram needs finishing'),
                    const SizedBox(height: 8),
                    for (final package in _packages) ...[
                      Text(
                        package.ownCaption ? 'Own caption' : 'Shared caption',
                        style: const TextStyle(
                          color: CaptionTokens.secondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.caption.isEmpty
                            ? 'Prepared photos'
                            : package.caption,
                        style: TextStyle(
                          color: package.ownCaption
                              ? CaptionTokens.own
                              : CaptionTokens.text,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${package.photos.length} prepared photos · ${_savedTime(package.createdAt)} · finish in Instagram',
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _openPackage(package),
                          child: const Text('View prepared package'),
                        ),
                      ),
                      const Divider(height: 32),
                    ],
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          selected: !_results,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: !_results
                                      ? CaptionTokens.text
                                      : CaptionTokens.ground,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => setState(() => _results = false),
                              child: const Text('Drafts'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          selected: _results,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _results
                                      ? CaptionTokens.text
                                      : CaptionTokens.ground,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => setState(() => _results = true),
                              child: const Text('Results'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_results &&
                      (_groups.isNotEmpty || _markedPackages.isNotEmpty)) ...[
                    for (final group in _groups) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          group.snapshot.posts.values.first.content.text.isEmpty
                              ? 'Reviewed post'
                              : group.snapshot.posts.values.first.content.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${Destination.values.where(group.snapshot.posts.containsKey).map(destinationName).join(', ')} · reviewed ${_savedTime(group.createdAt)}',
                        ),
                        onTap: _busy ? null : () => _openResults(group.id),
                      ),
                      const Divider(height: 24),
                    ],
                    for (final package in _markedPackages) ...[
                      Text(
                        'Instagram · Marked posted',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        package.ownCaption ? 'Own caption' : 'Shared caption',
                        style: const TextStyle(color: CaptionTokens.secondary),
                      ),
                      Text(
                        package.caption.isEmpty
                            ? 'Prepared photos'
                            : package.caption,
                        style: TextStyle(
                          color: package.ownCaption
                              ? CaptionTokens.own
                              : CaptionTokens.text,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your confirmation on this phone. Not verified by the app.',
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _openPackage(package),
                        child: const Text('View Instagram record'),
                      ),
                      const Divider(height: 32),
                    ],
                  ] else if (_results)
                    const Text('No posting results yet')
                  else if (empty &&
                      (_groups.isNotEmpty ||
                          _packages.isNotEmpty ||
                          _markedPackages.isNotEmpty))
                    const Text(
                      'No drafts. Prepared packages and Instagram records are kept in Your posts.',
                    )
                  else if (empty) ...[
                    Text(
                      'Your next post starts here.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Drafts are saved on this device. You can write before connecting any account.',
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Create a draft'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _accounts,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Set up accounts'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Direct publishing to X and Bluesky is unavailable in this build. Instagram needs no sign-in here; you finish posts in Instagram.',
                    ),
                  ] else ...[
                    for (final draft in _drafts!) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          draft.shared.text.isEmpty
                              ? 'Untitled draft'
                              : draft.shared.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${draft.retryParentAttemptId == null ? 'Saved' : 'Saved retry'} ${_savedTime(draft.updatedAt)} · ${draft.selected.isEmpty ? 'No destinations' : draft.selected.map(destinationName).join(', ')} · ${_stageName(draft.stage)}',
                        ),
                        onTap: _busy ? null : () => _open(draft),
                        trailing: IconButton(
                          tooltip: 'Delete draft',
                          onPressed: _busy ? null : () => _delete(draft),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Drafts live on this device only. Uninstalling the app removes them.',
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _savedTime(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _stageName(ComposeStage stage) => switch (stage) {
  ComposeStage.choose => 'Choose',
  ComposeStage.write => 'Write',
  ComposeStage.review => 'Review',
};

// The controller belongs to this route through Choose, Write and Review.
class _ComposeHost extends StatefulWidget {
  const _ComposeHost({
    required this.services,
    required this.initial,
    this.returnToExistingResults = false,
  });
  final AppServices services;
  final Draft initial;
  final bool returnToExistingResults;
  @override
  State<_ComposeHost> createState() => _ComposeHostState();
}

class _ComposeHostState extends State<_ComposeHost> {
  late final DraftController _controller;
  late ComposeStage _visibleStage;
  late final String _operationId;
  @override
  void initState() {
    super.initState();
    _controller = DraftController(
      widget.initial,
      widget.services.drafts,
      widget.services.clock,
    );
    _operationId =
        widget.initial.retryOperationId ?? widget.services.ids.next();
    _visibleStage = widget.initial.stage;
    _controller.addListener(_syncSavedStage);
  }

  void _syncSavedStage() {
    final draft = _controller.draft;
    if (mounted &&
        _controller.saveState == SaveState.saved &&
        _controller.savedRevision == draft.revision &&
        _visibleStage != draft.stage) {
      setState(() => _visibleStage = draft.stage);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSavedStage);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    await saveComposeStage(_controller, ComposeStage.choose);
  }

  Future<void> _repairMedia() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WriteScreen(
        controller: _controller,
        media: widget.services.media,
        pickerImports: widget.services.pickerImports,
        canLaunchPicker: widget.services.pickerRecoveryReady,
        repairOnly: true,
        onReview: () {},
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _visibleStage == ComposeStage.choose
      ? ChooseScreen(
          controller: _controller,
          accounts: widget.services.accounts,
          connections: widget.services.connections,
          onContinue: _syncSavedStage,
          onRepairMedia: _repairMedia,
        )
      : _visibleStage == ComposeStage.write
      ? WriteScreen(
          controller: _controller,
          media: widget.services.media,
          pickerImports: widget.services.pickerImports,
          canLaunchPicker: widget.services.pickerRecoveryReady,
          onReview: _syncSavedStage,
          onChangeDestinations: widget.initial.retryParentAttemptId == null
              ? _choose
              : null,
        )
      : ReviewScreen(
          controller: _controller,
          service: widget.services.review,
          onEdit: _editReview,
          onManageAccounts: _reviewAccounts,
          observeOnline: () async =>
              await widget.services.publishingOnline?.call(),
          contextNotice: widget.initial.retryParentAttemptId == null ? null : "Only this saved recovery version will be sent. Successful destinations and the original source stay frozen. Sending an Unknown version again requires a duplicate-risk decision.",
          onConfirm: _publish,
        );

  Future<void> _publish(ReviewedPost reviewed) async {
    final draft = _controller.draft;
    if (draft.revision != reviewed.revision ||
        _controller.savedRevision != reviewed.revision ||
        _controller.saveState != SaveState.saved) {
      throw StateError('Review this saved version again before publishing.');
    }
    String groupId;
    if (draft.retryParentAttemptId case final parentId?) {
      final parent = await widget.services.attempts.getAttempt(parentId);
      if (parent == null) {
        throw StateError('The original attempt is unavailable.');
      }
      if (parent.outcome.status == PublishStatus.unknown) {
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('This could create a duplicate post'),
            content: Text(
              '${destinationName(parent.snapshot.destination)} may already have published the earlier version. Check your profile first. Send only this reviewed version again if you accept that both posts may be visible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep checking'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I accept the duplicate risk'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await widget.services.publishing.resendAfterCheck(
          parentId,
          reviewed,
          operationId: _operationId,
          duplicateRiskAccepted: accepted!,
        );
      } else {
        await widget.services.publishing.retry(
          parentId,
          reviewed,
          operationId: _operationId,
        );
      }
      groupId = parent.groupId;
    } else {
      groupId = await widget.services.publishing.confirm(
        reviewed,
        operationId: _operationId,
      );
    }
    if (!mounted) return;
    if (widget.returnToExistingResults) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      _resultsRoute(
        widget.services,
        groupId,
        openPreparedInstagramOnEntry:
            reviewed.posts.length == 1 &&
            reviewed.posts.containsKey(Destination.instagram),
      ),
    );
  }

  Future<void> _editReview(Destination? destination) async {
    if (destination == null) {
      if (_controller.lastError is MediaFileException) {
        await _repairMedia();
      } else {
        final saved = await saveComposeStage(_controller, ComposeStage.write);
        if (!saved && mounted && _controller.lastError is MediaFileException) {
          await _repairMedia();
        }
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VersionScreen(
          controller: _controller,
          destination: destination,
          media: widget.services.media,
          pickerImports: widget.services.pickerImports,
          canLaunchPicker: widget.services.pickerRecoveryReady,
        ),
      ),
    );
  }

  Future<void> _reviewAccounts() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DraftSession(
        controller: _controller,
        child: AccountsScreen(
          accounts: widget.services.accounts,
          connections: widget.services.connections,
          controller: _controller,
        ),
      ),
    ),
  );
}

MaterialPageRoute<void> _resultsRoute(
  AppServices services,
  String groupId, {
  bool openPreparedInstagramOnEntry = false,
}) => MaterialPageRoute<void>(
  builder: (context) => ResultsScreen(
    groupId: groupId,
    openPreparedInstagramOnEntry: openPreparedInstagramOnEntry,
    attempts: services.attempts,
    coordinator: services.publishing,
    instagram: services.instagramRepo,
    onRetry: (attempt) async {
      final draft = await services.retryEdits.open(attempt.id);
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _ComposeHost(
            services: services,
            initial: draft,
            returnToExistingResults: true,
          ),
        ),
      );
    },
    onManageAccounts: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountsScreen(
          accounts: services.accounts,
          connections: services.connections,
        ),
      ),
    ),
  ),
);
