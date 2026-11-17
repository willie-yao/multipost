import 'dart:async';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/accounts_screen.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/accounts/bluesky_oauth.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Accounts implements AccountRepository {
  AccountView value = const AccountView(
    destination: Destination.x,
    state: AccountState.disconnected,
    capability: 'Publishing verification still required.',
  );
  bool failLoad = false;
  @override
  Future<List<AccountView>> list() async {
    if (failLoad) throw StateError('opaque-secret callback?code=private');
    return [value];
  }

  @override
  Future<AccountView> get(Destination destination) async => value;
  @override
  Future<void> save(AccountView account) async {
    value = account;
  }

  @override
  Future<void> setState(Destination destination, AccountState state) async {
    value = value.copyWith(state: state);
  }

  @override
  Future<bool> instagramAssistedSharing() async => true;
  @override
  Future<void> setInstagramAssistedSharing(bool enabled) async {}
}

class _Connection implements AccountConnection {
  _Connection(this.accounts);
  final _Accounts accounts;
  Object? error;
  Completer<void>? barrier;
  String? receivedHandle;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int repairCalls = 0;
  bool deleteFails = false;
  @override
  Future<AccountIdentity> connect({String? handle}) async {
    connectCalls++;
    receivedHandle = handle;
    await barrier?.future;
    if (error case final value?) throw value;
    final identity = AccountIdentity(
      destination: accounts.value.destination,
      subject: '123',
      handle: '@person',
    );
    accounts.value = accounts.value.copyWith(
      state: AccountState.connected,
      identity: identity,
    );
    return identity;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (deleteFails) {
      accounts.value = accounts.value.copyWith(
        state: AccountState.removalPending,
        identity: null,
      );
      throw const CredentialStorageFailure();
    }
    accounts.value = accounts.value.copyWith(
      state: AccountState.disconnected,
      identity: null,
    );
  }

  @override
  Future<void> repairCredentials() async {
    repairCalls++;
    accounts.value = accounts.value.copyWith(
      state: AccountState.disconnected,
      identity: null,
    );
  }

  @override
  Future<void> ensureAuthorized() async {}
}

