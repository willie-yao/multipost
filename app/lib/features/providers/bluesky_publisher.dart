import 'dart:convert';
import 'dart:io';

import 'package:atproto_core/atproto_core.dart';
import 'package:at_primitives/tid.dart' show isValidTid;
import 'package:bluesky/app_bsky_embed_images.dart';
import 'package:bluesky/app_bsky_embed_video.dart';
import 'package:bluesky/app_bsky_feed_post.dart';
import 'package:bluesky/app_bsky_richtext_facet.dart';
import 'package:bluesky/bluesky.dart';
import 'package:bluesky/app_bsky_video_defs.dart';
import 'package:bluesky_text/bluesky_text.dart';
import 'package:crypto/crypto.dart';

import '../../core/clock.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../accounts/bluesky_connection.dart';
import '../accounts/credential_vault.dart';
import '../drafts/draft.dart';
import '../publishing/attempt.dart';
import '../review/review.dart';
import 'bluesky_photo.dart';
import '../review/review_service.dart';
import 'capabilities.dart';
import 'provider.dart';
import 'provider_errors.dart';

/// SDK rich text extracts offsets from the original caption. Never format,
/// truncate, normalize or shorten the text that the user reviewed.
class BlueskyPostEncoder {
  BlueskyPostEncoder(this.client, {Map<String, Blob> blobs = const {}})
    : blobs = Map.unmodifiable(blobs);
  final Bluesky client;
  final Map<String, Blob> blobs;
  Future<Map<String, dynamic>> encode(
    ResolvedPost post, {
    required DateTime createdAt,
  }) async {
    final built = await BlueskyText(post.content.text, enableMarkdown: false)
        .entities
        .toFacetsResult(
          resolver: (handle) async {
            try {
              return (await client.atproto.identity.resolveHandle(
                handle: handle,
              )).data.did;
            } catch (_) {
              return null;
            }
          },
        );
    UFeedPostEmbed? embed;
    if (post.assets.isNotEmpty) {
      if (post.assets.first.mimeType.startsWith('video/')) {
        embed = UFeedPostEmbed.embedVideo(
          data: EmbedVideo(
            video: blobs[post.assets.single.id]!,
            alt: post.content.media.single.altText,
          ),
        );
      } else {
        embed = UFeedPostEmbed.embedImages(
          data: EmbedImages(
            images: [
              for (var i = 0; i < post.assets.length; i++)
                EmbedImagesImage(
                  image: blobs[post.assets[i].id]!,
                  alt: post.content.media[i].altText,
                ),
            ],
          ),
        );
      }
    }
    return FeedPostRecord(
      text: post.content.text,
      createdAt: createdAt.toUtc(),
      facets: built.facets.isEmpty
          ? null
          : built.facets.map(RichtextFacet.fromJson).toList(),
      embed: embed,
    ).toJson();
  }
}

class RecordIdentity {
  RecordIdentity({
    required this.repoDid,
    required this.collection,
    required this.rkey,
  }) {
    if (!RegExp(r'^did:plc:[a-z2-7]{24}$').hasMatch(repoDid) ||
        collection != 'app.bsky.feed.post' ||
        !isValidTid(rkey)) {
      throw const FormatException('Invalid Bluesky record identity');
    }
  }
  final String repoDid, collection, rkey;
  String get uri => 'at://$repoDid/$collection/$rkey';
  Map<String, dynamic> toJson() => {
    'repoDid': repoDid,
    'collection': collection,
    'rkey': rkey,
  };
  factory RecordIdentity.fromJson(Map<String, dynamic> json) => RecordIdentity(
    repoDid: json['repoDid'] as String,
    collection: json['collection'] as String,
    rkey: json['rkey'] as String,
  );
}

