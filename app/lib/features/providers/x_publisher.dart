import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/clock.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../accounts/credential_vault.dart';
import '../accounts/x_connection.dart';
import '../drafts/draft.dart';
import '../publishing/attempt.dart';
import '../review/review.dart';
import '../review/review_service.dart';
import 'capabilities.dart';
import 'provider.dart';
import 'provider_errors.dart';
import 'x_text_counter.dart';

/// X's official v2 protocol. No request is retried and all URLs are fixed to
/// api.x.com. A caller must supply a non-retrying Client (ordinary Client is).
/// Production composition remains gated by unavailable capability snapshots.
class XPublisher implements PublishProvider {
  XPublisher({
    required this.connection,
    required this.client,
    required this.media,
    required XTextCounter counter,
    required this.capabilities,
    this.clock = const Clock(),
  }) : validator = CapabilityValidator(capabilities, counter);
  final XConnection connection;
  final http.Client client;
  final MediaFiles media;
  final ProviderCapabilities capabilities;
  final CapabilityValidator validator;
  final Clock clock;
  @override
  Destination get destination => Destination.x;

  PublishOutcome _outcome(
    PublishStatus status, {
    EvidenceSource source = EvidenceSource.local,
    String? reason,
    String? message,
    DateTime? retryAfter,
    String? id,
  }) => PublishOutcome(
    status: status,
    source: source,
    at: clock.now(),
    reasonCode: reason,
    message: message,
    retryAfter: retryAfter,
    remoteId: id,
    url: id == null ? null : Uri.parse('https://x.com/i/status/$id'),
  );

