import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../accounts/account.dart';
import '../accounts/account_repository.dart';
import '../accounts/accounts_screen.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'draft_session.dart';

class ChooseScreen extends StatefulWidget {
  const ChooseScreen({
    super.key,
    required this.controller,
    required this.accounts,
    required this.onContinue,
  });
  final DraftController controller;
  final AccountRepository accounts;
  final VoidCallback onContinue;
  @override
  State<ChooseScreen> createState() => _ChooseScreenState();
}

class _ChooseScreenState extends State<ChooseScreen> {
  List<AccountView>? _accounts;
  bool _assisted = true;
  bool _busy = false;
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
    setState(() => _busy = true);
    final controller = widget.controller;
    if (await controller.flush()) {
      controller.change(
        setStage(controller.draft, ComposeStage.write, DateTime.now().toUtc()),
      );
      if (await controller.flush() && mounted) widget.onContinue();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _accountsScreen() async {
    if (!await widget.controller.flush() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DraftSession(
          controller: widget.controller,
          child: AccountsScreen(
            accounts: widget.accounts,
            controller: widget.controller,
          ),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => DraftSession(
    controller: widget.controller,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => CaptionScaffold(
        title: 'New post',
        stageIndicator: const CaptionStageIndicator(currentStage: 1),
        actions: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
        primaryAction: FilledButton(
          onPressed:
              _busy ||
                  widget.controller.draft.selected.isEmpty ||
                  _accounts == null
              ? null
              : _continue,
          child: const Text('Continue to writing'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where should this go?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Nothing is sent until you review it.'),
            const SizedBox(height: 24),
            if (_accounts == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text('Destinations could not load. $_error'),
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
                  child: Text(
                    account.destination == Destination.instagram
                        ? 'You finish it in Instagram · choose the account there'
                        : account.state == AccountState.connected
                        ? 'Publishes from this app · connected'
                        : 'Connect before publishing',
                  ),
                ),
                value: widget.controller.draft.selected.contains(
                  account.destination,
                ),
                onChanged:
                    _busy ||
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
              onPressed: _busy ? null : _accountsScreen,
              icon: const Icon(Icons.person_outline),
              label: const Text('Manage accounts'),
            ),
            const SizedBox(height: 8),
            Text(switch (widget.controller.saveState) {
              SaveState.saving => 'Saving on this device…',
              SaveState.saved => 'Saved on this device',
              SaveState.failed => 'Unsaved changes',
            }),
          ],
        ),
      ),
    ),
  );
}