/// Feature-owned, explicit-send adapter. Production capabilities remain gated.
class BlueskyPublisher implements PublishProvider {
  BlueskyPublisher({
    required this.connection,
    required this.media,
    required this.capabilities,
    this.clock = const Clock(),
  }) : validator = BlueskyValidator(capabilities);
  final BlueskyConnection connection;
  final MediaFiles media;
  final ProviderCapabilities capabilities;
  final BlueskyValidator validator;
  final Clock clock;
  final _keys = TidGenerator();
  @override
  Destination get destination => Destination.bluesky;
  PublishOutcome _outcome(
    PublishStatus status, {
    EvidenceSource source = EvidenceSource.local,
    String? reason,
    String? message,
    String? id,
    DateTime? retryAfter,
  }) => PublishOutcome(
    status: status,
    source: source,
    at: clock.now(),
    reasonCode: reason,
    message: message,
    remoteId: id,
    retryAfter: retryAfter,
    url: id == null
        ? null
        : Uri.https(
            'bsky.app',
            '/profile/${AtUri.parseStrict(id).hostname}/post/${AtUri.parseStrict(id).rkey}',
          ),
  );
  PublishOutcome _unknown() => _outcome(
    PublishStatus.unknown,
    reason: 'create-unconfirmed',
    message: 'Bluesky may have published this post. Check Bluesky before taking another action.',
  );
  @override
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context) async {
    var phase = ProviderFailurePhase.beforeCreate;
    if (context.uploadState['bluesky.dispatched'] == 'true') return _unknown();
    try {
      final issues = [
        ...sharedContentIssues(post),
        ...await validator.validate(post),
      ];
      if (issues.any((i) => i.blocking)) {
        final issue = issues.firstWhere((i) => i.blocking);
        return _outcome(
          PublishStatus.notPublished,
          reason: issue.code,
          message: issue.message,
        );
      }
      final did = post.account?.subject;
      if (post.account?.destination != destination ||
          did == null ||
          !RegExp(r'^did:plc:[a-z2-7]{24}$').hasMatch(did)) {
        throw const AccountConnectionExpired();
      }
      // Retain this captured generation-bound SDK client across every await.
      // Reacquiring a new client after preparation could select a new session.
      final client = await connection.authorizedClient(expectedDid: did);
      final files = <String, File>{};
      for (var i = 0; i < post.assets.length; i++) {
        final asset = post.assets[i];
        final file = await media.fileFor(asset.id);
        if (await media.find(asset.id) != asset ||
            (await sha256.bind(file.openRead()).first).toString() !=
                asset.sha256) {
          throw const FormatException('Reviewed media changed');
        }
        files[asset.id] = file;
      }
      _RecordEvidence? evidence;
      if (context.uploadState['bluesky-record'] case final encoded?) {
        evidence = _RecordEvidence.decode(encoded, post);
      } else {
        final blobs = <String, Blob>{};
        for (final asset in post.assets) {
          if (asset.mimeType.startsWith('video/')) {
            final job = await _prepareVideo(
              client,
              post,
              context,
              files[asset.id]!,
            );
            if (job.state.toJson() == 'JOB_STATE_FAILED' && !_videoReady(job)) {
              return _outcome(
                PublishStatus.notPublished,
                reason: 'video-processing-failed',
                message: 'Bluesky could not prepare this video. Review it before another attempt.',
              );
            }
            if (!_videoReady(job)) {
              return _outcome(
                PublishStatus.processing,
                source: EvidenceSource.provider,
                reason: 'media-processing',
                message: 'Bluesky is processing the video. No post has been created.',
              );
            }
            blobs[asset.id] = job.blob!;
            continue;
          }
          final fitted = await fitPhotoForBluesky(
            files[asset.id]!.path,
            asset.mimeType,
            capabilities.maxPhotoBytes,
          );
          final receipt = await client.atproto.repo.uploadBlob(
            bytes: fitted.bytes,
            $headers: {'Content-Type': fitted.mimeType},
          );
          final blob = receipt.data.blob;
          if (blob.mimeType != fitted.mimeType ||
              blob.size != fitted.bytes.length) {
            throw const FormatException('Upload receipt mismatch');
          }
          blobs[asset.id] = blob;
          await context.saveUpload(
            'bluesky.media.${asset.id}',
            jsonEncode({
              'sha': asset.sha256,
              'did': did,
              'blob': blob.toJson(),
            }),
          );
        }
        final record = await BlueskyPostEncoder(
          client,
          blobs: blobs,
        ).encode(post, createdAt: clock.now());
        evidence = _RecordEvidence(
          RecordIdentity(
            repoDid: did,
            collection: 'app.bsky.feed.post',
            rkey: _keys.next(),
          ),
          record,
          _source(post),
        );
        await context.saveUpload('bluesky-record', evidence.encode());
      }
      // A conservative sentinel survives process loss even between boundary and
      // HTTP. markDispatch must atomically reject prior dispatch under a claim.
      phase = ProviderFailurePhase.createDispatched;
      await context.saveUpload('bluesky.dispatched', 'true');
      await context.markDispatch();
      final receipt = await client.atproto.repo.createRecord(
        repo: evidence.identity.repoDid,
        collection: evidence.identity.collection,
        rkey: evidence.identity.rkey,
        record: evidence.record,
        validate: true,
      );
      if (_hasErrors(receipt.data.$unknown) ||
          receipt.data.uri.toString() != evidence.identity.uri ||
          receipt.data.cid != evidence.cid) {
        return _unknown();
      }
      return _outcome(
        PublishStatus.published,
        source: EvidenceSource.provider,
        id: evidence.identity.uri,
      );
    } on AccountConnectionExpired {
      return phase == ProviderFailurePhase.beforeCreate
          ? _outcome(
              PublishStatus.connectionNeeded,
              reason: 'connection-changed',
              message: 'Reconnect Bluesky and review this version again.',
            )
          : _unknown();
    } on AccountConnectionCancelled {
      return phase == ProviderFailurePhase.beforeCreate
          ? _outcome(
              PublishStatus.connectionNeeded,
              reason: 'connection-changed',
            )
          : _unknown();
    } on CredentialStorageFailure {
      return phase == ProviderFailurePhase.beforeCreate
          ? _outcome(
              PublishStatus.connectionNeeded,
              reason: 'credential-storage-failed',
            )
          : _unknown();
    } on XRPCException catch (error) {
      final code = error.response.data.error;
      final status = error.response.status.code;
      final definitive =
          const {
            'InvalidSwap': 400,
            'InvalidRequest': 400,
            'AuthenticationRequired': 401,
            'RateLimitExceeded': 429,
          }[code] ==
          status;
      return _outcome(
        classifyFailure(
          phase: phase,
          statusCode: status,
          documentedCode: code,
          definitiveRejection: definitive,
        ),
        reason: definitive ? 'bluesky-$code' : 'bluesky-unconfirmed-error',
        message: 'Bluesky could not accept this request. Check the connection, content or account limits.',
        retryAfter:
            status == 429 &&
                error.response.rateLimit.resetAt.isAfter(clock.now())
            ? error.response.rateLimit.resetAt
            : null,
      );
    } catch (_) {
      return phase == ProviderFailurePhase.beforeCreate
          ? _outcome(
              PublishStatus.notPublished,
              reason: 'preparation-failed',
              message: 'Bluesky preparation did not finish. Keep this version and check the connection or media.',
            )
          : _unknown();
    }
  }

  Future<JobStatus> _prepareVideo(
    Bluesky client,
    ResolvedPost post,
    PublishContext context,
    File file,
  ) async {
    if (context.uploadState['bluesky.video'] case final encoded?) {
      return _readSavedVideoStatus(encoded, post, context);
    }
    final session = (await client.atproto.server.getSession()).data;
    if (session.did != post.account!.subject ||
        session.emailConfirmed != true) {
      throw const FormatException('Verified email required');
    }
    final limitsAuth = (await client.video.getUploadLimitsAuth()).data.token;
    final limits = (await client.video.getUploadLimitsWithAuthToken(limitsAuth))
        .data;
    if (!limits.canUpload ||
        (limits.remainingDailyVideos != null &&
            limits.remainingDailyVideos! <= 0) ||
        (limits.remainingDailyBytes != null &&
            limits.remainingDailyBytes! < post.assets.single.bytes)) {
      throw const FormatException('Video upload unavailable');
    }
    final uploadAuth = (await client.video.getUploadVideoAuth()).data.token;
    final job = (await client.video.uploadVideoWithAuthToken(
      uploadAuth,
      bytes: await file.readAsBytes(),
    )).data;
    await _saveVideo(job, post, context);
    return job;
  }

  Future<JobStatus> _readSavedVideoStatus(
    String encoded,
    ResolvedPost post,
    PublishContext context,
  ) async {
    final job = _videoEvidence(encoded, post);
    if (job.state.toJson() == 'JOB_STATE_COMPLETED' ||
        job.state.toJson() == 'JOB_STATE_FAILED') {
      return job;
    }
    final current = await connection.videoJobStatus(
      expectedDid: post.account!.subject,
      jobId: job.jobId,
    );
    await _saveVideo(current, post, context);
    return current;
  }

  Future<void> _saveVideo(
    JobStatus job,
    ResolvedPost post,
    PublishContext context,
  ) async {
    _requireVideoJob(job, post);
    await context.saveUpload(
      'bluesky.video',
      jsonEncode({
        'source': _source(post),
        'job': {
          'jobId': job.jobId,
          'did': job.did,
          'state': job.state.toJson(),
          if (job.error == 'already_exists') 'error': 'already_exists',
          if (job.blob != null) 'blob': job.blob!.toJson(),
        },
      }),
    );
  }

  JobStatus _videoEvidence(String encoded, ResolvedPost post) {
    final value = jsonDecode(encoded) as Map<String, dynamic>;
    final job = const JobStatusConverter().fromJson(
      value['job'] as Map<String, dynamic>,
    );
    if (value['source'] != _source(post)) {
      throw const FormatException('Video source mismatch');
    }
    _requireVideoJob(job, post);
    return job;
  }

  bool _videoReady(JobStatus job) =>
      job.blob != null &&
      (job.state.toJson() == 'JOB_STATE_COMPLETED' ||
          job.error == 'already_exists');
  void _requireVideoJob(JobStatus job, ResolvedPost post) {
    if (job.did != post.account?.subject ||
        job.jobId.isEmpty ||
        job.jobId.length > 1024) {
      throw const FormatException('Video job mismatch');
    }
    // Failed jobs may report their ordinary error. Successful evidence may
    // carry only the documented reusable-blob error, without a failure code.
    if (_hasErrors(job.$unknown) ||
        ((job.state.toJson() == 'JOB_STATE_COMPLETED' ||
                job.error == 'already_exists') &&
            (job.failureCode != null ||
                (job.error != null && job.error != 'already_exists')))) {
      throw const FormatException('Conflicting video job evidence');
    }
    if (job.blob case final blob?) {
      CID.parse(blob.ref.link);
      if (blob.mimeType != 'video/mp4' ||
          blob.size <= 0 ||
          blob.size > 300000000) {
        throw const FormatException('Video blob mismatch');
      }
    }
  }

  @override
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async {
    if (previous.status == PublishStatus.published) return previous;
    try {
      if (previous.status == PublishStatus.processing &&
          context.uploadState['bluesky.dispatched'] != 'true') {
        final encoded = context.uploadState['bluesky.video'];
        if (encoded == null) return previous;
        final job = await _readSavedVideoStatus(encoded, post, context);
        if (job.state.toJson() == 'JOB_STATE_FAILED' && !_videoReady(job)) {
          return _outcome(
            PublishStatus.notPublished,
            source: EvidenceSource.provider,
            reason: 'video-processing-failed',
          );
        }
        if (_videoReady(job)) {
          return _outcome(
            PublishStatus.processing,
            reason: 'preparation-ready',
            message: 'The video is ready. Continue publishing after reviewing this version.',
          );
        }
        return previous;
      }
      final encoded = context.uploadState['bluesky-record'];
      if (encoded == null) return previous;
      final evidence = _RecordEvidence.decode(encoded, post);
      final client = await connection.authorizedClient(
        expectedDid: evidence.identity.repoDid,
      );
      final response = await client.atproto.repo.getRecord(
        repo: evidence.identity.repoDid,
        collection: evidence.identity.collection,
        rkey: evidence.identity.rkey,
      );
      if (!_hasErrors(response.data.$unknown) &&
          response.data.uri.toString() == evidence.identity.uri &&
          response.data.cid == evidence.cid &&
          computeRecordCid(response.data.value) == evidence.cid) {
        return _outcome(
          PublishStatus.published,
          source: EvidenceSource.provider,
          id: evidence.identity.uri,
        );
      }
    } catch (_) {
      /* Missing/different records and lookup errors do not prove absence. */
    }
    return previous;
  }
}

bool _hasErrors(Map<String, dynamic>? extra) =>
    extra?.keys.any((key) => key == 'error' || key == 'errors') ?? false;

String _source(ResolvedPost post) =>
    sha256.convert(utf8.encode(jsonEncode(post.toJson()))).toString();

class _RecordEvidence {
  _RecordEvidence(this.identity, this.record, this.source)
    : cid = computeRecordCid(record);
  final RecordIdentity identity;
  final Map<String, dynamic> record;
  final String source, cid;
  String encode() => jsonEncode({
    'identity': identity.toJson(),
    'record': record,
    'source': source,
    'cid': cid,
  });
  factory _RecordEvidence.decode(String encoded, ResolvedPost post) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final value = _RecordEvidence(
      RecordIdentity.fromJson(json['identity'] as Map<String, dynamic>),
      json['record'] as Map<String, dynamic>,
      json['source'] as String,
    );
    if (value.source != _source(post) ||
        value.identity.repoDid != post.account?.subject ||
        post.account?.destination != Destination.bluesky ||
        value.cid != json['cid']) {
      throw const FormatException('Frozen Bluesky record mismatch');
    }
    return value;
  }
}
