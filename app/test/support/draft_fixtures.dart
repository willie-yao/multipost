import 'package:cross_posting_app/features/drafts/draft.dart';

Draft sampleDraft() => Draft(
  id: 'draft-1',
  updatedAt: DateTime.utc(2026, 11, 16),
  selected: {Destination.x, Destination.bluesky, Destination.instagram},
  shared: const PostContent(text: 'A little color from today’s walk.'),
);