  @override
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context) =>
      _prepareAndSend(post, context);

  Future<PublishOutcome> _prepareAndSend(
    ResolvedPost post,
    PublishContext context,
  ) async {
    var phase = ProviderFailurePhase.beforeCreate;
    final generation = connection.authorizationGeneration;
    if (context.uploadState['x.dispatched'] == 'true') {
      return _outcome(
        PublishStatus.unknown,
        reason: 'create-already-dispatched',
        message: 'X may have published this post. Check X before taking another action.',
      );
    }
    try {
      final issues = [
        ...sharedContentIssues(post),
        ...await validator.validate(post),
      ];
      if (issues.any((i) => i.blocking)) {
        return _outcome(
          PublishStatus.notPublished,
          reason: issues.first.code,
          message: issues.first.message,
        );
      }
      final subject = post.account?.subject;
      if (post.account?.destination != Destination.x ||
          subject == null ||
          !_id.hasMatch(subject)) {
        return _outcome(
          PublishStatus.connectionNeeded,
          reason: 'reviewed-account-required',
          message: 'Connect X and review this version again.',
        );
      }
      var token = await connection.accessToken(expectedSubject: subject);
      connection.requireAuthorizationGeneration(generation);
      // Check the whole selected set before the first upload. Length/path checks
      // alone would miss same-length corruption of the reviewed owned file.
      final files = <File>[];
      for (var i = 0; i < post.assets.length; i++) {
        final asset = post.assets[i];
        final alt = post.content.media[i].altText;
        // Conservative app bound: UTF-16 units <=1000 also bounds code points.
        // This is not a claim about X's unspecified Unicode maxLength semantics.
        if (alt.length > 1000) {
          throw const _PreparationFailure(
            'alt-text-too-long',
            'Shorten the X media description to at most 1000 UTF-16 units.',
          );
        }
        final file = await media.fileFor(asset.id);
        if (await media.find(asset.id) != asset ||
            (await sha256.bind(file.openRead()).first).toString() !=
                asset.sha256) {
          throw const _PreparationFailure(
            'media-unavailable',
            'A reviewed media file changed. Review it again.',
          );
        }
        files.add(file);
      }
      final ids = <String>[];
      final readyUploads = <_Upload>[];
      for (var i = 0; i < post.assets.length; i++) {
        connection.requireAuthorizationGeneration(generation);
        token = await connection.accessToken(expectedSubject: subject);
        connection.requireAuthorizationGeneration(generation);
        final asset = post.assets[i];
        final key = 'x.media.${asset.id}';
        _Upload? upload;
        final stored = context.uploadState[key];
        if (stored != null) {
          upload = _Upload.decode(stored);
          if (upload.sha != asset.sha256 || upload.subject != subject) {
            throw const _PreparationFailure(
              'upload-mismatch',
              'Review this X version again.',
            );
          }
          if (!upload.expiresAt.isAfter(clock.now())) {
            throw const _PreparationFailure(
              'upload-expired',
              'The X upload expired. Start a new attempt after review.',
            );
          }
          if (upload.state == 'uploading') {
            throw const _PreparationFailure(
              'upload-incomplete',
              'The previous media upload did not finish. Start a new attempt after review.',
            );
          }
          if (upload.state == 'failed') {
            throw const _PreparationFailure(
              'media-processing-failed',
              'X could not process this media. Replace it before publishing.',
            );
          }
          if (upload.state != 'succeeded') {
            if (upload.nextCheck != null &&
                clock.now().isBefore(upload.nextCheck!)) {
              return _processing(upload);
            }
            final response = await _exchange(
              _jsonRequest(
                'GET',
                '/2/media/upload',
                token,
                query: {'command': 'STATUS', 'media_id': upload.id},
              ),
            );
            _accepted(response, {200});
            upload = _processingReceipt(upload, _data(response), clock.now());
            await context.saveUpload(key, upload.encode());
          }
        } else if (asset.mimeType.startsWith('video/')) {
          final init = await _exchange(
            _jsonRequest(
              'POST',
              '/2/media/upload/initialize',
              token,
              body: {
                'media_type': asset.mimeType,
                'media_category': 'tweet_video',
                'total_bytes': asset.bytes,
              },
            ),
          );
          _accepted(init, {200, 201});
          upload = _uploadReceipt(_data(init), asset, subject, 'uploading');
          await context.saveUpload(key, upload.encode());
          var segment = 0;
          // Stream bounded raw multipart segments; never load the whole video.
          for (var offset = 0; offset < asset.bytes; offset += 5000000) {
            final end = (offset + 5000000).clamp(0, asset.bytes);
            final append =
                http.MultipartRequest(
                    'POST',
                    _uri('/2/media/upload/${upload.id}/append'),
                  )
                  ..followRedirects = false
                  ..headers['Authorization'] = 'Bearer $token'
                  ..fields['segment_index'] = '${segment++}'
                  ..files.add(
                    http.MultipartFile(
                      'media',
                      files[i].openRead(offset, end),
                      end - offset,
                      filename: 'segment',
                    ),
                  );
            _accepted(await _exchange(append), {200, 204});
          }
          final finalized = await _exchange(
            _jsonRequest(
              'POST',
              '/2/media/upload/${upload.id}/finalize',
              token,
            ),
          );
          _accepted(finalized, {200, 201});
          upload = _processingReceipt(upload, _data(finalized), clock.now());
          await context.saveUpload(key, upload.encode());
        } else {
          final request = http.MultipartRequest('POST', _uri('/2/media/upload'))
            ..followRedirects = false
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['media_category'] = 'tweet_image'
            ..fields['media_type'] = asset.mimeType
            ..files.add(
              http.MultipartFile(
                'media',
                files[i].openRead(),
                asset.bytes,
                filename: asset.mimeType == 'image/png'
                    ? 'photo.png'
                    : 'photo.jpg',
              ),
            );
          final response = await _exchange(request);
          _accepted(response, {200, 201});
          upload = _uploadReceipt(_data(response), asset, subject, 'succeeded');
          if (_data(response)['processing_info'] != null) {
            upload = _processingReceipt(upload, _data(response), clock.now());
          }
          await context.saveUpload(key, upload.encode());
        }
        if (upload.state == 'failed') {
          throw const _PreparationFailure(
            'media-processing-failed',
            'X could not process this media. Replace it before publishing.',
          );
        }
        if (upload.state != 'succeeded') return _processing(upload);
        final alt = post.content.media[i].altText;
        if (alt.isNotEmpty) {
          final metadata = await _exchange(
            _jsonRequest(
              'POST',
              '/2/media/metadata',
              token,
              body: {
                'id': upload.id,
                'metadata': {
                  'alt_text': {'text': alt},
                },
              },
            ),
          );
          _accepted(metadata, {200});
          if (_data(metadata)['id'] != upload.id) {
            throw const FormatException('Metadata was not confirmed');
          }
        }
        ids.add(upload.id);
        readyUploads.add(upload);
      }
      // Refresh after awaited preparation, and again if the durable boundary
      // itself outlives token freshness. Never choose a different subject.
      token = await connection.accessToken(expectedSubject: subject);
      connection.requireAuthorizationGeneration(generation);
      void requireUnexpiredMedia() {
        if (readyUploads.any(
          (upload) => !upload.expiresAt.isAfter(clock.now()),
        )) {
          throw const _PreparationFailure(
            'upload-expired',
            'The X upload expired. Start a new attempt after review.',
          );
        }
      }

      requireUnexpiredMedia();
      final request = _jsonRequest(
        'POST',
        '/2/tweets',
        token,
        body: {
          'text': post.content.text,
          if (ids.isNotEmpty) 'media': {'media_ids': ids},
        },
      );
      // The coordinator owns an exclusive attempt claim. Its durable boundary
      // must reject an already-dispatched attempt. The provider sentinel also
      // prevents recreation when a fresh context is reconstructed after crash.
      await context.saveUpload('x.dispatched', 'true');
      phase = ProviderFailurePhase.createDispatched;
      await context.markDispatch();
      token = await connection.accessToken(expectedSubject: subject);
      request.headers['Authorization'] = 'Bearer $token';
      requireUnexpiredMedia();
      connection.requireAuthorizationGeneration(generation);
      final response = await _exchange(request);
      _accepted(response, {201});
      final data = _data(response);
      final id = data['id'];
      if (id is! String || !_id.hasMatch(id) || data['text'] is! String) {
        throw const FormatException('Invalid post receipt');
      }
      return _outcome(
        PublishStatus.published,
        source: EvidenceSource.provider,
        id: id,
      );
    } on _Rejection catch (error) {
      final status = classifyFailure(
        phase: phase,
        statusCode: error.status,
        documentedCode: error.code,
        definitiveRejection: error.code != null,
      );
      final billing = error.status == 402 || error.code == 'usage-capped';
      return _outcome(
        status,
        source: EvidenceSource.provider,
        reason: error.code ?? 'http-${error.status}',
        message: billing
            ? 'X access or credits are exhausted. The app owner must check billing and access before another attempt.'
            : error.status == 429
            ? 'X is limiting requests. Wait before trying an eligible failed attempt again.'
            : error.status == 401
            ? 'Reconnect X and review this version again.'
            : error.status == 403
            ? 'The app owner must check X permissions and account access.'
            : 'X did not confirm publication. Check X before taking another action.',
        retryAfter: error.retryAfter,
      );
    } on AccountConnectionExpired {
      return _connectionFailure(phase);
    } on AccountConnectionCancelled {
      return _connectionFailure(phase);
    } on AccountConnectionUnavailable {
      return _connectionFailure(phase);
    } on CredentialStorageFailure {
      return _connectionFailure(phase);
    } on _PreparationFailure catch (error) {
      return _outcome(
        phase == ProviderFailurePhase.beforeCreate
            ? PublishStatus.notPublished
            : PublishStatus.unknown,
        reason: error.code,
        message: error.message,
      );
    } catch (_) {
      return _outcome(
        classifyFailure(phase: phase),
        reason: phase == ProviderFailurePhase.beforeCreate
            ? 'preparation-failed'
            : 'create-unconfirmed',
        message: phase == ProviderFailurePhase.beforeCreate
            ? 'X preparation did not finish. Keep this version and check the connection or media.'
            : 'X may have published this post. Check X before taking another action.',
      );
    }
  }

  PublishOutcome _connectionFailure(ProviderFailurePhase phase) => _outcome(
    phase == ProviderFailurePhase.beforeCreate
        ? PublishStatus.connectionNeeded
        : PublishStatus.unknown,
    reason: 'connection-changed',
    message: phase == ProviderFailurePhase.beforeCreate
        ? 'The X connection changed. Reconnect and review this version again.'
        : 'The X connection changed after dispatch was marked. Check X before taking another action.',
  );
  PublishOutcome _processing(_Upload upload) => _outcome(
    PublishStatus.processing,
    source: EvidenceSource.provider,
    reason: 'media-processing',
    message: 'X is processing the media. No post has been created.',
    retryAfter: upload.nextCheck,
  );

  @override
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async {
    // Checks never retry a dispatched create, and never search a timeline.
    if (previous.status == PublishStatus.published) return previous;
    if (previous.status == PublishStatus.processing &&
        context.uploadState['x.dispatched'] != 'true') {
      return _checkMedia(post, previous, context);
    }
    final id = previous.remoteId;
    if (id == null ||
        !_id.hasMatch(id) ||
        post.account?.destination != Destination.x) {
      return previous;
    }
    try {
      final token = await connection.accessToken(
        expectedSubject: post.account!.subject,
      );
      final response = await _exchange(
        _jsonRequest(
          'GET',
          '/2/tweets/$id',
          token,
          query: {'tweet.fields': 'author_id'},
        ),
      );
      _accepted(response, {200});
      final data = _data(response);
      if (data['id'] == id &&
          data['author_id'] == post.account!.subject &&
          data['text'] is String) {
        return _outcome(
          PublishStatus.published,
          source: EvidenceSource.provider,
          id: id,
        );
      }
    } catch (_) {
      /* Absence/errors are not proof a post was never published. */
    }
    return previous;
  }

  // Reconciliation is read-only at X. Ready media never causes post creation;
  // an explicitly labelled continuation must revalidate then call send again.
  Future<PublishOutcome> _checkMedia(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async {
    try {
      if (post.account?.destination != Destination.x) return previous;
      final subject = post.account!.subject;
      final token = await connection.accessToken(expectedSubject: subject);
      var found = false;
      for (final asset in post.assets) {
        final key = 'x.media.${asset.id}';
        final stored = context.uploadState[key];
        if (stored == null) continue;
        found = true;
        var upload = _Upload.decode(stored);
        if (upload.subject != subject || upload.sha != asset.sha256) {
          return previous;
        }
        if (!upload.expiresAt.isAfter(clock.now())) {
          return _outcome(
            PublishStatus.notPublished,
            reason: 'upload-expired',
            message: 'The X upload expired. Start a new attempt after review.',
          );
        }
        if (upload.state != 'succeeded' &&
            upload.state != 'failed' &&
            upload.state != 'uploading') {
          if (upload.nextCheck != null &&
              clock.now().isBefore(upload.nextCheck!)) {
            return _processing(upload);
          }
          final response = await _exchange(
            _jsonRequest(
              'GET',
              '/2/media/upload',
              token,
              query: {'command': 'STATUS', 'media_id': upload.id},
            ),
          );
          _accepted(response, {200});
          upload = _processingReceipt(upload, _data(response), clock.now());
          await context.saveUpload(key, upload.encode());
        }
        if (upload.state == 'failed') {
          return _outcome(
            PublishStatus.notPublished,
            source: EvidenceSource.provider,
            reason: 'media-processing-failed',
            message:
                'X could not process this media. Replace it before publishing.',
          );
        }
        if (upload.state != 'succeeded') return _processing(upload);
      }
      if (found) {
        return _outcome(
          PublishStatus.processing,
          reason: 'preparation-ready',
          message: 'Media preparation can continue. Continue publishing after reviewing this version.',
        );
      }
    } catch (_) {
      /* A failed check is not evidence that processing failed. */
    }
    return previous;
  }

  static final _id = RegExp(r'^[1-9][0-9]{0,18}$');
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.https('api.x.com', path, query);
  http.Request _jsonRequest(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    final request = http.Request(method, _uri(path, query))
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return request;
  }

  Future<_Response> _exchange(http.BaseRequest request) async {
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 1048576) {
        throw const FormatException('Response too large');
      }
    }
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      /* Receipt validation below decides whether an empty body is permitted. */
    }
    return _Response(response.statusCode, json, response.headers);
  }

  void _accepted(_Response response, Set<int> statuses) {
    final hasErrors = response.json?.containsKey('errors') ?? false;
    final errors = response.json?['errors'];
    if (statuses.contains(response.status) &&
        (!hasErrors || (errors is List && errors.isEmpty))) {
      return;
    }
    final type = response.json?['type'];
    String? code;
    for (final candidate in [
      'invalid-request',
      'not-authorized-for-resource',
      'client-forbidden',
      'usage-capped',
      'rate-limit-exceeded',
    ]) {
      if (type == 'https://api.x.com/2/problems/$candidate' &&
          response.json?['data'] == null) {
        code = candidate;
      }
    }
    DateTime? retry;
    final header = response.headers['retry-after'];
    if (header != null) {
      final seconds = int.tryParse(header);
      if (seconds != null && seconds >= 0) {
        retry = clock.now().add(Duration(seconds: seconds));
      } else {
        try {
          retry = HttpDate.parse(header).toUtc();
        } catch (_) {}
      }
    }
    if (retry == null && response.status == 429) {
      final reset = int.tryParse(response.headers['x-rate-limit-reset'] ?? '');
      if (reset != null) {
        retry = DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
      }
    }
    throw _Rejection(response.status, code, retry);
  }

  Map<String, dynamic> _data(_Response response) {
    final data = response.json?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing official receipt');
    }
    return data;
  }

  _Upload _uploadReceipt(
    Map<String, dynamic> data,
    MediaAsset asset,
    String subject,
    String state,
  ) {
    final id = data['id'];
    final lifetime = data['expires_after_secs'];
    if (id is! String ||
        !_id.hasMatch(id) ||
        lifetime is! int ||
        lifetime <= 0) {
      throw const FormatException('Invalid upload receipt');
    }
    return _Upload(
      id: id,
      sha: asset.sha256,
      subject: subject,
      state: state,
      expiresAt: clock.now().add(Duration(seconds: lifetime)),
    );
  }

  _Upload _processingReceipt(
    _Upload upload,
    Map<String, dynamic> data,
    DateTime now,
  ) {
    if (data['id'] != upload.id) {
      throw const FormatException('Upload identity changed');
    }
    final info = data['processing_info'];
    final state = info == null
        ? 'succeeded'
        : (info as Map<String, dynamic>)['state'];
    if (state is! String) {
      throw const FormatException('Invalid processing state');
    }
    final delay = info is Map ? info['check_after_secs'] : null;
    final next = state == 'succeeded' || state == 'failed'
        ? null
        : now.add(Duration(seconds: delay is int && delay > 0 ? delay : 5));
    return _Upload(
      id: upload.id,
      sha: upload.sha,
      subject: upload.subject,
      state: state,
      expiresAt: upload.expiresAt,
      nextCheck: next,
    );
  }
}

