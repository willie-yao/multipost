import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../../storage/local_database.dart';
import '../accounts/account.dart';
import '../accounts/account_repository.dart';
import '../accounts/accounts_screen.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'draft_session.dart';
import 'compose_stage.dart';

class ChooseScreen extends StatefulWidget {
  const ChooseScreen({
    super.key,
    required this.controller,
    required this.accounts,
    required this.onContinue,
    this.onRepairMedia,
    this.connections = const {},
  });
  final DraftController controller;
  final AccountRepository accounts;
  final Map<Destination, AccountConnection> connections;
  final VoidCallback onContinue;
  final Future<void> Function()? onRepairMedia;
  @override
  State<ChooseScreen> createState() => _ChooseScreenState();
}

class _ChooseScreenState extends State<ChooseScreen> {
  List<AccountView>? _accounts;
  bool _assisted = true;
  bool _busy = false;
  bool _exitPending = false;
  bool get _blocked => _busy || _exitPending;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await widget.accounts.list();
      final assisted = await widget.accounts.instagramAssistedSharing();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _assisted = assisted;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _continue() async {
    if (_blocked) return;
    setState(() => _busy = true);
    final controller = widget.controller;
    if (await saveComposeStage(controller, ComposeStage.write) && mounted) {
      widget.onContinue();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _accountsScreen() async {
    if (_blocked) return;
    setState(() => _busy = true);
    try {
      if (!await widget.controller.flush() || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DraftSession(
            controller: widget.controller,
            child: AccountsScreen(
              accounts: widget.accounts,
              connections: widget.connections,
              controller: widget.controller,
            ),
          ),
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repairMedia() async {
    if (_blocked ||
        widget.onRepairMedia == null ||
        widget.controller.lastError is! MediaFileException) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onRepairMedia!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DraftSession(
    controller: widget.controller,
    exitBlocked: _busy,
    onExitPendingChanged: (pending) {
      if (mounted) setState(() => _exitPending = pending);
    },
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => CaptionScaffold(
        title: 'New post',
        stageIndicator: const CaptionStageIndicator(currentStage: 1),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _blocked ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        primaryAction: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.controller.draft.selected.isEmpty) ...[
              Text(
                'Choose at least one destination.',
                style: TextStyle(
                  fontSize: 14,
                  color: CaptionTokens.of(context).secondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed:
                  _blocked ||
                      widget.controller.draft.selected.isEmpty ||
                      _accounts == null
                  ? null
                  : _continue,
              child: const Text('Continue to writing'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where should this go?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (_accounts == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(switch (_error) {
                LocalStorageException(:final message) => message,
                _ => 'Destinations could not load. Keep this screen open and retry.',
              }),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            for (final account in _accounts ?? <AccountView>[]) ...[
              const Divider(),
              CheckboxListTile(
                key: ValueKey('choose-${account.destination.name}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  destinationName(account.destination),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      accountMark(account),
                      if (account.destination == Destination.instagram) ...[
                        const SizedBox(height: 6),
                        const Text('You finish it in Instagram.'),
                      ],
                    ],
                  ),
                ),
                value: widget.controller.draft.selected.contains(
                  account.destination,
                ),
                onChanged:
                    _blocked ||
                        (account.destination == Destination.instagram &&
                            !_assisted &&
                            !widget.controller.draft.selected.contains(
                              account.destination,
                            ))
                    ? null
                    : (value) => widget.controller.change(
                        setDestination(
                          widget.controller.draft,
                          account.destination,
                          value ?? false,
                          DateTime.now().toUtc(),
                        ),
                      ),
              ),
            ],
            if (!_assisted)
              const Text(
                'Instagram assisted sharing is off. Enable it in Accounts to select Instagram.',
              ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _blocked ? null : _accountsScreen,
              icon: const Icon(Icons.person_outline),
              label: const Text('Manage accounts'),
            ),
            const SizedBox(height: 8),
            if (widget.controller.lastError is MediaFileException &&
                widget.onRepairMedia != null)
              OutlinedButton(
                onPressed: _blocked ? null : _repairMedia,
                child: const Text('Repair draft media'),
              ),
            DraftSaveStatus(controller: widget.controller),
          ],
        ),
      ),
    ),
  );
}
