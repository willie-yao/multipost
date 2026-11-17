// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResolvedPost _$ResolvedPostFromJson(Map<String, dynamic> json) => ResolvedPost(
  destination: $enumDecode(_$DestinationEnumMap, json['destination']),
  content: PostContent.fromJson(json['content'] as Map<String, dynamic>),
  assets: (json['assets'] as List<dynamic>)
      .map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
      .toList(),
  account: json['account'] == null
      ? null
      : AccountIdentity.fromJson(json['account'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ResolvedPostToJson(ResolvedPost instance) =>
    <String, dynamic>{
      'destination': _$DestinationEnumMap[instance.destination]!,
      'content': instance.content.toJson(),
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'account': instance.account?.toJson(),
    };

const _$DestinationEnumMap = {
  Destination.x: 'x',
  Destination.bluesky: 'bluesky',
  Destination.instagram: 'instagram',
};

ReviewedPost _$ReviewedPostFromJson(Map<String, dynamic> json) => ReviewedPost(
  draftId: json['draftId'] as String,
  revision: (json['revision'] as num).toInt(),
  posts: (json['posts'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      $enumDecode(_$DestinationEnumMap, k),
      ResolvedPost.fromJson(e as Map<String, dynamic>),
    ),
  ),
  capabilityVersions: (json['capabilityVersions'] as Map<String, dynamic>).map(
    (k, e) => MapEntry($enumDecode(_$DestinationEnumMap, k), e as String),
  ),
  reviewedAt: DateTime.parse(json['reviewedAt'] as String),
);

Map<String, dynamic> _$ReviewedPostToJson(ReviewedPost instance) =>
    <String, dynamic>{
      'draftId': instance.draftId,
      'revision': instance.revision,
      'posts': instance.posts.map(
        (k, e) => MapEntry(_$DestinationEnumMap[k]!, e.toJson()),
      ),
      'capabilityVersions': instance.capabilityVersions.map(
        (k, e) => MapEntry(_$DestinationEnumMap[k]!, e),
      ),
      'reviewedAt': instance.reviewedAt.toIso8601String(),
    };

ReviewResult _$ReviewResultFromJson(Map<String, dynamic> json) => ReviewResult(
  snapshot: ReviewedPost.fromJson(json['snapshot'] as Map<String, dynamic>),
  issues: (json['issues'] as List<dynamic>)
      .map((e) => ReviewIssue.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ReviewResultToJson(ReviewResult instance) =>
    <String, dynamic>{
      'snapshot': instance.snapshot.toJson(),
      'issues': instance.issues.map((e) => e.toJson()).toList(),
    };

_ReviewIssue _$ReviewIssueFromJson(Map<String, dynamic> json) => _ReviewIssue(
  destination: $enumDecode(_$DestinationEnumMap, json['destination']),
  code: json['code'] as String,
  message: json['message'] as String,
  blocking: json['blocking'] as bool,
);

Map<String, dynamic> _$ReviewIssueToJson(_ReviewIssue instance) =>
    <String, dynamic>{
      'destination': _$DestinationEnumMap[instance.destination]!,
      'code': instance.code,
      'message': instance.message,
      'blocking': instance.blocking,
    };
