/// Literal reason codes only. The unknown fallback requires a committed snapshot;
/// unsaved editors must use storage-failed or their own action-specific copy.
String userSafeMessage(String reasonCode) => switch (reasonCode) {
  'connection-needed' => 'Reconnect this account before publishing.',
  'storage-failed' => "Couldn't save — keep this screen open",
  'rate-limited' => 'This service needs you to wait before trying again.',
  'access-unavailable' => 'Publishing access is unavailable for this account.',
  _ => 'Something interrupted this action. Your saved work is still available.',
};
