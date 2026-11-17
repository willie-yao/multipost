import 'package:cross_posting_app/core/safe_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unrecognized server detail cannot enter the UI message', () {
    final message = userSafeMessage('access_token=secret-caption-and-key');
    expect(
      message,
      'Something interrupted this action. Your saved work is still available.',
    );
    expect(message, isNot(contains('secret-caption')));
  });

  test('only exact allowlisted reasons select actionable copy', () {
    const messages = {
      'connection-needed': 'Reconnect this account before publishing.',
      'storage-failed': "Couldn't save — keep this screen open",
      'rate-limited': 'This service needs you to wait before trying again.',
      'access-unavailable':
          'Publishing access is unavailable for this account.',
    };
    for (final entry in messages.entries) {
      expect(userSafeMessage(entry.key), entry.value);
      expect(
        userSafeMessage('${entry.key}?token=synthetic-private'),
        'Something interrupted this action. Your saved work is still available.',
      );
    }
  });
}
