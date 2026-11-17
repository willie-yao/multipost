import 'package:freezed_annotation/freezed_annotation.dart';

import '../drafts/draft.dart';
part 'account.freezed.dart';
part 'account.g.dart';

enum AccountState { disconnected, connecting, connected, expired, unavailable }

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