void main() {
  testWidgets(
    'Bluesky asks for a handle and cancel does not start authorization',
    (tester) async {
      final accounts = _Accounts();
      accounts.value = accounts.value.copyWith(
        destination: Destination.bluesky,
      );
      final connection = _Connection(accounts);
      await tester.pumpWidget(
        CaptionApp(
          home: AccountsScreen(
            accounts: accounts,
            connections: {Destination.bluesky: connection},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect Bluesky'));
      await tester.pumpAndSettle();
      expect(find.text('Bluesky handle'), findsOneWidget);
      await tester.tap(find.text('Keep drafting'));
      await tester.pumpAndSettle();
      expect(connection.connectCalls, 0);
      await tester.tap(find.text('Connect Bluesky'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '  custom.example  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(connection.receivedHandle, 'custom.example');
      expect(find.text('Connected'), findsOneWidget);
    },
  );
  testWidgets(
    'unsupported Bluesky hosting displays safe named reason at 320dp 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final accounts = _Accounts();
      accounts.value = accounts.value.copyWith(
        destination: Destination.bluesky,
      );
      final connection = _Connection(accounts)
        ..error = const UnsupportedBlueskyAccount();
      await tester.pumpWidget(
        CaptionApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AccountsScreen(
              accounts: accounts,
              connections: {Destination.bluesky: connection},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Connect Bluesky'));
      await tester.tap(find.text('Connect Bluesky'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'custom.example');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Custom PDS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'connect shows stable handle and disconnect updates public account',
    (tester) async {
      final accounts = _Accounts();
      final connection = _Connection(accounts);
      await tester.pumpWidget(
        CaptionApp(
          home: AccountsScreen(
            accounts: accounts,
            connections: {Destination.x: connection},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect X'));
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('@person'), findsOneWidget);
      expect(
        find.text('Publishing verification still required.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Disconnect X'));
      await tester.pumpAndSettle();
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('@person'), findsNothing);
    },
  );
  testWidgets(
    'busy connection blocks repeated connect and displays safe storage error',
    (tester) async {
      final accounts = _Accounts();
      final connection = _Connection(accounts)
        ..barrier = Completer<void>()
        ..error = const CredentialStorageFailure();
      await tester.pumpWidget(
        CaptionApp(
          home: AccountsScreen(
            accounts: accounts,
            connections: {Destination.x: connection},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect X'));
      await tester.pump();
      await tester.tap(find.text('Connect X'));
      await tester.pump();
      expect(connection.connectCalls, 1);
      connection.barrier!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't securely save this connection. Try again."),
        findsOneWidget,
      );
      expect(find.text('Connected'), findsNothing);
    },
  );
  testWidgets('account load error never prints raw exception or callback', (
    tester,
  ) async {
    final accounts = _Accounts()..failLoad = true;
    await tester.pumpWidget(
      CaptionApp(home: AccountsScreen(accounts: accounts)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('opaque-secret'), findsNothing);
    expect(find.textContaining('callback?code'), findsNothing);
    expect(
      find.text(
        'Accounts could not load or save. Try again. Your drafts are safe.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'unavailable account displays actual setup reason and keeps drafting',
    (tester) async {
      final accounts = _Accounts();
      accounts.value = accounts.value.copyWith(
        state: AccountState.unavailable,
        capability: 'X connection verification is incomplete in this build. Keep drafting.',
      );
      await tester.pumpWidget(
        CaptionApp(home: AccountsScreen(accounts: accounts)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connection setup required'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'X connection verification is incomplete in this build. Keep drafting.',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Keep drafting'), findsOneWidget);
    },
  );
  testWidgets('Accounts reflows at 320dp and 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AccountsScreen(accounts: _Accounts()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Accounts'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Sign-in uses'), 200);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed removal can be retried after reopening at 320dp 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = _Accounts();
      final connection = _Connection(accounts);
      await connection.connect();
      connection.deleteFails = true;
      Widget screen(Key key) => CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AccountsScreen(
            key: key,
            accounts: accounts,
            connections: {Destination.x: connection},
          ),
        ),
      );
      await tester.pumpWidget(screen(const ValueKey(1)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reconnect X'));
      await tester.ensureVisible(find.text('Disconnect X'));
      await tester.tap(find.text('Disconnect X'));
      await tester.pumpAndSettle();
      expect(find.text('Removal pending'), findsOneWidget);
      expect(find.text('Connect X'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      await tester.ensureVisible(find.text('Retry removing X'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(screen(const ValueKey(2)));
      await tester.pumpAndSettle();
      connection.deleteFails = false;
      await tester.ensureVisible(find.text('Retry removing X'));
      await tester.tap(find.text('Retry removing X'));
      await tester.pumpAndSettle();
      expect(connection.disconnectCalls, 2);
      expect(find.text('Not connected'), findsOneWidget);
      expect(connection.connectCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repair requires confirmation and leaves fresh connect explicit at 320dp 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = _Accounts();
      accounts.value = accounts.value.copyWith(
        state: AccountState.repairRequired,
      );
      final connection = _Connection(accounts);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AccountsScreen(
              accounts: accounts,
              connections: {Destination.x: connection},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Repair X connection storage'));
      await tester.tap(find.text('Repair X connection storage'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only this X connection'), findsOneWidget);
      await tester.ensureVisible(find.text('Keep connection data'));
      await tester.tap(find.text('Keep connection data'));
      await tester.pumpAndSettle();
      expect(connection.repairCalls, 0);
      await tester.ensureVisible(find.text('Repair X connection storage'));
      await tester.tap(find.text('Repair X connection storage'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Repair storage'));
      await tester.tap(find.text('Repair storage'));
      await tester.pumpAndSettle();
      expect(connection.repairCalls, 1);
      expect(connection.connectCalls, 0);
      expect(find.text('Connected'), findsNothing);
      await tester.ensureVisible(find.text('Connect X'));
      await tester.tap(find.text('Connect X'));
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
