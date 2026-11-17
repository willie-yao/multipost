import 'dart:io';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_repository.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'app_fixture.dart';

// Fixture-only two-PNG limit. This is not a release capability claim.
final fixtureInstagramPolicy = InstagramPhotoPolicy(
  preparationVerified: true,
  maxPhotos: 2,
  mimeTypes: {'image/png'},
  evidenceVersion: 'fixture-only-two-png-1',
);

Future<InstagramTestServices> instagramTestServices({
  AndroidTransfer? transfer,
  InstagramShareCapability shareCapability = const InstagramShareCapability(),
}) async => InstagramTestServices(
  await localTestServices(),
  transfer: transfer,
  shareCapability: shareCapability,
);

class InstagramTestServices {
  InstagramTestServices(
    this.app, {
    this.transfer,
    this.shareCapability = const InstagramShareCapability(),
  });
  final InstagramShareCapability shareCapability;
  final AndroidTransfer? transfer;
  final AppServices app;
  InstagramRepository get instagramRepo => app.instagramRepo;
  late final policy = fixtureInstagramPolicy;
  late final validators = CapabilityRegistry({Destination.instagram: policy});
  late final review = ReviewService(
    app.drafts,
    app.media,
    app.accounts,
    validators,
    app.clock,
  );
  late final instagram = InstagramService(
    instagramRepo,
    app.media,
    app.instagramPackageRoot,
    policy,
    app.ids,
    app.clock,
    transfer: transfer,
    shareCapability: shareCapability,
  );

  Future<ReviewedPost> reviewTwoPhotos(String caption) async {
    final attachments = <Attachment>[];
    for (var i = 0; i < 2; i++) {
      final source = File(
        '${File(app.database.db.path).parent.path}/photo-$i.png',
      );
      final image = img.Image(width: 8 + i, height: 6);
      img.fill(image, color: img.ColorRgb8(20 + i, 80, 120));
      await source.writeAsBytes(img.encodePng(image), flush: true);
      final asset = await app.media.importFile(XFile(source.path));
      attachments.add(
        Attachment(assetId: asset.id, altText: 'Description ${i + 1}'),
      );
    }
    final draft = Draft(
      id: app.ids.next(),
      updatedAt: app.clock.now(),
      selected: {Destination.instagram},
      shared: PostContent(text: caption, media: attachments),
    );
    await app.drafts.save(draft, expectedRevision: -1);
    final result = await review.review(draft);
    if (!result.canProceed) {
      throw StateError('Fixture review blocked: ${result.issues}');
    }
    return result.snapshot;
  }

  Future<void> close() => app.close();
}
