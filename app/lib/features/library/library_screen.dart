import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/services.dart';
import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../accounts/accounts_screen.dart';
import '../compose/choose_screen.dart';
import '../compose/draft_session.dart';
import '../compose/version_screen.dart';
import '../compose/write_screen.dart';
import '../compose/compose_stage.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../media/picker_imports.dart';
import '../review/review_screen.dart';
import '../review/review_service.dart';
import 'library_repository.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Draft>? _drafts;
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
      final drafts = await LibraryRepository(widget.services.drafts)
          .listDrafts();
      if (mounted) setState(() => _drafts = drafts);
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
      if (mounted) await _open(draft);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Draft draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ComposeHost(services: widget.services, initial: draft),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _accounts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountsScreen(accounts: widget.services.accounts),
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
    return CaptionScaffold(
      title: 'Your posts',
      actions: [
        IconButton(
          tooltip: 'Accounts',
          onPressed: _accounts,
          icon: const Icon(Icons.person_outline),
        ),
      ],
      primaryAction: _drafts != null && !_results && !empty
          ? FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('New post'),
            )
          : null,
      body: Column(
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
              Text('${widget.services.pickerRecoveryError}'),
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
            Text('Your saved data has been kept. $_error'),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
          if (_drafts != null) ...[
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
            if (_results)
              const Text('No posting results yet')
            else if (empty) ...[
              const SizedBox(height: 16),
              const CaptionText('Write once.'),
              const SizedBox(height: 6),
              const CaptionText('Review each destination.'),
              const SizedBox(height: 6),
              const CaptionText('Finish Instagram yourself.'),
              const SizedBox(height: 40),
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
                'X and Bluesky publish from this app once connected. Instagram never needs a sign-in here; you finish posts in Instagram.',
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
                    'Saved ${_savedTime(draft.updatedAt)} · ${draft.selected.isEmpty ? 'No destinations' : draft.selected.map(destinationName).join(', ')} · ${_stageName(draft.stage)}',
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
  const _ComposeHost({required this.services, required this.initial});
  final AppServices services;
  final Draft initial;
  @override
  State<_ComposeHost> createState() => _ComposeHostState();
}

class _ComposeHostState extends State<_ComposeHost> {
  late final DraftController _controller;
  late ComposeStage _visibleStage;
  @override
  void initState() {
    super.initState();
    _controller = DraftController(
      widget.initial,
      widget.services.drafts,
      widget.services.clock,
    );
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
          onChangeDestinations: _choose,
        )
      : ReviewScreen(
          controller: _controller,
          service: ReviewService(
            widget.services.drafts,
            widget.services.media,
            widget.services.accounts,
            const LocalValidators(),
            widget.services.clock,
          ),
          onEdit: _editReview,
          onManageAccounts: _reviewAccounts,
          // I1/P tasks will wire a real checked action. Review never calls this.
          onConfirm: (_) async {},
        );

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
          controller: _controller,
        ),
      ),
    ),
  );
}
