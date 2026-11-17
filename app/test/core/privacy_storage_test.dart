import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/instagram/instagram_repository.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/attempt_repository.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/account_fixture.dart';
import '../support/bluesky_fixture.dart';
import '../support/instagram_fixture.dart';
import '../support/publisher_fixture.dart';

const _private = 'privacy-fixture-private-error-body';

void main() {
  test('failed X auth and refresh never persist credential or error payloads outside the vault', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    final output = <String>[];
    await runZoned(
      () async {
        h.oauth.authorizeError = StateError(_private);
        await expectLater(
          h.x.connect(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        h.oauth.authorizeError = null;
        await h.x.connect();
        expect(h.vault.value, contains('opaque-access-initial'));
        h.clock.value = h.clock.value.add(const Duration(hours: 3));
        h.oauth.refreshError = StateError(_private);
        await expectLater(
          h.x.ensureAuthorized(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        await _inspectTables(h.fixture.database, [
          _private,
          'opaque-access-initial',
          'opaque-refresh-initial',
        ]);
        await h.x.disconnect();
        expect(h.vault.value, isNull);
        expect((await h.drafts.get('draft-1'))!.shared.text, 'Kept draft');
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => output.add(line),
      ),
    );
    _assertAbsent(output.join('\n'), [
      _private,
      'opaque-access-initial',
      'opaque-refresh-initial',
    ], 'host output');
  });

  test('real Bluesky SDK DPoP keys and proofs stay out of ordinary SQLite and host output', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    final output = <String>[];
    final secrets = <String>[
      _private,
      'synthetic-access-0',
      'synthetic-refresh-0',
    ];
    await runZoned(
      () async {
        await h.connect();
        final session =
            (jsonDecode(h.vault.value!) as Map<String, dynamic>)['session']
                as Map<String, dynamic>;
        final privateKey = session['dpop_private_key'] as String;
        expect(privateKey, isNotEmpty);
        secrets.add(privateKey);
        secrets.addAll(
          h.requests
              .map((request) => request.headers['dpop'])
              .whereType<String>(),
        );
        await h.expireStoredSession();
        h.errorPath = '/oauth/token';
        h.requestError = StateError(_private);
        await expectLater(
          h.connection.ensureAuthorized(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        await _inspectTables(h.fixture.database, secrets);
        await h.connection.disconnect();
        expect(h.vault.value, isNull);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => output.add(line),
      ),
    );
    _assertAbsent(output.join('\n'), secrets, 'host output');
  });

  for (final failAt in ['upload', 'create']) {
    test(
      'X $failAt interruption persists only safe outcomes beside drafts and prepared packages',
      () async {
        final h = await xPublisherHarness();
        addTearDown(h.close);
        final output = <String>[];
        const secrets = [
          _private,
          'opaque-access-initial',
          'opaque-refresh-initial',
        ];
        await runZoned(
          () async {
            final database = h.account.fixture.database;
            final clock = h.account.clock;
            final draft = Draft(
              id: 'privacy-$failAt',
              updatedAt: clock.now(),
              selected: {Destination.x, Destination.instagram},
              shared: h.photoPost.content,
            );
            await h.account.drafts.save(draft, expectedRevision: -1);
            final reviewed = ReviewedPost(
              draftId: draft.id,
              revision: draft.revision,
              posts: {
                Destination.x: h.photoPost,
                Destination.instagram: h.photoPost.copyWith(
                  destination: Destination.instagram,
                  account: null,
                ),
              },
              capabilityVersions: {
                Destination.x: h.provider.capabilities.version,
                Destination.instagram: fixtureInstagramPolicy.version,
              },
              reviewedAt: clock.now(),
            );
            final instagram = InstagramService(
              InstagramRepository(database),
              h.account.fixture.files,
              Directory(
                '${h.account.fixture.directory.path}/instagram-packages',
              ),
              fixtureInstagramPolicy,
              const Ids(),
              clock,
            );
            final package = await instagram.prepare(
              reviewed,
              operationId: 'privacy-package',
            );
            final attempts = AttemptRepository(database, clock, const Ids());
            final group = await attempts.begin(reviewed, 'privacy-attempt');
            final attempt = (await attempts.attempts(group.group.id)).single;
            expect(await attempts.claim(attempt.id), isTrue);
            h.beforeResponse = (request) async {
              if (request.url.path ==
                  (failAt == 'upload' ? '/2/media/upload' : '/2/tweets')) {
                throw StateError(_private);
              }
            };
            final outcome = await h.provider.send(
              h.photoPost,
              PublishContext(
                attemptId: attempt.id,
                uploadState: const {},
                markDispatch: () => attempts.markDispatch(attempt.id),
                saveUpload: (key, value) =>
                    attempts.saveUpload(attempt.id, key, value),
              ),
            );
            expect(
              outcome.status,
              failAt == 'upload'
                  ? PublishStatus.notPublished
                  : PublishStatus.unknown,
            );
            _assertAbsent(
              jsonEncode(outcome.toJson()),
              secrets,
              'user-visible outcome',
            );
            await attempts.record(attempt.id, outcome);
            expect((await database.db.query('instagram_packages')).length, 1);
            expect(
              (await database.db.query('attempt_events')).length,
              greaterThan(1),
            );
            await _inspectTables(database, secrets);
            await h.account.x.disconnect();
            expect(h.account.vault.value, isNull);
            expect(await h.account.drafts.get(draft.id), draft);
            expect(await instagram.repository.get(package.id), package);
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => output.add(line),
          ),
        );
        _assertAbsent(output.join('\n'), secrets, 'host output');
      },
    );
  }
}

Future<void> _inspectTables(
  LocalDatabase database,
  Iterable<String> secrets,
) async {
  for (final table in const [
    'assets',
    'drafts',
    'picker_imports',
    'picker_import_items',
    'local_preferences',
    'instagram_packages',
    'instagram_events',
    'export_jobs',
    'accounts',
    'attempt_groups',
    'destination_attempts',
    'attempt_events',
  ]) {
    _assertAbsent(jsonEncode(await database.db.query(table)), secrets, table);
  }
}

void _assertAbsent(String value, Iterable<String> secrets, String boundary) {
  for (final secret in secrets) {
    // Never print a vault value if this assertion fails.
    expect(
      value.contains(secret),
      isFalse,
      reason: 'Private fixture material crossed $boundary',
    );
  }
}
