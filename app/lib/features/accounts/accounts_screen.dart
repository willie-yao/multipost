import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'account.dart';
import 'account_repository.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.accounts, this.controller});
  final AccountRepository accounts;
  final DraftController? controller;
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AccountView>? _accounts;
  bool _assisted = true;
  Object? _error;
  bool _busy = false;
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

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    final controller = widget.controller;
    final selected =
        controller?.draft.selected.contains(Destination.instagram) ?? false;
    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn off assisted sharing?'),
          content: Text(
            selected
                ? 'Remove Instagram from this draft? Existing prepared packages stay available.'
                : 'Existing prepared packages stay available. You can turn assisted sharing on again at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep enabled'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      if (controller != null && !await controller.flush()) return;
      if (!enabled && selected) {
        controller!.change(
          setDestination(
            controller.draft,
            Destination.instagram,
            false,
            DateTime.now().toUtc(),
          ),
        );
        if (!await controller.flush()) return;
      }
      await widget.accounts.setInstagramAssistedSharing(enabled);
      if (mounted) {
        setState(() {
          _assisted = enabled;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _connectionSetup(Destination destination) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connection setup required'),
      content: Text(
        '${destinationName(destination)} connection is unavailable because its official connection configuration has not been supplied. You can keep drafting now.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep drafting'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => CaptionScaffold(
    title: 'Accounts',
    actions: [
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connect only where you publish. Writing drafts never needs an account.',
        ),
        if (_error != null) ...[
          Text('Accounts could not load or save. $_error'),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (_accounts == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        for (final account in _accounts ?? <AccountView>[]) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            destinationName(account.destination),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (account.destination == Destination.instagram) ...[
            const Text('No sign-in'),
            const SizedBox(height: 8),
            const Text(
              'This app prepares photos and the caption on this phone. You choose the account and publish in Instagram.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Assisted sharing'),
              value: _assisted,
              onChanged: _busy ? null : _toggle,
            ),
          ] else ...[
            Text(switch (account.state) {
              AccountState.disconnected => 'Not connected',
              AccountState.connecting => 'Connecting',
              AccountState.connected => 'Connected',
              AccountState.expired => 'Connection expired',
              AccountState.unavailable => 'Unavailable',
            }),
            Text(account.capability),
            if (account.identity != null) Text(account.identity!.handle),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => _connectionSetup(account.destination),
                child: const Text('Connection setup required'),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        const Divider(),
        const Text(
          "Sign-in uses each service's own official flow. Services can change what they allow, so each publish is checked first.",
        ),
      ],
    ),
  );
}
