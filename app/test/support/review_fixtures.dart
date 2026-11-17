import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ReviewAccounts implements AccountRepository {
  @override
  Future<AccountView> get(Destination destination) async =>
      (await list()).firstWhere((a) => a.destination == destination);
  @override
  Future<void> save(AccountView account) async => throw UnimplementedError();
  @override
  Future<void> setState(Destination destination, AccountState state) async =>
      throw UnimplementedError();
  bool fail = false;
  bool expired = false;
  String subject = 'person';
  @override
  Future<List<AccountView>> list() async {
    if (fail) throw StateError('unavailable');
    return [
      for (final d in [Destination.x, Destination.bluesky])
        AccountView(
          destination: d,
          state: expired ? AccountState.expired : AccountState.connected,
          capability: 'test verified',
          identity: AccountIdentity(
            destination: d,
            subject: subject,
            handle: '@person',
          ),
        ),
    ];
  }

  @override
  Future<bool> instagramAssistedSharing() async => true;
  @override
  Future<void> setInstagramAssistedSharing(bool enabled) async {}
}

class TestValidators implements ValidatorRegistry, DestinationValidator {
  TestValidators({this.throwsOnValidate = false});
  final bool throwsOnValidate;
  bool block = false;
  String versionValue = 'verified-1';
  @override
  String get version => versionValue;
  @override
  DestinationValidator forDestination(Destination destination) => this;
  @override
  List<ReviewIssue> validate(ResolvedPost post) {
    if (throwsOnValidate) throw StateError('requirements unavailable');
    return block
        ? [
            ReviewIssue(
              destination: post.destination,
              code: 'test-policy',
              message: 'Current verified policy blocks this content',
              blocking: true,
            ),
          ]
        : [];
  }
}

Future<MediaAsset> photo(
  Directory root,
  Future<MediaAsset> Function(XFile) importFile,
  String name,
) async {
  await root.create(recursive: true);
  final file = File('${root.parent.path}/$name.png');
  await file.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
  return importFile(XFile(file.path));
}

Future<MediaAsset> syntheticVideo(
  Directory root,
  Future<int> Function(String, Map<String, Object?>) insert,
) async {
  // File-boundary fixture: native video probing is covered by L3, not host Review.
  final file = File('${root.path}/assets/video');
  await file.parent.create(recursive: true);
  final bytes = [0, 0, 0, 20, 102, 116, 121, 112];
  await file.writeAsBytes(bytes);
  final asset = MediaAsset(
    id: 'video',
    relativePath: 'assets/video',
    mimeType: 'video/mp4',
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    width: 640,
    height: 480,
    durationMs: 1000,
  );
  await insert('assets', {
    'id': asset.id,
    'payload': jsonEncode(asset.toJson()),
  });
  return asset;
}
