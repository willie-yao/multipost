import '../drafts/draft.dart';

String platformName(Destination destination) => switch (destination) {
  Destination.x => 'X',
  Destination.bluesky => 'Bluesky',
  Destination.instagram => 'Instagram',
};
