import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_android_transfer.dart';
import '../../support/instagram_fixture.dart';

void main() {
  test(
    'only missing photo exports are retried and journal precedes native',
    () async {
      final fake = FakeAndroidTransfer(failOrdinals: {2});
      final s = await instagramTestServices(transfer: fake);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'p',
      );
      fake.beforeSave = (jobs) async {
        expect(
          (await s.instagramRepo.exportJobs(p.id))
              .where((j) => jobs.any((wanted) => wanted.id == j.id))
              .map((j) => j.id),
          jobs.map((j) => j.id),
        );
      };
      await s.instagram.saveMissingPhotos(p.id);
      expect((await s.instagramRepo.progress(p.id)).savedUris.keys, [1]);
      fake.failOrdinals.clear();
      await s.instagram.saveMissingPhotos(p.id);
      expect(fake.savedBatches, [
        {1, 2},
        {2},
      ]);
      expect((await s.instagramRepo.progress(p.id)).savedUris.length, 2);
    },
  );

  test(
    'OS success before receipt commit recovers without another write',
    () async {
      final fake = FakeAndroidTransfer();
      final s = await instagramTestServices(transfer: fake);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'gap',
      );
      await s.app.database.db.execute(
        "CREATE TRIGGER fail_receipt BEFORE UPDATE ON export_jobs WHEN NEW.completed = 1 BEGIN SELECT RAISE(FAIL, 'injected receipt failure'); END",
      );
      await expectLater(s.instagram.saveMissingPhotos(p.id), throwsException);
      expect(fake.receipts, hasLength(2));
      expect((await s.instagramRepo.progress(p.id)).savedUris, isEmpty);
      await s.app.database.db.execute('DROP TRIGGER fail_receipt');
      await s.instagram.saveMissingPhotos(p.id);
      expect(fake.savedBatches, [
        {1, 2},
      ]);
      expect((await s.instagramRepo.progress(p.id)).savedUris.length, 2);
    },
  );

  test(
    'resume removes deleted receipt from count without automatically exporting',
    () async {
      final fake = FakeAndroidTransfer();
      final s = await instagramTestServices(transfer: fake);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'deleted',
      );
      await s.instagram.saveMissingPhotos(p.id);
      final jobs = await s.instagramRepo.exportJobs(p.id);
      fake.receipts.remove(jobs.first.id);
      expect((await s.instagram.recheckSavedPhotos(p.id)).savedUris.keys, [2]);
      expect(fake.savedBatches, hasLength(1));
      await s.instagram.saveMissingPhotos(p.id);
      expect(fake.savedBatches, [
        {1, 2},
        {1},
      ]);
    },
  );

  test(
    'caption activity only records successful writes of frozen text',
    () async {
      final fake = FakeAndroidTransfer()
        ..copyFailure = Exception('clipboard unavailable');
      final s = await instagramTestServices(transfer: fake);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Frozen caption'),
        operationId: 'copy',
      );
      await expectLater(s.instagram.copyCaption(p.id), throwsException);
      expect(await s.app.database.db.query('instagram_events'), isEmpty);
      fake.copyFailure = null;
      await s.instagram.copyCaption(p.id);
      expect(fake.copied, 'Frozen caption');
      expect(
        (await s.app.database.db.query('instagram_events')).single['kind'],
        InstagramEventKind.captionCopied.name,
      );
    },
  );

  test(
    'journal failure prevents native write and concurrent taps coalesce',
    () async {
      final fake = FakeAndroidTransfer();
      final s = await instagramTestServices(transfer: fake);
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'journal',
      );
      await s.app.database.db.execute(
        "CREATE TRIGGER fail_job BEFORE INSERT ON export_jobs BEGIN SELECT RAISE(FAIL, 'injected journal failure'); END",
      );
      await expectLater(s.instagram.saveMissingPhotos(p.id), throwsException);
      expect(fake.savedBatches, isEmpty);
      await s.app.database.db.execute('DROP TRIGGER fail_job');
      await Future.wait([
        s.instagram.saveMissingPhotos(p.id),
        s.instagram.saveMissingPhotos(p.id),
      ]);
      expect(fake.savedBatches, [
        {1, 2},
      ]);
    },
  );
  test('stale unavailable receipt cannot clear a newer receipt', () async {
    final fake = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: fake);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'stale-receipt',
    );
    await s.instagram.saveMissingPhotos(p.id);
    final old = (await s.instagramRepo.exportJobs(p.id)).first;
    await s.instagramRepo.recordExportResult(
      old,
      'content://caption-test/newer',
      InstagramEvent(
        id: s.app.ids.next(),
        kind: InstagramEventKind.photoSaved,
        at: s.app.clock.now(),
        photoOrdinal: old.ordinal,
        uri: 'content://caption-test/newer',
      ),
    );
    await s.instagramRepo.recordExportResult(
      old,
      null,
      InstagramEvent(
        id: s.app.ids.next(),
        kind: InstagramEventKind.photoUnavailable,
        at: s.app.clock.now(),
        photoOrdinal: old.ordinal,
        uri: old.uri,
      ),
    );
    expect(
      (await s.instagramRepo.progress(p.id)).savedUris[old.ordinal],
      'content://caption-test/newer',
    );
  });

  test('damaged frozen media never reaches native save', () async {
    final fake = FakeAndroidTransfer();
    final s = await instagramTestServices(transfer: fake);
    addTearDown(s.close);
    final p = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'damaged-export',
    );
    final file = await s.instagram.fileFor(p, p.photos.first);
    await file.writeAsBytes([1, 2, 3], flush: true);
    await expectLater(s.instagram.saveMissingPhotos(p.id), throwsException);
    expect(fake.savedBatches, isEmpty);
    expect(await s.instagramRepo.exportJobs(p.id), isEmpty);
  });
  test(
    'stale missing result cannot clear newer receipt restored at same URI',
    () async {
      final s = await instagramTestServices(transfer: FakeAndroidTransfer());
      addTearDown(s.close);
      final p = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'same-uri-stale',
      );
      await s.instagram.saveMissingPhotos(p.id);
      final old = (await s.instagramRepo.exportJobs(p.id)).first;
      await s.instagramRepo.recordExportResult(
        old,
        null,
        InstagramEvent(
          id: s.app.ids.next(),
          kind: InstagramEventKind.photoUnavailable,
          at: s.app.clock.now(),
          photoOrdinal: old.ordinal,
          uri: old.uri,
        ),
      );
      final missing = (await s.instagramRepo.exportJobs(p.id)).first;
      await s.instagramRepo.recordExportResult(
        missing,
        old.uri,
        InstagramEvent(
          id: s.app.ids.next(),
          kind: InstagramEventKind.photoSaved,
          at: s.app.clock.now(),
          photoOrdinal: old.ordinal,
          uri: old.uri,
        ),
      );
      await s.instagramRepo.recordExportResult(
        old,
        null,
        InstagramEvent(
          id: s.app.ids.next(),
          kind: InstagramEventKind.photoUnavailable,
          at: s.app.clock.now(),
          photoOrdinal: old.ordinal,
          uri: old.uri,
        ),
      );
      expect(
        (await s.instagramRepo.progress(p.id)).savedUris[old.ordinal],
        old.uri,
      );
    },
  );
}
