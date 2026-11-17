import 'package:freezed_annotation/freezed_annotation.dart';

import '../drafts/draft.dart';
part 'account.freezed.dart';
part 'account.g.dart';

enum AccountState {
  disconnected,
  connecting,
  connected,
  expired,
  unavailable,
  repairRequired,
  removalPending,
}

@freezed
abstract class AccountIdentity with _$AccountIdentity {
  const factory AccountIdentity({
    required Destination destination,
    required String subject,
    required String handle,
  }) = _AccountIdentity;
  factory AccountIdentity.fromJson(Map<String, dynamic> json) =>
      _$AccountIdentityFromJson(json);
}

@freezed
abstract class AccountView with _$AccountView {
  const factory AccountView({
    required Destination destination,
    required AccountState state,
    AccountIdentity? identity,
    required String capability,
  }) = _AccountView;
  factory AccountView.fromJson(Map<String, dynamic> json) =>
      _$AccountViewFromJson(json);
}

String destinationName(Destination value) => switch (value) {
  Destination.x => 'X',
  Destination.bluesky => 'Bluesky',
  Destination.instagram => 'Instagram',
};

/// A connection owns authorization only; publishing capability is checked separately.
abstract interface class AccountConnection {
  Future<AccountIdentity> connect({String? handle});
  Future<void> disconnect();
  Future<void> repairCredentials();
  Future<void> ensureAuthorized();
}

class AccountConnectionCancelled implements Exception {
  const AccountConnectionCancelled();
  @override
  String toString() => 'Connection cancelled. Your drafts are safe.';
}

class AccountConnectionExpired implements Exception {
  const AccountConnectionExpired();
  @override
  String toString() => 'Connection expired. Reconnect to continue.';
}

class AccountConnectionUnavailable implements Exception {
  const AccountConnectionUnavailable();
  @override
  String toString() =>
      "Couldn't connect right now. Check your connection and try again. Your drafts are safe.";
}
