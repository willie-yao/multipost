import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_tokens.dart';
import '../../design/impression.dart';
import '../../design/post_sheet.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'account.dart';
import 'account_repository.dart';
import 'credential_vault.dart';
import 'bluesky_oauth.dart';

/// A destination's connection state as a mark: the same word on Accounts
/// and Choose, with a tone that says whether it needs you.
ImpressionMark accountMark(AccountView account) =>
    switch (account.destination == Destination.instagram
    ? null
    : account.state) {
      null => const ImpressionMark(
        label: 'No sign-in',
        tone: ImpressionTone.waiting,
        icon: Icons.check,
      ),
      AccountState.connected => const ImpressionMark(
        label: 'Connected',
        tone: ImpressionTone.confirmed,
      ),
      AccountState.connecting => const ImpressionMark(
        label: 'Connecting',
        tone: ImpressionTone.waiting,
        icon: Icons.sync,
      ),
      AccountState.disconnected => const ImpressionMark(
        label: 'Not connected',
        tone: ImpressionTone.waiting,
        icon: Icons.link_off,
      ),
      AccountState.unavailable => const ImpressionMark(
        label: 'Not available',
        tone: ImpressionTone.waiting,
        icon: Icons.block,
      ),
      AccountState.expired => const ImpressionMark(
        label: 'Connection expired',
        tone: ImpressionTone.attention,
      ),
      AccountState.repairRequired => const ImpressionMark(
        label: 'Needs repair',
        tone: ImpressionTone.attention,
      ),
      AccountState.removalPending => const ImpressionMark(
        label: 'Removal pending',
        tone: ImpressionTone.attention,
      ),
    };

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

  Future<void> _confirmDisconnect(AccountView account) async {
    final name = destinationName(account.destination);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect $name?'),
        content: Text(
          'This phone forgets the $name connection. Drafts and results stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep connected'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Disconnect $name'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _connectionAction(account, disconnect: true);
    }
  }

  /// The state's one recovery action, outlined; null when there is none.
  Widget? _recovery(AccountView account) {
    final name = destinationName(account.destination);
    if (account.state == AccountState.unavailable ||
        !widget.connections.containsKey(account.destination)) {
      return null;
    }
    final (label, VoidCallback action) = switch (account.state) {
      AccountState.removalPending => (
        'Retry removing $name',
        () => _connectionAction(account, disconnect: true),
      ),
      AccountState.repairRequired => (
        'Repair $name connection storage',
        () => _repairConnection(account),
      ),
      AccountState.connected || AccountState.expired => (
        'Reconnect $name',
        () => _connectionAction(account),
      ),
      AccountState.connecting => (
        'Start sign-in again',
        () => _connectionAction(account),
      ),
      _ => ('Connect $name', () => _connectionAction(account)),
    };
    return OutlinedButton(onPressed: _busy ? null : action, child: Text(label));
  }

  /// One plain line per state; the setup detail stays behind "Why?".
  String? _plainState(AccountView account, bool setupRequired) {
    final name = destinationName(account.destination);
    if (setupRequired) return null;
    return switch (account.state) {
      AccountState.connected => null,
      AccountState.connecting => null,
      AccountState.disconnected => null,
      AccountState.expired => null,
      AccountState.repairRequired =>
        "This phone can't read the saved $name connection.",
      AccountState.removalPending => "Removing $name didn't finish.",
      AccountState.unavailable => null,
    };
  }

  void _details(AccountView account) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${destinationName(account.destination)} details'),
      content: Text(account.capability),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _connectionSetup(AccountView account) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        "Why ${destinationName(account.destination)} isn't available",
      ),
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
  Widget build(BuildContext context) {
    // The three destinations are known up front, so their sheets show at once
    // and fill in when the saved state arrives instead of popping in.
    final loaded = {
      for (final account in _accounts ?? <AccountView>[])
        account.destination: account,
    };
    return CaptionScaffold(
      title: 'Accounts',
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: CaptionTokens.of(context).error),
              ),
            ),
            if (_loadFailed)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Retry'),
                ),
              ),
            const SizedBox(height: 12),
          ],
          // Placeholders only while loading; afterwards, exactly the loaded
          // destinations (none after a load error).
          for (final destination in Destination.values)
            if (_accounts == null && _error == null ||
                loaded.containsKey(destination))
              _row(destination, loaded[destination]),
        ],
      ),
    );
  }

  /// States where the account needs the person: the one row raised on a sheet.
  static const _needsYou = {
    AccountState.expired,
    AccountState.repairRequired,
    AccountState.removalPending,
  };

  /// A ledger row per destination: name with its state mark on the same line,
  /// then the handle or one plain line, then actions. Only a row that needs
  /// the person is raised; the rest sit on hairlines. [account] is null while
  /// the saved state loads, so rows never pop in.
  Widget _row(Destination destination, AccountView? account) {
    final t = CaptionTokens.of(context);
    final name = destinationName(destination);
    final setupRequired =
        account != null &&
        (account.state == AccountState.unavailable ||
            !widget.connections.containsKey(destination));
    final note = account == null || destination == Destination.instagram
        ? null
        : _plainState(account, setupRequired);
    final body = <Widget>[
      if (account?.identity case final identity?)
        Semantics(
          label: 'Account ${identity.handle}',
          excludeSemantics: true,
          child: Text(
            identity.handle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      if (note != null) Text(note, style: TextStyle(color: t.secondary)),
      if (account != null && destination == Destination.instagram)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Assisted sharing'),
          subtitle: const Text('Off hides Instagram when you choose.'),
          value: _assisted,
          onChanged: _busy ? null : _toggle,
        ),
      if (account != null && destination != Destination.instagram) ...[
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // One outlined recovery action per state, then Details.
            ?_recovery(account),
            if (account.state == AccountState.removalPending &&
                widget.connections.containsKey(destination))
              TextButton(
                onPressed: _busy ? null : () => _repairConnection(account),
                child: Text('Repair $name connection storage'),
              ),
            setupRequired
                ? TextButton(
                    onPressed: _busy ? null : () => _connectionSetup(account),
                    child: Text("Why isn't $name available?"),
                  )
                : TextButton(
                    onPressed: _busy ? null : () => _details(account),
                    child: const Text('Details'),
                  ),
            // Disconnect is destructive, so it trails the row's other actions.
            if (account.identity != null &&
                account.state != AccountState.removalPending &&
                widget.connections.containsKey(destination))
              TextButton(
                onPressed: _busy ? null : () => _confirmDisconnect(account),
                style: TextButton.styleFrom(foregroundColor: t.error),
                child: Text('Disconnect $name'),
              ),
          ],
        ),
      ],
    ];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [if (body.isNotEmpty) const SizedBox(height: 6), ...body],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Semantics(
              header: true,
              child: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            account == null
                ? const ImpressionMark(
                    label: 'Checking…',
                    tone: ImpressionTone.waiting,
                    icon: Icons.sync,
                  )
                : accountMark(account),
          ],
        ),
        // A zero-length AnimatedSize re-lays itself out mid-layout, so with
        // animations off the details simply appear.
        if (MediaQuery.disableAnimationsOf(context))
          details
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: details,
          ),
      ],
    );
    if (account != null && _needsYou.contains(account.state)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: PostSheet(child: content),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: content,
      ),
    );
  }
}
