import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'account.dart';
import 'account_repository.dart';
import 'credential_vault.dart';
import 'bluesky_oauth.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.accounts,
    this.controller,
    this.connections = const {},
  });
  final AccountRepository accounts;
  final Map<Destination, AccountConnection> connections;
  final DraftController? controller;
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AccountView>? _accounts;
  bool _assisted = true;
  String? _error;
  bool _busy = false;
  bool _loadFailed = false;
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
          _loadFailed = false;
          _accounts = accounts;
          _assisted = assisted;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error = 'Accounts could not load or save. Try again. Your drafts are safe.';
        });
      }
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
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error = 'Accounts could not load or save. Try again. Your drafts are safe.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectionAction(
    AccountView account, {
    bool disconnect = false,
    bool repair = false,
  }) async {
    if (_busy) return;
    final connection = widget.connections[account.destination];
    if (connection == null) return;
    setState(() {
      _busy = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      if (widget.controller != null && !await widget.controller!.flush()) {
        return;
      }
      if (repair) {
        await connection.repairCredentials();
      } else if (disconnect) {
        await connection.disconnect();
      } else {
        String? handle;
        if (account.destination == Destination.bluesky) {
          handle = await _askBlueskyHandle();
          if (handle == null) return;
        }
        await connection.connect(handle: handle);
      }
      await _load();
    } catch (error) {
      // Neither provider/native exceptions nor callback parameters enter the UI.
      if (mounted) {
        setState(
          () => _error = switch (error) {
            CredentialStorageFailure() =>
              repair
                  ? "Couldn't repair connection storage. Try again. Your drafts are safe."
                  : disconnect
                  ? "Couldn't remove this connection. Retry removal below. Your drafts are safe."
                  : error.toString(),
            UnsupportedBlueskyAccount() => error.toString(),
            AccountConnectionCancelled() =>
              'Connection cancelled. Your drafts are safe.',
            AccountConnectionExpired() =>
              'Connection expired. Reconnect to continue.',
            _ => "Couldn't connect right now. Check your connection and try again. Your drafts are safe.",
          },
        );
      }
      // A storage failure can have expired or disconnected public metadata.
      try {
        final accounts = await widget.accounts.list();
        if (mounted) setState(() => _accounts = accounts);
      } catch (_) {
        /* Keep the safe operation error. */
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askBlueskyHandle() {
    var handle = '';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('Connect Bluesky'),
          content: TextField(
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            decoration: const InputDecoration(
              labelText: 'Bluesky handle',
              hintText: 'you.bsky.social or a custom handle',
              helperText: 'Use your handle, never a password.',
              helperMaxLines: 3,
            ),
            onChanged: (value) => update(() => handle = value.trim()),
            onSubmitted: (_) {
              if (handle.isNotEmpty) Navigator.pop(context, handle);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep drafting'),
            ),
            FilledButton(
              onPressed: handle.isEmpty
                  ? null
                  : () => Navigator.pop(context, handle),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _repairConnection(AccountView account) async {
    if (_busy) return;
    final name = destinationName(account.destination);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Repair $name connection storage?'),
        content: Text(
          'Only this $name connection will be removed from this phone and its secure storage reset. Other connections, drafts, results and media stay. You will need to connect $name again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep connection data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repair storage'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _connectionAction(account, repair: true);
    }
  }

  void _connectionSetup(AccountView account) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connection setup required'),
      content: Text(account.capability),
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
    leading: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connect only where you publish. Writing drafts never needs an account.',
        ),
        if (_error != null) ...[
          Text(_error!),
          if (_loadFailed)
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Retry'),
            ),
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
              AccountState.repairRequired =>
                'Connection storage needs attention',
              AccountState.removalPending => 'Removal pending',
            }),
            Text(account.capability),
            if (account.identity != null) Text(account.identity!.handle),
            if (account.state != AccountState.removalPending &&
                account.state != AccountState.repairRequired)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : account.state == AccountState.unavailable ||
                            !widget.connections.containsKey(account.destination)
                      ? () => _connectionSetup(account)
                      : () => _connectionAction(account),
                  child: Text(
                    account.state == AccountState.unavailable ||
                            !widget.connections.containsKey(account.destination)
                        ? 'Connection setup required'
                        : account.state == AccountState.connected ||
                              account.state == AccountState.expired
                        ? 'Reconnect ${destinationName(account.destination)}'
                        : 'Connect ${destinationName(account.destination)}',
                  ),
                ),
              ),
            if (account.state == AccountState.removalPending &&
                widget.connections.containsKey(account.destination))
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _connectionAction(account, disconnect: true),
                  child: Text(
                    'Retry removing ${destinationName(account.destination)}',
                  ),
                ),
              ),
            if ((account.state == AccountState.repairRequired ||
                    account.state == AccountState.removalPending) &&
                widget.connections.containsKey(account.destination))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => _repairConnection(account),
                  child: Text(
                    'Repair ${destinationName(account.destination)} connection storage',
                  ),
                ),
              ),
            if (account.identity != null &&
                widget.connections.containsKey(account.destination))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _connectionAction(account, disconnect: true),
                  child: Text(
                    'Disconnect ${destinationName(account.destination)}',
                  ),
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
