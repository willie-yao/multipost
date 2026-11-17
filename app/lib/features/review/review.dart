import 'package:freezed_annotation/freezed_annotation.dart';

import '../accounts/account.dart';
import '../drafts/draft.dart';

part 'review.freezed.dart';
part 'review.g.dart';

@freezed
@JsonSerializable()
class ResolvedPost with _$ResolvedPost {
  ResolvedPost({
    required this.destination,
    required this.content,
    required this.ownCaption,
    required List<MediaAsset> assets,
    this.account,
  }) : assets = List<MediaAsset>.unmodifiable(assets);

  final Destination destination;
  final PostContent content;
  final bool ownCaption;
  final List<MediaAsset> assets;
  final AccountIdentity? account;

  factory ResolvedPost.fromJson(Map<String, dynamic> json) =>
      _$ResolvedPostFromJson(json);
  Map<String, dynamic> toJson() => _$ResolvedPostToJson(this);
}

@freezed
abstract class ReviewIssue with _$ReviewIssue {
  const factory ReviewIssue({
    required Destination destination,
    required String code,
    required String message,
    required bool blocking,
  }) = _ReviewIssue;
  factory ReviewIssue.fromJson(Map<String, dynamic> json) =>
      _$ReviewIssueFromJson(json);
}

@freezed
@JsonSerializable()
class ReviewedPost with _$ReviewedPost {
  ReviewedPost({
    required this.draftId,
    required this.revision,
    required Map<Destination, ResolvedPost> posts,
    required Map<Destination, String> capabilityVersions,
    required this.reviewedAt,
  }) : posts = Map<Destination, ResolvedPost>.unmodifiable(posts),
       capabilityVersions = Map<Destination, String>.unmodifiable(
         capabilityVersions,
       );

  final String draftId;
  final int revision;
  final Map<Destination, ResolvedPost> posts;
  final Map<Destination, String> capabilityVersions;
  final DateTime reviewedAt;

  factory ReviewedPost.fromJson(Map<String, dynamic> json) =>
      _$ReviewedPostFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewedPostToJson(this);
}

@freezed
@JsonSerializable()
class ReviewResult with _$ReviewResult {
  ReviewResult({required this.snapshot, required List<ReviewIssue> issues})
    : issues = List<ReviewIssue>.unmodifiable(issues);

  final ReviewedPost snapshot;
  final List<ReviewIssue> issues;
  bool get canProceed =>
      snapshot.posts.isNotEmpty && !issues.any((issue) => issue.blocking);

  factory ReviewResult.fromJson(Map<String, dynamic> json) =>
      _$ReviewResultFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewResultToJson(this);
}
