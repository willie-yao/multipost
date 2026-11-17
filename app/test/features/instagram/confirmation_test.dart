import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_repository.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fake_android_transfer.dart';
import '../../support/instagram_fixture.dart';

void main() {
  for (final share in [false, true]) {
    test(
      'pause during local ${share ? 'photo validation' : 'lookup'} cannot qualify a later transfer',
      () async {
        final transfer = FakeAndroidTransfer();
        final s = await instagramTestServices(transfer: transfer);
        addTearDown(s.close);
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        );
        final repository = _BlockingLookup(s.app.database);
        final service = InstagramService(
          repository,
          s.app.media,
          s.app.instagramPackageRoot,
          s.policy,
          s.app.ids,
          s.app.clock,
          transfer: transfer,
          shareCapability: InstagramShareCapability(
            carousel: true,
            checkedAt: DateTime.utc(2026),
            device: 'synthetic',
            instagramVersion: 'fixture only',
          ),
        );
        // A new explicit action must retire even a previous unobserved trip.
        await service.open(p.id);
        repository.blockAfterReads(share ? 2 : 1);
        final operation = share ? service.share(p.id) : service.open(p.id);
        await repository.entered.future;
        service.onExternalPause(p.id);
        repository.release.complete();
        await operation;
        expect(await service.onResume(p.id), isFalse);
        // A departure after actual transfer entry still qualifies normally.
        service.onExternalPause(p.id);
        expect(await service.onResume(p.id), isTrue);
      },
    );
  }
  for (final handedOff in [false, true]) {
    test(
      'manual mark is timestamped, idempotent and Undo restores ${handedOff ? 'handedOff' : 'ready'}',
      () async {
        final s = await instagramTestServices(transfer: FakeAndroidTransfer());
        addTearDown(s.close);
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        );
        if (handedOff) {
          await s.instagramRepo.append(
            p.id,
            InstagramEvent(
              id: 'dispatch',
              kind: InstagramEventKind.targetDispatched,
              at: DateTime.utc(2026),
              launchId: 'trip',
              targetPackage: 'com.instagram.android',
            ),
          );
        }
        await Future.wait([
          s.instagram.markPosted(p.id),
          s.instagram.markPosted(p.id),
        ]);
        final marked = await s.instagramRepo.progress(p.id);
        expect(marked.state, InstagramState.userMarked);
        expect(marked.confirmedAt, isNotNull);
        expect(
          marked.priorPending,
          handedOff ? InstagramState.handedOff : InstagramState.ready,
        );
        expect(
          (await s.instagramRepo.events(p.id))
              .where((e) => e.kind == InstagramEventKind.markedPosted),
          hasLength(1),
        );
        await Future.wait([
          s.instagram.undoMarked(p.id),
          s.instagram.undoMarked(p.id),
        ]);
        final undone = await s.instagramRepo.progress(p.id);
        expect(
          undone.state,
          handedOff ? InstagramState.handedOff : InstagramState.ready,
        );
        expect(undone.confirmedAt, isNull);
        expect(
          (await s.instagramRepo.events(p.id))
              .where((e) => e.kind == InstagramEventKind.markUndone),
          hasLength(1),
        );
        expect(await s.instagram.fileFor(p, p.photos.last), isA<File>());
      },
    );
  }
  test('only an observed successful external trip prompts, acknowledged once across restart', () async {
    final transfer = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: transfer);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    expect(await s.instagram.onResume(p.id), isFalse);
    await s.instagram.open(p.id);
    // Native success without observed departure is insufficient evidence.
    expect(await s.instagram.onResume(p.id), isFalse);
    s.instagram.discardUnobservedTrip(p.id);
    s.instagram.onExternalPause(p.id);
    expect(await s.instagram.onResume(p.id), isFalse);
    await s.instagram.open(p.id);
    s.instagram.onExternalPause(p.id);
    expect(await s.instagram.onResume(p.id), isTrue);
    await Future.wait([
      s.instagram.acknowledgeReturn(p.id),
      s.instagram.acknowledgeReturn(p.id),
    ]);
    expect(await s.instagram.onResume(p.id), isFalse);
    expect(
      (await s.instagramRepo.events(p.id))
          .where((e) => e.kind == InstagramEventKind.returnAcknowledged),
      hasLength(1),
    );
    final path = s.app.database.db.path;
    await s.app.database.close();
    final database = await LocalDatabase.open(
      databaseFactoryFfiNoIsolate,
      path,
    );
    addTearDown(database.close);
    final repo = InstagramRepository(database);
    final restarted = InstagramService(
      repo,
      s.app.media,
      s.app.instagramPackageRoot,
      s.policy,
      s.app.ids,
      s.app.clock,
      transfer: transfer,
    );
    expect(await restarted.onResume(p.id), isFalse);
    await restarted.open(p.id);
    restarted.onExternalPause(p.id);
    expect(await restarted.onResume(p.id), isTrue);
    await restarted.markPosted(p.id);
    expect(await restarted.onResume(p.id), isFalse);
  });
  test('process recreation without proven departure does not infer a trip; marking persists and keeps files after draft deletion', () async {
    final s = await instagramTestServices(transfer: FakeAndroidTransfer());
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Frozen'),
      operationId: 'p',
    );
    await s.instagram.open(p.id);
    final restarted = InstagramService(
      s.instagramRepo,
      s.app.media,
      s.app.instagramPackageRoot,
      s.policy,
      s.app.ids,
      s.app.clock,
      transfer: FakeAndroidTransfer(),
    );
    restarted.onExternalPause(p.id);
    expect(await restarted.onResume(p.id), isFalse);
    await restarted.markPosted(p.id);
    await s.app.drafts.setDeleted(p.draftId, s.app.clock.now());
    await s.app.database.db.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [p.draftId],
    );
    final path = s.app.database.db.path;
    await s.app.database.close();
    final database = await LocalDatabase.open(
      databaseFactoryFfiNoIsolate,
      path,
    );
    addTearDown(database.close);
    final repo = InstagramRepository(database);
    expect(await repo.pending(), isEmpty);
    expect((await repo.marked()).single.id, p.id);
    expect((await repo.progress(p.id)).confirmedAt, isNotNull);
    expect(
      await File(
        '${s.app.instagramPackageRoot.path}/${p.photos.last.relativePath}',
      ).exists(),
      isTrue,
    );
  });
  test('a stale trip cannot acknowledge a later launch, including another service instance', () async {
    final s = await instagramTestServices(transfer: FakeAndroidTransfer());
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'p',
    );
    await s.instagram.open(p.id);
    s.instagram.onExternalPause(p.id);
    final first = (await s.instagramRepo.progress(p.id)).activeLaunchId!;
    final secondService = InstagramService(
      s.instagramRepo,
      s.app.media,
      s.app.instagramPackageRoot,
      s.policy,
      s.app.ids,
      s.app.clock,
      transfer: FakeAndroidTransfer(),
    );
    await secondService.open(p.id);
    final second = (await s.instagramRepo.progress(p.id)).activeLaunchId!;
    expect(first, isNot(second));
    await s.instagram.acknowledgeReturn(p.id);
    await s.instagramRepo.append(
      p.id,
      InstagramEvent(
        id: 'stale-ack',
        kind: InstagramEventKind.returnAcknowledged,
        at: DateTime.utc(2026),
        launchId: first,
      ),
    );
    expect((await s.instagramRepo.progress(p.id)).promptedLaunchId, isNull);
    secondService.onExternalPause(p.id);
    expect(await secondService.onResume(p.id), isTrue);
    await secondService.acknowledgeReturn(p.id);
    expect((await s.instagramRepo.progress(p.id)).promptedLaunchId, second);
  });
}

class _BlockingLookup extends InstagramRepository {
  _BlockingLookup(super.database);
  int _remainingReads = 0;
  final entered = Completer<void>();
  final release = Completer<void>();

  void blockAfterReads(int count) => _remainingReads = count;

  @override
  Future<InstagramPackage?> get(String id) async {
    if (_remainingReads > 0 && --_remainingReads == 0) {
      entered.complete();
      await release.future;
    }
    return super.get(id);
  }
}
