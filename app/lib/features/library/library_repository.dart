import '../drafts/draft.dart';
import '../drafts/draft_repository.dart';
import '../instagram/instagram_package.dart';
import '../instagram/instagram_repository.dart';

class LibraryRepository {
  LibraryRepository(this.drafts, this.instagram);
  final InstagramRepository instagram;
  final DraftRepository drafts;
  Future<List<Draft>> listDrafts() => drafts.list();
  Future<List<InstagramPackage>> markedInstagram() => instagram.marked();
  Future<List<InstagramPackage>> pendingInstagram() => instagram.pending();
}
