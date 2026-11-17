import '../publishing/attempt.dart';

enum ProviderFailurePhase { beforeCreate, createDispatched }

PublishStatus classifyFailure({
  required ProviderFailurePhase phase,
  int? statusCode,
  String? documentedCode,
  bool definitiveRejection = false,
}) {
  if (phase == ProviderFailurePhase.beforeCreate) {
    return statusCode == 401
        ? PublishStatus.connectionNeeded
        : PublishStatus.notPublished;
  }
  if (definitiveRejection &&
      documentedCode != null &&
      statusCode != null &&
      statusCode >= 400 &&
      statusCode < 500) {
    return statusCode == 401
        ? PublishStatus.connectionNeeded
        : PublishStatus.notPublished;
  }
  return PublishStatus.unknown;
}
