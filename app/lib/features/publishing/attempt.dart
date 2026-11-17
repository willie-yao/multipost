enum PublishStatus {
  pending,
  preparing,
  sending,
  processing,
  published,
  notPublished,
  connectionNeeded,
  unknown,
  userReported,
}

enum EvidenceSource { provider, user, local }

/// Publication evidence shared by direct providers and the durable coordinator.
/// A local handoff or accepted upload can never construct provider publication.
class PublishOutcome {
  PublishOutcome({
    required this.status,
    required this.source,
    required this.at,
    this.remoteId,
    this.url,
    this.reasonCode,
    this.message,
    this.retryAfter,
  }) {
    if (status == PublishStatus.published &&
        (source != EvidenceSource.provider ||
            remoteId == null ||
            remoteId!.trim().isEmpty)) {
      throw ArgumentError(
        'Publication needs provider evidence and an official identifier.',
      );
    }
    if (status == PublishStatus.userReported && source != EvidenceSource.user) {
      throw ArgumentError('User-reported publication needs user evidence.');
    }
    if (url != null &&
        (url!.scheme != 'https' ||
            url!.host.isEmpty ||
            url!.userInfo.isNotEmpty)) {
      throw ArgumentError('Publication links must use HTTPS.');
    }
  }
  final PublishStatus status;
  final EvidenceSource source;
  final DateTime at;
  final String? remoteId, reasonCode, message;
  final Uri? url;
  final DateTime? retryAfter;
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'source': source.name,
    'at': at.toUtc().toIso8601String(),
    if (remoteId != null) 'remoteId': remoteId,
    if (url != null) 'url': url.toString(),
    if (reasonCode != null) 'reasonCode': reasonCode,
    if (message != null) 'message': message,
    if (retryAfter != null) 'retryAfter': retryAfter!.toUtc().toIso8601String(),
  };
  factory PublishOutcome.fromJson(Map<String, dynamic> json) => PublishOutcome(
    status: PublishStatus.values.byName(json['status'] as String),
    source: EvidenceSource.values.byName(json['source'] as String),
    at: DateTime.parse(json['at'] as String),
    remoteId: json['remoteId'] as String?,
    url: json['url'] == null ? null : Uri.parse(json['url'] as String),
    reasonCode: json['reasonCode'] as String?,
    message: json['message'] as String?,
    retryAfter: json['retryAfter'] == null
        ? null
        : DateTime.parse(json['retryAfter'] as String),
  );
}

/// Each call receives a fresh owned snapshot from durable attempt storage.
/// Callbacks must finish their durable write before completing; failure blocks
/// create. Providers never update a coordinator's in-memory projection directly.
class PublishContext {
  PublishContext({
    required this.attemptId,
    required Map<String, String> uploadState,
    required this.markDispatch,
    required this.saveUpload,
  }) : uploadState = Map.unmodifiable(uploadState) {
    if (attemptId.trim().isEmpty) {
      throw ArgumentError.value(attemptId, 'attemptId');
    }
  }
  final String attemptId;
  final Map<String, String> uploadState;

  /// Atomically reject a previously dispatched attempt under the coordinator's
  /// exclusive claim, and await its durable boundary before completing.
  final Future<void> Function() markDispatch;
  final Future<void> Function(String key, String value) saveUpload;
}
