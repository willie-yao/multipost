import 'dart:async';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/accounts/x_connection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_fixture.dart';

void main() {
  test(
    'token is bound to the reviewed subject across refresh and reconnect',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      expect(
        await h.x.accessToken(expectedSubject: '12345'),
        'opaque-access-initial',
      );
      await expectLater(
        h.x.accessToken(expectedSubject: '999'),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.connected,
      );
      h.clock.value = h.clock.value.add(const Duration(hours: 3));
      h.oauth.rotation = Completer<XTokenSet>();
      final token = h.x.accessToken(expectedSubject: '12345');
      final failure = expectLater(
        token,
        throwsA(isA<AccountConnectionCancelled>()),
      );
      await h.oauth.refreshStarted.future;
      await h.x.disconnect();
      h.subject = '67890';
      await h.x.connect();
      h.oauth.rotation!.complete(h.oauth.tokens('old-rotation'));
      await failure;
      expect(
        await h.x.accessToken(expectedSubject: '67890'),
        'opaque-access-initial',
      );
    },
  );
}