class _Response {
  const _Response(this.status, this.json, this.headers);
  final int status;
  final Map<String, dynamic>? json;
  final Map<String, String> headers;
}

class _Rejection implements Exception {
  const _Rejection(this.status, this.code, this.retryAfter);
  final int status;
  final String? code;
  final DateTime? retryAfter;
}

class _PreparationFailure implements Exception {
  const _PreparationFailure(this.code, this.message);
  final String code, message;
}

class _Upload {
  const _Upload({
    required this.id,
    required this.sha,
    required this.subject,
    required this.state,
    required this.expiresAt,
    this.nextCheck,
  });
  final String id, sha, subject, state;
  final DateTime expiresAt;
  final DateTime? nextCheck;
  String encode() => jsonEncode({
    'id': id,
    'sha': sha,
    'subject': subject,
    'state': state,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (nextCheck != null) 'nextCheck': nextCheck!.toUtc().toIso8601String(),
  });
  factory _Upload.decode(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    final id = data['id'] as String;
    if (!XPublisher._id.hasMatch(id)) {
      throw const FormatException('Invalid upload id');
    }
    return _Upload(
      id: id,
      sha: data['sha'] as String,
      subject: data['subject'] as String,
      state: data['state'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      nextCheck: data['nextCheck'] == null
          ? null
          : DateTime.parse(data['nextCheck'] as String),
    );
  }
}
