import 'dart:convert';

import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/draft_fixtures.dart';

void main() {
  test('own caption survives shared edits; its media still inherits', () {
    var d = sampleDraft();
    d = editOwnCaption(
      d,
      Destination.bluesky,
      'My own words',
      DateTime.utc(2026),
    );
    d = editSharedCaption(d, 'Changed shared words', DateTime.utc(2026, 1, 2));
    d = editSharedMedia(d, const [
      Attachment(assetId: 'photo-2'),
    ], DateTime.utc(2026, 1, 3));
    expect(resolveContent(d, Destination.bluesky).text, 'My own words');
    expect(
      resolveContent(d, Destination.bluesky).media.single.assetId,
      'photo-2',
    );
    expect(resolveContent(d, Destination.x).text, 'Changed shared words');
    d = setDestination(d, Destination.bluesky, false, DateTime.utc(2026, 1, 4));
    d = setDestination(d, Destination.bluesky, true, DateTime.utc(2026, 1, 5));
    expect(resolveContent(d, Destination.bluesky).text, 'My own words');
    expect(Draft.fromJson(d.toJson()), d);
  });

  test('own media survives shared edits while its caption inherits', () {
    var d = sampleDraft();
    final now = DateTime.utc(2026, 11, 17);
    d = editOwnMedia(d, Destination.instagram, const [
      Attachment(assetId: 'own-photo', altText: 'Poppies'),
    ], now);
    d = editSharedCaption(d, 'New shared caption', now);
    d = editSharedMedia(d, const [Attachment(assetId: 'shared-photo')], now);
    expect(resolveContent(d, Destination.instagram).text, 'New shared caption');
    expect(resolveContent(d, Destination.instagram).media, const [
      Attachment(assetId: 'own-photo', altText: 'Poppies'),
    ]);
    expect(resolveContent(d, Destination.x).media, const [
      Attachment(assetId: 'shared-photo'),
    ]);
  });

  test('empty overrides survive codecs and differ from inheritance', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = editSharedMedia(sampleDraft(), const [
      Attachment(assetId: 'shared-photo'),
    ], now);
    d = editOwnCaption(d, Destination.x, '', now);
    d = editOwnMedia(d, Destination.x, const [], now);
    final restored = Draft.fromJson(jsonDecode(jsonEncode(d.toJson())));
    expect(restored, d);
    expect(resolveContent(restored, Destination.x), PostContent());
    expect(restored.versions[Destination.x]!.ownText, '');
    expect(restored.versions[Destination.x]!.ownMedia, isEmpty);
    expect(
      resolveContent(restored, Destination.bluesky).text,
      'A little color from today’s walk.',
    );
    expect(
      resolveContent(restored, Destination.bluesky).media.single.assetId,
      'shared-photo',
    );
  });

  test('restoring shared caption keeps own media and its baseline', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = sampleDraft().copyWith(
      sharedTextRevision: 3,
      sharedMediaRevision: 5,
    );
    d = editOwnCaption(d, Destination.x, 'Own caption', now);
    d = editOwnMedia(d, Destination.x, const [Attachment(assetId: 'own')], now);
    d = restoreSharedCaption(d, Destination.x, now);
    final version = d.versions[Destination.x]!;
    expect(version.ownText, isNull);
    expect(version.baseTextRevision, isNull);
    expect(version.ownMedia, const [Attachment(assetId: 'own')]);
    expect(version.baseMediaRevision, 5);
    expect(
      resolveContent(d, Destination.x).text,
      'A little color from today’s walk.',
    );
  });

  test('restoring shared media keeps own caption and its baseline', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = sampleDraft().copyWith(
      sharedTextRevision: 3,
      sharedMediaRevision: 5,
    );
    d = editSharedMedia(d, const [Attachment(assetId: 'shared')], now);
    d = editOwnCaption(d, Destination.x, 'Own caption', now);
    d = editOwnMedia(d, Destination.x, const [], now);
    d = restoreSharedMedia(d, Destination.x, now);
    final version = d.versions[Destination.x]!;
    expect(version.ownMedia, isNull);
    expect(version.baseMediaRevision, isNull);
    expect(version.ownText, 'Own caption');
    expect(version.baseTextRevision, 3);
    expect(resolveContent(d, Destination.x).media.single.assetId, 'shared');
  });

  test('selection changes retain versions and other destinations', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = sampleDraft();
    d = editOwnCaption(d, Destination.bluesky, 'Saved own words', now);
    d = editOwnMedia(d, Destination.bluesky, const [], now);
    final versions = d.versions;
    d = setDestination(d, Destination.bluesky, false, now);
    expect(d.selected, {Destination.x, Destination.instagram});
    expect(d.versions, versions);
    d = Draft.fromJson(jsonDecode(jsonEncode(d.toJson())));
    d = setDestination(d, Destination.bluesky, true, now);
    expect(d.selected, Destination.values.toSet());
    expect(d.versions, versions);
    expect(
      resolveContent(d, Destination.bluesky),
      PostContent(text: 'Saved own words'),
    );
  });

  test('text warning compares only the caption baseline', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = editOwnCaption(sampleDraft(), Destination.x, 'Own words', now);
    var v = d.versions[Destination.x]!;
    expect(
      v.ownText != null && v.baseTextRevision != d.sharedTextRevision,
      isFalse,
    );
    d = editSharedMedia(d, const [Attachment(assetId: 'new-photo')], now);
    v = d.versions[Destination.x]!;
    expect(
      v.ownText != null && v.baseTextRevision != d.sharedTextRevision,
      isFalse,
    );
    d = editSharedCaption(d, 'New shared words', now);
    v = d.versions[Destination.x]!;
    expect(v.baseTextRevision, 0);
    expect(d.sharedTextRevision, 1);
    expect(
      v.ownText != null && v.baseTextRevision != d.sharedTextRevision,
      isTrue,
    );
    d = editOwnCaption(d, Destination.x, 'Revised own words', now);
    v = d.versions[Destination.x]!;
    expect(v.baseTextRevision, 1);
    expect(
      v.ownText != null && v.baseTextRevision != d.sharedTextRevision,
      isFalse,
    );
    d = restoreSharedCaption(d, Destination.x, now);
    d = editSharedCaption(d, 'Another change', now);
    v = d.versions[Destination.x]!;
    expect(
      v.ownText != null && v.baseTextRevision != d.sharedTextRevision,
      isFalse,
    );
  });

  test('shared media revision changes only when shared media differs', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = editSharedMedia(sampleDraft(), const [
      Attachment(assetId: 'photo', altText: 'Before'),
    ], now);
    expect(d.sharedMediaRevision, 1);
    d = editOwnMedia(d, Destination.x, const [], now);
    d = restoreSharedMedia(d, Destination.x, now);
    d = editSharedCaption(d, 'Changed caption', now);
    expect(d.sharedMediaRevision, 1);
    d = editSharedMedia(d, [
      const Attachment(assetId: 'photo', altText: 'Before'),
    ], now);
    expect(d.sharedMediaRevision, 1);
    expect(d.revision, 5);
    d = editSharedMedia(d, const [
      Attachment(assetId: 'photo', altText: 'After'),
    ], now);
    expect(d.sharedMediaRevision, 2);
    expect(d.sharedTextRevision, 1);
  });

  test('undo restores only the saved platform version after shared edits', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = editOwnCaption(
      sampleDraft(),
      Destination.x,
      'Prior own words',
      now,
    );
    d = editOwnMedia(d, Destination.x, const [], now);
    final savedVersion = d.versions[Destination.x]!;
    d = restoreSharedCaption(d, Destination.x, now);
    d = editOwnMedia(d, Destination.x, const [
      Attachment(assetId: 'new-own'),
    ], now);
    d = editSharedCaption(d, 'Latest shared words', now);
    d = editSharedMedia(d, const [Attachment(assetId: 'latest-shared')], now);
    d = editOwnCaption(d, Destination.bluesky, 'Other platform', now);
    d = setDestination(d, Destination.instagram, false, now);
    d = setStage(d, ComposeStage.review, now);
    final beforeUndo = d;
    final undoTime = DateTime.utc(2026, 11, 18);
    d = restoreVersion(d, Destination.x, savedVersion, undoTime);
    expect(d.versions[Destination.x], savedVersion);
    expect(
      d.versions[Destination.bluesky],
      beforeUndo.versions[Destination.bluesky],
    );
    expect(d.shared.text, 'Latest shared words');
    expect(d.shared.media.single.assetId, 'latest-shared');
    expect(d.sharedTextRevision, 1);
    expect(d.sharedMediaRevision, 1);
    expect(d.selected, {Destination.x, Destination.bluesky});
    expect(d.stage, ComposeStage.review);
    expect(d.revision, beforeUndo.revision + 1);
    expect(d.updatedAt, undoTime);
  });

  test('undo can return a newly customized destination to inheritance', () {
    final now = DateTime.utc(2026, 11, 17);
    var d = editOwnCaption(
      sampleDraft(),
      Destination.x,
      'Temporary own words',
      now,
    );
    d = editSharedCaption(d, 'Shared change made afterward', now);
    d = restoreVersion(d, Destination.x, DestinationVersion(), now);
    expect(
      resolveContent(d, Destination.x).text,
      'Shared change made afterward',
    );
    expect(d.versions[Destination.x]!.baseTextRevision, isNull);
  });

  test('stage edits retain content, selection, and versions', () {
    final now = DateTime.utc(2026, 11, 17);
    final original = editOwnCaption(
      sampleDraft(),
      Destination.x,
      'Own words',
      now,
    );
    final changed = setStage(original, ComposeStage.write, now);
    expect(changed.stage, ComposeStage.write);
    expect(changed.shared, original.shared);
    expect(changed.selected, original.selected);
    expect(changed.versions, original.versions);
    expect(original.stage, ComposeStage.choose);
  });

  test('every editor produces a fresh revision without mutating its input', () {
    final original = sampleDraft().copyWith(
      revision: 12,
      sharedTextRevision: 4,
      sharedMediaRevision: 7,
      deletedAt: DateTime.utc(2026, 11, 20),
      versions: {Destination.instagram: DestinationVersion(ownText: 'Keep me')},
    );
    final before = jsonEncode(original.toJson());
    final now = DateTime.utc(2026, 11, 17);
    final edits = <Draft Function(Draft)>[
      (d) => editSharedCaption(d, 'New shared', now),
      (d) => editOwnCaption(d, Destination.x, 'New own', now),
      (d) => restoreSharedCaption(d, Destination.x, now),
      (d) => editSharedMedia(d, const [Attachment(assetId: 'shared')], now),
      (d) => editOwnMedia(d, Destination.x, const [
        Attachment(assetId: 'own'),
      ], now),
      (d) => restoreSharedMedia(d, Destination.x, now),
      (d) => setDestination(d, Destination.x, false, now),
      (d) => setDestination(d, Destination.x, true, now),
      (d) => setStage(d, ComposeStage.review, now),
      (d) => restoreVersion(d, Destination.x, DestinationVersion(), now),
    ];
    for (final edit in edits) {
      final changed = edit(original);
      expect(identical(changed, original), isFalse);
      expect(changed.revision, 13);
      expect(changed.updatedAt, now);
      expect(changed.id, 'draft-1');
      expect(changed.deletedAt, DateTime.utc(2026, 11, 20));
      expect(changed.versions[Destination.instagram]!.ownText, 'Keep me');
      expect(jsonEncode(original.toJson()), before);
    }
  });

  test('media edits snapshot the supplied attachment list', () {
    final now = DateTime.utc(2026, 11, 17);
    final media = [const Attachment(assetId: 'photo')];
    final shared = editSharedMedia(sampleDraft(), media, now);
    final own = editOwnMedia(sampleDraft(), Destination.x, media, now);
    media.clear();
    expect(shared.shared.media.single.assetId, 'photo');
    expect(own.versions[Destination.x]!.ownMedia!.single.assetId, 'photo');
    expect(() => shared.shared.media.clear(), throwsUnsupportedError);
    expect(
      () => own.versions[Destination.x]!.ownMedia!.clear(),
      throwsUnsupportedError,
    );
  });

  test('draft codecs emit nested maps and retain all fields immutably', () {
    final d = Draft(
      id: 'encoded-draft',
      updatedAt: DateTime.utc(2026, 11, 16, 12, 30),
      revision: 8,
      sharedTextRevision: 3,
      sharedMediaRevision: 2,
      stage: ComposeStage.review,
      selected: const {Destination.x, Destination.instagram},
      shared: PostContent(
        text: 'Shared',
        media: const [Attachment(assetId: 'photo', altText: 'A poppy')],
      ),
      versions: {
        Destination.x: DestinationVersion(
          ownText: '',
          ownMedia: [],
          baseTextRevision: 1,
          baseMediaRevision: 2,
        ),
        Destination.bluesky: DestinationVersion(),
      },
      deletedAt: DateTime.utc(2026, 11, 18),
    );
    final json = d.toJson();
    final sharedJson = json['shared'] as Map<String, dynamic>;
    expect(sharedJson['text'], 'Shared');
    expect((sharedJson['media'] as List).single, {
      'assetId': 'photo',
      'altText': 'A poppy',
    });
    final versionsJson = json['versions'] as Map<String, dynamic>;
    expect(versionsJson['x'], {
      'ownText': '',
      'ownMedia': [],
      'baseTextRevision': 1,
      'baseMediaRevision': 2,
    });
    expect(versionsJson['bluesky'], {
      'ownText': null,
      'ownMedia': null,
      'baseTextRevision': null,
      'baseMediaRevision': null,
    });
    final decoded = Draft.fromJson(jsonDecode(jsonEncode(json)));
    expect(decoded, d);
    expect(() => decoded.selected.clear(), throwsUnsupportedError);
    expect(() => decoded.versions.clear(), throwsUnsupportedError);
    expect(() => decoded.shared.media.clear(), throwsUnsupportedError);
    expect(
      () => decoded.versions[Destination.x]!.ownMedia!.clear(),
      throwsUnsupportedError,
    );
  });

  test('media asset codecs preserve source and duration metadata', () {
    const asset = MediaAsset(
      id: 'asset-1',
      relativePath: 'media/asset-1.jpg',
      mimeType: 'image/jpeg',
      bytes: 42,
      sha256: 'digest',
      width: 1200,
      height: 800,
      durationMs: 1500,
      originalAssetId: 'original-1',
    );
    expect(MediaAsset.fromJson(jsonDecode(jsonEncode(asset.toJson()))), asset);
    final still = asset.copyWith(durationMs: null, originalAssetId: null);
    final decoded = MediaAsset.fromJson(still.toJson());
    expect(decoded.durationMs, isNull);
    expect(decoded.originalAssetId, isNull);
  });

  test('clock returns the current instant expressed in UTC', () {
    final before = DateTime.now().toUtc();
    final actual = const Clock().now();
    final after = DateTime.now().toUtc();
    expect(actual.isUtc, isTrue);
    expect(actual.isBefore(before), isFalse);
    expect(actual.isAfter(after), isFalse);
  });

  test('ids produce distinct UUID v4 identifiers', () {
    const ids = Ids();
    final first = ids.next();
    final second = ids.next();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(first, matches(uuidV4));
    expect(second, matches(uuidV4));
    expect(second, isNot(first));
  });

  test('PostContent constructor owns its media list', () {
    final media = [const Attachment(assetId: 'original')];
    final content = PostContent(text: 'Words', media: media);
    media.clear();
    expect(content.media, const [Attachment(assetId: 'original')]);
    expect(() => content.media.clear(), throwsUnsupportedError);
  });

  test('PostContent copyWith owns its replacement media list', () {
    final original = PostContent(text: 'Words');
    final media = [const Attachment(assetId: 'replacement')];
    final copied = original.copyWith(media: media);
    media.clear();
    expect(copied.media, const [Attachment(assetId: 'replacement')]);
    expect(copied.text, 'Words');
    expect(original.media, isEmpty);
    expect(() => copied.media.clear(), throwsUnsupportedError);
  });

  test('DestinationVersion constructor owns its ownMedia list', () {
    final media = [const Attachment(assetId: 'original')];
    final version = DestinationVersion(ownMedia: media);
    media.clear();
    expect(version.ownMedia, const [Attachment(assetId: 'original')]);
    expect(() => version.ownMedia!.clear(), throwsUnsupportedError);
  });

  test('DestinationVersion copyWith owns its replacement ownMedia list', () {
    final original = DestinationVersion(ownText: 'Own words');
    final media = [const Attachment(assetId: 'replacement')];
    final copied = original.copyWith(ownMedia: media);
    media.clear();
    expect(copied.ownMedia, const [Attachment(assetId: 'replacement')]);
    expect(copied.ownText, 'Own words');
    expect(original.ownMedia, isNull);
    expect(() => copied.ownMedia!.clear(), throwsUnsupportedError);
  });

  test('Draft constructor owns its selected set', () {
    final selected = {Destination.x};
    final draft = Draft(
      id: 'owned-selection',
      updatedAt: DateTime.utc(2026),
      selected: selected,
    );
    selected.clear();
    expect(draft.selected, {Destination.x});
    expect(() => draft.selected.clear(), throwsUnsupportedError);
  });

  test('Draft copyWith owns its replacement selected set', () {
    final original = sampleDraft();
    final selected = {Destination.x};
    final copied = original.copyWith(selected: selected);
    selected.clear();
    expect(copied.selected, {Destination.x});
    expect(original.selected, Destination.values.toSet());
    expect(() => copied.selected.clear(), throwsUnsupportedError);
  });

  test('Draft constructor owns its versions map', () {
    final version = DestinationVersion(ownText: 'Own words');
    final versions = {Destination.x: version};
    final draft = Draft(
      id: 'owned-versions',
      updatedAt: DateTime.utc(2026),
      versions: versions,
    );
    versions.clear();
    expect(draft.versions[Destination.x]?.ownText, 'Own words');
    expect(() => draft.versions.clear(), throwsUnsupportedError);
  });

  test('Draft copyWith owns its replacement versions map', () {
    final original = sampleDraft();
    final versions = {Destination.x: DestinationVersion(ownText: 'Own words')};
    final copied = original.copyWith(versions: versions);
    versions.clear();
    expect(copied.versions[Destination.x]?.ownText, 'Own words');
    expect(original.versions, isEmpty);
    expect(() => copied.versions.clear(), throwsUnsupportedError);
  });

  test('restored version cannot change through caller-owned media', () {
    final media = [const Attachment(assetId: 'saved-own-photo')];
    final version = DestinationVersion(ownMedia: media, baseMediaRevision: 0);
    final original = sampleDraft();
    final now = DateTime.utc(2026, 11, 17);
    final restored = restoreVersion(original, Destination.x, version, now);
    final encoded = jsonEncode(restored.toJson());
    media.clear();
    expect(resolveContent(restored, Destination.x).media, const [
      Attachment(assetId: 'saved-own-photo'),
    ]);
    expect(jsonEncode(restored.toJson()), encoded);
    expect(restored.revision, 1);
    expect(restored.updatedAt, now);
    expect(original.revision, 0);
  });

  test('minimal draft JSON retains model defaults', () {
    final draft = Draft.fromJson({
      'id': 'minimal',
      'updatedAt': '2026-11-16T00:00:00.000Z',
    });
    expect(draft.stage, ComposeStage.choose);
    expect(draft.revision, 0);
    expect(draft.sharedTextRevision, 0);
    expect(draft.sharedMediaRevision, 0);
    expect(draft.shared.text, '');
    expect(draft.shared.media, isEmpty);
    expect(draft.selected, isEmpty);
    expect(draft.versions, isEmpty);
    expect(draft.deletedAt, isNull);
  });
}
