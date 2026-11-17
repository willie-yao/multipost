import 'dart:io';

import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/instagram/instagram_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_android_transfer.dart';
import '../../support/instagram_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('opening Instagram is an activity, not a handoff', () async {
    final transfer = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: transfer);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    expect(await s.instagram.open(p.id), LaunchResult.opened);
    expect((await s.instagramRepo.progress(p.id)).state, InstagramState.ready);
    final event = (await s.instagramRepo.events(p.id)).single;
    expect(event.kind, InstagramEventKind.opened);
    expect(event.launchId, isNotEmpty);
    expect(event.targetPackage, isNull);
  });

  test('unavailable and failed launch record no successful activity', () async {
    final transfer = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: transfer);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    for (final outcome in [LaunchResult.unavailable, LaunchResult.failed]) {
      transfer.launchResult = outcome;
      expect(await s.instagram.open(p.id), outcome);
    }
    expect(await s.instagramRepo.events(p.id), isEmpty);
    expect((await s.instagramRepo.progress(p.id)).state, InstagramState.ready);
  });

  test('default capability never sends a prepared carousel', () async {
    final transfer = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: transfer);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    expect(await s.instagram.share(p.id), ShareDispatch.unavailable);
    expect(transfer.sharedPackages, isEmpty);
    expect(await s.instagramRepo.events(p.id), isEmpty);
  });
  final evidence = InstagramShareCapability(
    singlePhoto: true,
    carousel: true,
    checkedAt: DateTime.utc(2026, 11, 16),
    device: 'synthetic host fixture',
    instagramVersion: 'fixture only',
  );
  for (final outcome in ShareDispatch.values) {
    test(
      '$outcome records only justified activity and survives reconstruction',
      () async {
        final transfer = FakeAndroidTransfer()..shareResult = outcome;
        final s = await instagramTestServices(
          transfer: transfer,
          shareCapability: evidence,
        );
        addTearDown(s.close);
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        );
        expect(await s.instagram.share(p.id), outcome);
        final events = await s.instagramRepo.events(p.id);
        final dispatched = outcome == ShareDispatch.dispatchedToInstagram;
        final chooser = outcome == ShareDispatch.chooserOpened;
        expect(events.length, dispatched || chooser ? 1 : 0);
        if (events.isNotEmpty) {
          expect(
            events.single.kind,
            dispatched
                ? InstagramEventKind.targetDispatched
                : InstagramEventKind.chooserOpened,
          );
          expect(
            events.single.targetPackage,
            dispatched ? 'com.instagram.android' : null,
          );
        }
        final reconstructed = InstagramService(
          s.instagramRepo,
          s.app.media,
          s.app.instagramPackageRoot,
          s.policy,
          s.app.ids,
          s.app.clock,
          transfer: transfer,
        );
        // A new service/startup does not send anything or change durable progress.
        expect(
          (await reconstructed.repository.progress(p.id)).state,
          dispatched ? InstagramState.handedOff : InstagramState.ready,
        );
        expect(transfer.sharedPackages.length, 1);
        expect((await reconstructed.repository.get(p.id))!.caption, 'Caption');
        expect((await reconstructed.repository.get(p.id))!.photos.length, 2);
      },
    );
  }
  test(
    'an app launch preserves pending dispatch and uses a new launch id',
    () async {
      final transfer = FakeAndroidTransfer();
      final s = await instagramTestServices(
        transfer: transfer,
        shareCapability: evidence,
      );
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'p',
      );
      await s.instagram.share(p.id);
      await s.instagram.open(p.id);
      final events = await s.instagramRepo.events(p.id);
      expect(events[0].launchId, isNot(events[1].launchId));
      expect(
        (await s.instagramRepo.progress(p.id)).state,
        InstagramState.handedOff,
      );
    },
  );
  test('a targeted event without Instagram identity is rejected', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    for (final target in [null, 'other.app']) {
      await expectLater(
        s.instagramRepo.append(
          p.id,
          InstagramEvent(
            id: 'bad-$target',
            kind: InstagramEventKind.targetDispatched,
            at: DateTime.utc(2026),
            launchId: 'l',
            targetPackage: target,
          ),
        ),
        throwsA(isA<LocalStorageException>()),
      );
    }
    expect(await s.instagramRepo.events(p.id), isEmpty);
  });
  test('incomplete receiving-app evidence never enables a path', () async {
    for (final capability in [
      const InstagramShareCapability(singlePhoto: true, carousel: true),
      InstagramShareCapability(
        carousel: true,
        checkedAt: DateTime.utc(2026),
        device: 'fixture',
      ),
    ]) {
      final transfer = FakeAndroidTransfer();
      final s = await instagramTestServices(
        transfer: transfer,
        shareCapability: capability,
      );
      try {
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        );
        expect(await s.instagram.share(p.id), ShareDispatch.unavailable);
        expect(transfer.sharedPackages, isEmpty);
      } finally {
        await s.close();
      }
    }
  });
  test(
    'a missing prepared photo prevents the entire carousel handoff',
    () async {
      final transfer = FakeAndroidTransfer();
      final s = await instagramTestServices(
        transfer: transfer,
        shareCapability: evidence,
      );
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'p',
      );
      await (await s.instagram.fileFor(p, p.photos[1])).delete();
      await expectLater(
        s.instagram.share(p.id),
        throwsA(isA<InstagramPreparationException>()),
      );
      expect(transfer.sharedPackages, isEmpty);
      expect(await s.instagramRepo.events(p.id), isEmpty);
    },
  );
  test(
    'launch activity and frozen files survive a database close and reopen',
    () async {
      final transfer = FakeAndroidTransfer();
      final s = await instagramTestServices(transfer: transfer);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Frozen caption'),
        operationId: 'p',
      );
      await s.instagram.open(p.id);
      final path = s.app.database.db.path;
      await s.app.database.close();
      final reopened = await LocalDatabase.open(
        databaseFactoryFfiNoIsolate,
        path,
      );
      addTearDown(reopened.close);
      final repo = InstagramRepository(reopened);
      expect((await repo.progress(p.id)).state, InstagramState.ready);
      expect((await repo.events(p.id)).single.kind, InstagramEventKind.opened);
      expect((await repo.get(p.id))!.caption, 'Frozen caption');
      expect(
        await File(
          '${s.app.instagramPackageRoot.path}/${p.photos[1].relativePath}',
        ).exists(),
        isTrue,
      );
      expect(transfer.openCalls, 1);
      expect(transfer.sharedPackages, isEmpty);
    },
  );
}
