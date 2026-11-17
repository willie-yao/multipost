import '../drafts/draft.dart';
import '../drafts/draft_repository.dart';

class LibraryRepository {
  LibraryRepository(this.drafts);
  final DraftRepository drafts;
  Future<List<Draft>> listDrafts() => drafts.list();
}
