import 'draft.dart';

PostContent resolveContent(Draft d, Destination target) {
  final version = d.versions[target];
  return PostContent(
    text: version?.ownText ?? d.shared.text,
    media: version?.ownMedia ?? d.shared.media,
  );
}

Draft editSharedCaption(Draft d, String text, DateTime now) => d.copyWith(
  revision: d.revision + 1,
  updatedAt: now,
  sharedTextRevision: d.sharedTextRevision + 1,
  shared: d.shared.copyWith(text: text),
);

Draft editOwnCaption(Draft d, Destination target, String text, DateTime now) {
  final previous = d.versions[target] ?? DestinationVersion();
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    versions: {
      ...d.versions,
      target: previous.copyWith(
        ownText: text,
        baseTextRevision: d.sharedTextRevision,
      ),
    },
  );
}

Draft restoreSharedCaption(Draft d, Destination target, DateTime now) {
  final previous = d.versions[target] ?? DestinationVersion();
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    versions: {
      ...d.versions,
      target: previous.copyWith(ownText: null, baseTextRevision: null),
    },
  );
}

Draft editSharedMedia(Draft d, List<Attachment> media, DateTime now) {
  final shared = d.shared.copyWith(media: media);
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    sharedMediaRevision: d.sharedMediaRevision + (shared == d.shared ? 0 : 1),
    shared: shared,
  );
}

Draft editOwnMedia(
  Draft d,
  Destination target,
  List<Attachment> media,
  DateTime now,
) {
  final previous = d.versions[target] ?? DestinationVersion();
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    versions: {
      ...d.versions,
      target: previous.copyWith(
        ownMedia: media,
        baseMediaRevision: d.sharedMediaRevision,
      ),
    },
  );
}

Draft restoreSharedMedia(Draft d, Destination target, DateTime now) {
  final previous = d.versions[target] ?? DestinationVersion();
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    versions: {
      ...d.versions,
      target: previous.copyWith(ownMedia: null, baseMediaRevision: null),
    },
  );
}

Draft setDestination(Draft d, Destination target, bool selected, DateTime now) {
  final destinations = {...d.selected};
  if (selected) {
    destinations.add(target);
  } else {
    destinations.remove(target);
  }
  return d.copyWith(
    revision: d.revision + 1,
    updatedAt: now,
    selected: destinations,
  );
}

Draft setStage(Draft d, ComposeStage stage, DateTime now) =>
    d.copyWith(revision: d.revision + 1, updatedAt: now, stage: stage);

Draft restoreVersion(
  Draft d,
  Destination target,
  DestinationVersion version,
  DateTime now,
) => d.copyWith(
  revision: d.revision + 1,
  updatedAt: now,
  versions: {...d.versions, target: version},
);
