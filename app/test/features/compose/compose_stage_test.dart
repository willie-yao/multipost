import 'package:cross_posting_app/features/compose/compose_stage.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

class StageFailure implements DraftRepository {
  StageFailure(this.delegate, this.onFailure);
  final DraftRepository delegate;
  final void Function() onFailure;
  bool failed = false;
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    if (!failed && draft.stage == ComposeStage.review) {
      failed = true;
      onFailure();
      throw const LocalStorageException('Stage write failed');
    }
    await delegate.save(draft, expectedRevision: expectedRevision);
  }
}

void main() {
  for (final newerStage in [false, true]) {
    test(
      'stage rollback preserves newer ${newerStage ? 'deliberate stage choice' : 'caption edits'}',
      () async {
        final s = await localTestServices();
        addTearDown(s.close);
        final initial = sampleDraft().copyWith(stage: ComposeStage.write);
        await s.drafts.save(initial, expectedRevision: -1);
        late DraftController c;
        final repo = StageFailure(s.drafts, () {
          c.change(
            editSharedCaption(
              c.draft,
              'Latest words during failed advance',
              s.clock.now(),
            ),
          );
          if (newerStage) {
            c.change(setStage(c.draft, ComposeStage.choose, s.clock.now()));
          }
        });
        c = DraftController(initial, repo, s.clock);
        addTearDown(c.dispose);
        expect(await saveComposeStage(c, ComposeStage.review), isFalse);
        expect(c.draft.shared.text, 'Latest words during failed advance');
        expect(
          c.draft.stage,
          newerStage ? ComposeStage.choose : ComposeStage.write,
        );
        expect(await c.flush(), isTrue);
        expect(await s.drafts.get(initial.id), c.draft);
      },
    );
  }
}
