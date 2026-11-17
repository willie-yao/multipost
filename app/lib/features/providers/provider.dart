import '../drafts/draft.dart';
import '../publishing/attempt.dart';
import '../review/review.dart';

String platformName(Destination destination) => switch (destination) {
  Destination.x => 'X',
  Destination.bluesky => 'Bluesky',
  Destination.instagram => 'Instagram',
};

abstract interface class PublishProvider {
  Destination get destination;
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context);
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  );
}
