import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/providers/provider_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outcome round trips evidence and rejects invented publication', () {
    final at = DateTime.utc(2026, 11, 17);
    final published = PublishOutcome(
      status: PublishStatus.published,
      source: EvidenceSource.provider,
      at: at,
      remoteId: '123',
      url: Uri.parse('https://x.com/i/status/123'),
    );
    expect(
      PublishOutcome.fromJson(published.toJson()).toJson(),
      published.toJson(),
    );
    expect(
      () => PublishOutcome(
        status: PublishStatus.published,
        source: EvidenceSource.local,
        at: at,
        remoteId: '123',
      ),
      throwsArgumentError,
    );
    expect(
      () => PublishOutcome(
        status: PublishStatus.published,
        source: EvidenceSource.provider,
        at: at,
      ),
      throwsArgumentError,
    );
    expect(
      () => PublishOutcome(
        status: PublishStatus.userReported,
        source: EvidenceSource.provider,
        at: at,
      ),
      throwsArgumentError,
    );
    final uploads = {'id': 'one'};
    final context = PublishContext(
      attemptId: 'a',
      uploadState: uploads,
      markDispatch: () async {},
      saveUpload: (k, v) async {},
    );
    uploads.clear();
    expect(context.uploadState, {'id': 'one'});
    expect(() => context.uploadState.clear(), throwsUnsupportedError);
  });
  test(
    'failure classification requires definitive semantics after dispatch',
    () {
      for (final code in [400, 401, 403, 429, 500]) {
        expect(
          classifyFailure(
            phase: ProviderFailurePhase.createDispatched,
            statusCode: code,
          ),
          PublishStatus.unknown,
        );
      }
      expect(
        classifyFailure(
          phase: ProviderFailurePhase.beforeCreate,
          statusCode: 401,
        ),
        PublishStatus.connectionNeeded,
      );
      expect(
        classifyFailure(phase: ProviderFailurePhase.beforeCreate),
        PublishStatus.notPublished,
      );
      expect(
        classifyFailure(
          phase: ProviderFailurePhase.createDispatched,
          statusCode: 429,
          documentedCode: 'usage-capped',
          definitiveRejection: true,
        ),
        PublishStatus.notPublished,
      );
      expect(
        classifyFailure(
          phase: ProviderFailurePhase.createDispatched,
          statusCode: 503,
          definitiveRejection: true,
        ),
        PublishStatus.unknown,
      );
    },
  );
}
