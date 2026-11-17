import 'dart:async';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/accounts_screen.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
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
  int connectCalls = 0;
  @override
  Future<AccountIdentity> connect({String? handle}) async {
    connectCalls++;
    await barrier?.future;
    if (error case final value?) throw value;
    const identity = AccountIdentity(
      destination: Destination.x,
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
}
