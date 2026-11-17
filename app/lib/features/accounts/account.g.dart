// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountIdentity _$AccountIdentityFromJson(Map<String, dynamic> json) =>
    _AccountIdentity(
      destination: $enumDecode(_$DestinationEnumMap, json['destination']),
      subject: json['subject'] as String,
      handle: json['handle'] as String,
    );

Map<String, dynamic> _$AccountIdentityToJson(_AccountIdentity instance) =>
    <String, dynamic>{
      'destination': _$DestinationEnumMap[instance.destination]!,
      'subject': instance.subject,
      'handle': instance.handle,
    };

const _$DestinationEnumMap = {
  Destination.x: 'x',
  Destination.bluesky: 'bluesky',
  Destination.instagram: 'instagram',
};

_AccountView _$AccountViewFromJson(Map<String, dynamic> json) => _AccountView(
  destination: $enumDecode(_$DestinationEnumMap, json['destination']),
  state: $enumDecode(_$AccountStateEnumMap, json['state']),
  identity: json['identity'] == null
      ? null
      : AccountIdentity.fromJson(json['identity'] as Map<String, dynamic>),
  capability: json['capability'] as String,
);

Map<String, dynamic> _$AccountViewToJson(_AccountView instance) =>
    <String, dynamic>{
      'destination': _$DestinationEnumMap[instance.destination]!,
      'state': _$AccountStateEnumMap[instance.state]!,
      'identity': instance.identity?.toJson(),
      'capability': instance.capability,
    };

const _$AccountStateEnumMap = {
  AccountState.disconnected: 'disconnected',
  AccountState.connecting: 'connecting',
  AccountState.connected: 'connected',
  AccountState.expired: 'expired',
  AccountState.unavailable: 'unavailable',
  AccountState.repairRequired: 'repairRequired',
  AccountState.removalPending: 'removalPending',
};
