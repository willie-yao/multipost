# Flutter Caption Official Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect X and Bluesky through official native flows and publish reviewed content with independent, durable, truthful results.

**Architecture:** Provider adapters consume immutable reviewed posts and a dispatch-journal context. Credentials remain outside drafts; each attempt binds a stable account identity. A SQLite coordinator persists every sending boundary, permits only explicit eligible retries, and integrates existing Instagram preparation without treating it as direct publication.

**Tech Stack:** Flutter, existing SQLite/models/UI, flutter_appauth for X, vetted atproto_oauth/bluesky SDKs and flutter_web_auth_2 for AT Protocol, flutter_secure_storage, http, url_launcher; deterministic fake transports and official conformance fixtures.

**Spec:** `PRODUCT.md`; `docs/design/design-review.md` sections 3–4 and 8–10; Caption results, Accounts, Review and publishing-state boards; parent `2026-11-16-flutter-caption-mvp.md`. Depends on Plan 01; mixed-destination completion also depends on Plan 02.

## Global Constraints

- "No unofficial APIs, password collection, browser automation, required AI services, or agent-driven workflows."
- "Published snapshots remain immutable."
- "A timeout alone never becomes a definite failure."
- "No automatic resend occurs on app launch or network return."
- "Never silently omit a selected destination."
- "Review separates \"Publish now\" from \"Prepare only\". The button says both: \"Publish & prepare\"."
- "Official account connection and publishing without an operated service remain feasibility questions, not established capabilities."
- All parent accessibility, scope and authorization constraints apply. Test accounts, paid API use, public metadata hosting and live publication require explicit authorization; ordinary unit tests use fakes.

---

## File ownership and provider contract

This plan owns accounts, providers, attempts, results, configuration and their tests. It extends Review/Library/AppServices rather than copying the shared composer. `flutter_appauth` is not a substitute for AT Protocol's DPoP/PAR profile. Public identifiers may be configuration; secrets/refresh tokens/private keys may not be compiled into source.

### Task P1: Resolve provider feasibility and configuration before promising connection

**Files:** Create `docs/engineering/{provider-feasibility,provider-capabilities,oauth-configuration}.md`, `app/lib/app/app_configuration.dart`, `app/lib/features/providers/{provider,capabilities}.dart`, `app/test/features/providers/capabilities_test.dart`, `app/test/fixtures/providers/README.md`. Add dependencies and lockfile only after compatibility inspection.

**Interfaces:** `AppConfiguration({required String xClientId,required Uri xRedirectUri,required Uri blueskyMetadataUri,required String blueskyCallbackScheme})`; invalid/missing configuration disables only the affected connection with an explanation. `ProviderCapabilities({required Destination destination,required String version,required DateTime verifiedAt,required bool text,required bool photos,required bool video,required int maxPhotos,required int maxTextUnits,required int maxPhotoBytes,required int maxVideoBytes,required int maxVideoDurationMs,required Set<String> mimeTypes})`; optional aspect/dimension/alt-text requirements are explicit named fields added with fixture tests, not generic unexplained limits. `TextCounter.count(String) -> int` is platform-specific. `CapabilityValidator(ProviderCapabilities,TextCounter) implements DestinationValidator`; `CapabilityRegistry(Map<Destination,DestinationValidator>) implements ValidatorRegistry` joins verified direct profiles with I1's InstagramPhotoPolicy adapter.

- [ ] **Step 1: Create an evidence matrix from official documentation.** For X and Bluesky record text/photo-set/video separately: auth scopes, app type, native callback requirements, identity verification, media endpoints, processing behavior, text units, Unicode/link rules, account-specific limits, error codes, idempotency/reconciliation, cost and required hosted resources. Every entry includes URL, accessed date and evidence level (`documented`, `mock-tested`, `device-tested`, `unavailable`). Unverified capabilities remain disabled. A documented claim is not a completed live test.
- [ ] **Step 2: Resolve the consequential setup choices.** X: public native client, developer-app billing owner and client ID; no client secret. Bluesky: a user-owned HTTPS client-metadata URL, allowed native redirect scheme and any optional identity resolver. A static metadata file may require hosting even without a backend; document this cost/ownership and obtain the product decision before publishing it. If ordinary users must create developer accounts, return that setup burden for review rather than silently violating install/connect. If a running service is required, present its exact purpose and cost before adding one.
- [ ] **Step 3: Verify library compatibility with the actual locked versions.** Inspect the published atproto_oauth 0.8.3 API/source and compatible bluesky SDK; the main README may differ. Confirm secure state/session persistence, PAR, PKCE S256, DPoP keys/nonces, issuer and account binding, native callback validation and refresh serialization. Run a local, fake-endpoint round trip before accepting the SDK. No homemade cryptographic signing implementation and no app-password fallback. Record selected versions/licenses. Generic OAuth package support alone is not sufficient evidence.
- [ ] **Step 4: Write a failing conservative-validation test.**

```dart
test('unsupported video blocks only its destination', () {
  final profile = fixtureCapabilities(destination: Destination.bluesky, video: false);
  final issues = CapabilityValidator(profile, FixtureTextCounter()).validate(
    fixtureVideoPost(Destination.bluesky));
  expect(issues.single.code, 'video-unavailable');
  expect(issues.single.destination, Destination.bluesky);
  expect(issues.single.blocking, isTrue);
});
```

Define these fixtures in `app/test/support/provider_fixtures.dart`: `fixtureCapabilities` with an explicitly fake evidence version, photo count 2, caption count 20 and small test byte/duration limits; `FixtureTextCounter` counts grapheme clusters for fixture text only; `fixtureVideoPost` builds ResolvedPost with a local MediaAsset MIME video/mp4 and stable account identity. It is not production X counting. Run `flutter test test/features/providers/capabilities_test.dart`; expect missing validator.
- [ ] **Step 5: Implement registry and configuration guards.**

```dart
if (post.assets.any((a) => a.mimeType.startsWith('video/')) && !profile.video) {
  return [ReviewIssue(destination: post.destination, code: 'video-unavailable',
    message: '${platformName(post.destination)} video is not available in this build. Replace it or leave this destination out.',
    blocking: true)];
}
```

Define `String platformName(Destination)` in provider.dart returning X, Bluesky or Instagram. Validate count, MIME, bytes, dimensions/aspect, duration and text units against the evidence-backed profile; unknown metadata blocks, and superseded/unavailable profiles report `Couldn't check current requirements`. Do not require a live limits fetch for every keystroke or silently let a generic string length stand in for official counting. Shipping profiles include their source/evidence version. Test fixture limits never enter production assets.
- [ ] **Step 6: Commit the evidence, guards and tests** with message `docs: establish official provider capability gates`. A provider gate still unavailable is explicitly recorded and blocks that provider's release, while local/Instagram work can proceed.

### Task P2: Connect X with public-client OAuth and secure sessions

**Files:** Create `app/lib/features/accounts/{credential_vault,x_connection}.dart`, `app/test/features/accounts/{credential_vault_test,x_connection_test}.dart`; extend account.dart, account_repository.dart, accounts_screen.dart, app_configuration.dart and Android callback/backup configuration.

**Interfaces:** `CredentialVault.read(Destination) -> Future<String?>`, `write(Destination,String) -> Future<void>`, `delete(Destination) -> Future<void>` stores opaque serialized session material. `AccountConnection.connect({String? handle}) -> Future<AccountIdentity>`, `disconnect() -> Future<void>`, `ensureAuthorized() -> Future<void>`. X ignores the optional handle; Bluesky requires it as an identity lookup input. `XConnection` implements the interface with `FlutterAppAuth`, vault, public-account repository and injected http.Client. `AccountRepository.save(AccountView) -> Future<void>`, `get(Destination) -> Future<AccountView>`, `setState(Destination,AccountState) -> Future<void>` extend the existing interface. Account public metadata lives in a dedicated `accounts` SQLite table introduced in this task's migration.

- [ ] **Step 1: Test cancellation and secure-write failure.**

```dart
test('failed credential persistence never reports connected', () async {
  final h = await accountHarness(vaultWriteFails: true);
  addTearDown(h.close);
  await expectLater(h.x.connect(), throwsA(isA<CredentialStorageFailure>()));
  expect((await h.accounts.get(Destination.x)).state, isNot(AccountState.connected));
  expect(await h.drafts.get('draft-1'), isNotNull);
});
```

Create `app/test/support/account_fixture.dart` defining `AccountHarness` with real draft/account SQLite stores, `MemoryCredentialVault` with read/write/delete and optional write failure, a fake OAuth driver returning opaque token values, and fake `/2/users/me` response. Add `XOAuthDriver.authorize() -> Future<XTokenSet>` and `refresh(String) -> Future<XTokenSet>` interfaces to x_connection.dart so tests never open a browser; `XTokenSet` has accessToken, refreshToken, expiresAt. Production `AppAuthXDriver` wraps the package. Run the test to see missing connection code.
- [ ] **Step 2: Implement the official browser flow.**

```dart
final response = await appAuth.authorizeAndExchangeCode(
  AuthorizationTokenRequest(configuration.xClientId, configuration.xRedirectUri.toString(),
    serviceConfiguration: const AuthorizationServiceConfiguration(
      authorizationEndpoint: 'https://x.com/i/oauth2/authorize',
      tokenEndpoint: 'https://api.x.com/2/oauth2/token'),
    scopes: const ['tweet.read', 'tweet.write', 'users.read', 'offline.access', 'media.write']),
);
```

Use the endpoints/scopes only after P1 confirms them; no clientSecret. Verify the SDK uses PKCE S256 and state/callback validation. The external browser owns login, consent and MFA. Do not collect an X password, use an embedded WebView login, or log callback query parameters. Retrieve the authenticated stable user ID and handle through the official identity endpoint. Store the complete token set securely before saving Connected public metadata. Define `CredentialStorageFailure implements Exception`; safe user copy is `Couldn't securely save this connection. Try again.`
- [ ] **Step 3: Implement refresh/disconnect and failure transitions.** Single-flight refresh per account; await durable rotated-token storage before treating it as healthy. A rejected/revoked refresh marks expired and prompts reconnection; timeout/offline retains existing credentials and reports unavailable connectivity, not a destructive disconnect. Keystore invalidation requires reconnect while preserving drafts/results. Disconnect removes credentials and clears connected metadata without touching content. Reconnecting to a different subject invalidates any review bound to the old subject.
- [ ] **Step 4: Run tests for state mismatch/cancel, wrong callback, token refresh race, secure-storage failure, changed identity and disconnect preserving drafts.** Inspect Android backup rules excluding tokens/session keys. No credential strings appear in logger messages or generic error UI. Live connection waits for P1's explicit account/setup authorization.
- [ ] **Step 5: Commit** with message `feat: add official X connection and secure token storage`.

### Task P3: Connect Bluesky through the full AT Protocol OAuth profile

**Files:** Create `app/lib/features/accounts/bluesky_connection.dart`, `app/test/features/accounts/bluesky_connection_test.dart`; extend credential vault adapters, Accounts screen, SDK lockfile and OAuth configuration documentation.

**Interfaces:** `BlueskyConnection implements AccountConnection`; `ATProtoOAuthDriver.authorize(String handle) -> Future<Uri>`, `callback(String url) -> Future<OAuthSession>`, `restore(String serializedSession) -> Future<OAuthSessionManager>`; production implementation delegates to the vetted SDK. `BlueskyConnection.authorizedClient() -> Future<Bluesky>` is used by the provider adapter. SDK types are imported from the pinned packages, not recreated. `AccountIdentity identityFromSession(OAuthSession)` validates the authenticated DID/issuer/PDS using documented SDK fields and official identity resolution before producing public identity.

- [ ] **Step 1: Test DPoP/session material never enters draft/account JSON.**

```dart
test('restoring Bluesky preserves private OAuth data only in the vault', () async {
  final h = await blueskyAccountHarness();
  addTearDown(h.close);
  await h.connection.connect(handle: 'testaccount.test');
  final account = await h.accounts.get(Destination.bluesky);
  expect(account.identity?.subject, 'did:plc:testaccount');
  expect(jsonEncode(account.toJson()), isNot(contains('private-test-key')));
  expect(await h.vault.read(Destination.bluesky), contains('private-test-key'));
  await h.restartConnection();
  await h.connection.ensureAuthorized();
  expect(h.driver.restoreCount, 1);
});
```

Extend account_fixture.dart with `BlueskyAccountHarness` and a fake ATProtoOAuthDriver using the pinned SDK's test-session fixture shape. Its `Future<void> restartConnection()` drops the in-memory connection/manager and reconstructs BlueskyConnection with the same vault, public account repository and fake driver, so ensureAuthorized must restore the saved session. The fake opaque value `private-test-key` is synthetic, never a real credential. Reuse AccountView/AccountIdentity codecs defined in L5. Run the test to establish missing Bluesky adapter.
- [ ] **Step 2: Implement client metadata, browser authorization and secure serialization.** The verified README's flow is:

```dart
final metadata = await getClientMetadata(configuration.blueskyMetadataUri.toString());
final oauth = OAuthClient(metadata);
final authUrl = await oauth.authorize(handle);
final callback = await FlutterWebAuth2.authenticate(
  url: authUrl.toString(), callbackUrlScheme: configuration.blueskyCallbackScheme);
final session = await oauth.callback(callback);
await vault.write(Destination.bluesky, jsonEncode(session.toJson()));
final manager = OAuthSessionManager.fromSession(session, client: oauth);
final client = Bluesky.fromOAuth(manager);
```

Adapt only to the API proved by P1; do not copy main-branch examples into a mismatched release. Inject persistent secure OAuthStateStore/session/nonce adapters where required so process death during browser flow has a defined recover-or-cancel outcome. `handle` is an identity lookup input, not a password. Enforce HTTPS discovery, issuer/client binding, exact callbacks, state single-use, session DID and PDS validation. Do not send credentials or DPoP headers across arbitrary redirects or to unvalidated endpoints. Use maintained SDK cryptography.
- [ ] **Step 3: Serialize session rotations and expose honest account state.** Await secure writes on refresh before allowing a subsequent authenticated action. The SDK's onSessionUpdated stream must be drained through a serialized persistence adapter; an unawaited listener with racing writes is not enough. Keep one refresh coordinator per session. Revocation means expired, cancellation preserves the prior state, network outage does not delete credentials. Disconnect clears stored session/private-key/state material. An unsupported custom PDS yields a named connection problem, not fallback to a password.
- [ ] **Step 4: Run tests for forged/mismatched issuer/state, rejected callback, nonce challenge, refresh rotation, process death with pending OAuth, unreadable vault and changed DID.** Record SDK conformance evidence. A valid public metadata URL is required for the authorized device check; absence is a blocked gate, not permission to stand up a service silently.
- [ ] **Step 5: Commit** with message `feat: connect Bluesky with native AT Protocol OAuth`.

### Task P4: Implement X content validation, upload and confirmed posting

**Files:** Create `app/lib/features/providers/{x_publisher,provider_errors}.dart`, `app/test/features/providers/x_publisher_test.dart`, `app/test/fixtures/providers/x/` sanitized protocol/conformance fixtures; extend provider.dart and capabilities.dart.

**Interfaces:** `PublishStatus { pending,preparing,sending,processing,published,notPublished,connectionNeeded,unknown,userReported }`; `EvidenceSource { provider,user,local }`; immutable `PublishOutcome({required PublishStatus status,required EvidenceSource source,required DateTime at,String? remoteId,Uri? url,String? reasonCode,String? message,DateTime? retryAfter})` with JSON codec and guarded constructors. `PublishContext({required String attemptId,required Map<String,String> uploadState,required Future<void> Function() markDispatch,required Future<void> Function(String key,String value) saveUpload})`. `PublishProvider.send(ResolvedPost,PublishContext) -> Future<PublishOutcome>`, `check(ResolvedPost,PublishOutcome,PublishContext) -> Future<PublishOutcome>`, `Destination get destination`. The coordinator reconstructs context.uploadState from durable storage for every check, so a provider can find its preassigned record identity after restart. `XPublisher` consumes XConnection, http.Client, MediaFiles, XTextCounter and verified capabilities. Outcomes live in `features/publishing/attempt.dart` created here so both providers share one type.

- [ ] **Step 1: Test upload success cannot masquerade as post success.**

```dart
test('lost create response after upload remains unknown', () async {
  final h = await xPublisherHarness(createResponseLost: true);
  addTearDown(h.close);
  final result = await h.provider.send(h.photoPost, PublishContext(
    attemptId: 'attempt-x-1', uploadState: const {}, markDispatch: () async { h.dispatchMarked = true; },
    saveUpload: h.recordUpload));
  expect(h.dispatchMarked, isTrue);
  expect(result.status, PublishStatus.unknown);
  expect(result.remoteId, isNull);
  expect(h.createRequestCount, 1);
});
```

Create `app/test/support/publisher_fixture.dart` with fake HTTP transport: ordered media-upload responses, an optional processing response, one final create response or simulated connection loss, request counters, and real temporary owned fixture files. `recordUpload(String,String)` records an in-memory map. Run the test; expect missing XPublisher.
- [ ] **Step 2: Implement source-backed text validation and payload encoding.** Implement `XTextCounter implements TextCounter` against official weighted-text/URL/emoji conformance fixtures pinned to a source revision; do not use Dart String.length. Preserve the exact caption. Links do not silently acquire a preview or shorten in the stored snapshot. Verify account identity from the reviewed post equals the connected subject before upload. Media-only posting is allowed only if P1 proves it. Validate the entire selected photo set or single video before dispatch.
- [ ] **Step 3: Implement the official media sequence.** Stream owned files; use the documented current simple or initialize/append/finalize/status endpoints and media categories from P1. Persist upload identifiers and processing status under attempt ID. Set alt-text metadata through the official supported endpoint before create; if descriptions cannot be carried, block or present a review warning requiring acknowledgment, never silently discard them. Accepted/processing media is still preparing/processing. When media is ready, durably mark the final publication boundary and issue one create request:

```dart
await context.markDispatch();
final response = await client.post(Uri.parse('https://api.x.com/2/tweets'),
  headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
  body: jsonEncode({'text': post.content.text,
    if (mediaIds.isNotEmpty) 'media': {'media_ids': mediaIds}}));
```

This is the final-create excerpt inside XPublisher.send; `accessToken` comes from XConnection's authorized token accessor, `mediaIds` from the completed uploads, and `post` is its ResolvedPost. Add `XConnection.accessToken() -> Future<String>` with refresh/secure persistence from P2. Never log the headers. Parse a documented success plus valid created ID before producing Published. A malformed response after submission is Unknown. Link construction uses that official ID, not text matching.
- [ ] **Step 4: Implement stage-aware failure classification.** `ProviderFailurePhase { beforeCreate,createDispatched }`; `classifyFailure({required ProviderFailurePhase phase,int? statusCode,String? documentedCode,bool definitiveRejection=false}) -> PublishStatus`. Before-create interruption is safe notPublished/connectionNeeded; an explicit documented rejection may be notPublished; timeout, connection loss, ambiguous 5xx or malformed final receipt after dispatch is unknown. A generic status code must not override provider semantics. Record Retry-After for rate limits and credit/access errors with clear remedies. No HTTP middleware automatically retries create requests. Reconciliation may confirm a known official ID; absence from an arbitrary timeline is not proof of failure.
- [ ] **Step 5: Run fixture tests and weighted-text conformance.** Include Unicode/emoji/URL counts, text-only/photo-set/video, metadata failure, processing failure, token expiry before create, partial upload, rate limit, credits exhausted, malformed success, account change and lost create response. Authorized live evidence covers each content class separately; do not mark video supported from a text-only test.
- [ ] **Step 6: Commit** with message `feat: implement official X publishing with honest outcomes`.

### Task P5: Implement Bluesky records, media and reconciliation

**Files:** Create `app/lib/features/providers/bluesky_publisher.dart`, `app/test/features/providers/bluesky_publisher_test.dart`, `app/test/fixtures/providers/bluesky/`; extend provider fixtures/capabilities.

**Interfaces:** `BlueskyPublisher implements PublishProvider`; consumes BlueskyConnection.authorizedClient(), owned files, Clock and capabilities. `BlueskyPostEncoder.encode(ResolvedPost,{required DateTime createdAt}) -> Future<Map<String,dynamic>>` creates the official record with exact text/facets/embeds. `BlueskyTextCounter implements TextCounter` counts the units mandated by the current lexicon. `RecordIdentity({required String repoDid,required String collection,required String rkey})` is persisted before final create if the verified endpoint permits client-supplied record keys.

- [ ] **Step 1: Test lost-response recovery uses the same durable identity.**

```dart
test('checking a lost response does not create another Bluesky record', () async {
  final h = await blueskyPublisherHarness(createResponseLost: true, recordExists: true);
  addTearDown(h.close);
  final outcome = await h.provider.send(h.photoPost, h.context);
  expect(outcome.status, PublishStatus.unknown);
  final checked = await h.provider.check(h.photoPost, outcome, h.context);
  expect(checked.status, PublishStatus.published);
  expect(h.createRequestCount, 1);
  expect(h.checkedRecordIdentity, h.createdRecordIdentity);
});
```

Extend publisher_fixture.dart with sanitized AT Protocol responses, a stable record identity and request counts. Its context getter reconstructs uploadState from the map populated by saveUpload, just as the real coordinator does from SQLite. Store RecordIdentity as JSON under the `bluesky-record` uploadState key before create. If the chosen official client cannot support that identity strategy, P1 must record the alternative; check returns unknown and the human-check flow remains required. Run the failing test before the adapter.
- [ ] **Step 2: Encode accurate text and media.** Count grapheme/byte limits per lexicon, not UTF-16 units. Generate link/mention facets using the SDK's verified rich-text support and official identity resolution; facet offsets are UTF-8 bytes. A pure helper used by encoder tests is:

```dart
({int byteStart, int byteEnd}) utf8Range(String text, int start, int end) => (
  byteStart: utf8.encode(text.substring(0, start)).length,
  byteEnd: utf8.encode(text.substring(0, end)).length,
);
```

Preserve composed emoji/newlines; unresolved mentions are plain text with a visible preview warning instead of falsely implying notification. Upload image blobs in selected order and include the corresponding alt strings in image embeds. Video uses the official supported processing/upload flow and verified account prerequisites; no unofficial transcoder. Keep returned blob references/job IDs with the attempt; upload completion alone is not Published.
- [ ] **Step 3: Submit one record with the SDK's DPoP session.** Construct `app.bsky.feed.post` with reviewed text, facets, embeds and createdAt. Use createRecord with the previously persisted rkey where supported; do not accidentally choose a new key on a transport retry. Await context.markDispatch immediately before final create. The response must have a valid record URI/CID and match the account/collection identity before becoming Published. A nonce/auth challenge may be retried only when official evidence shows the request was rejected before application; the SDK must not blindly retry record writes after timeouts. Audit its retry settings in P1.
- [ ] **Step 4: Implement exact reconciliation and errors.** Fetch the same repo/collection/rkey, verify the record/content corresponds to the frozen attempt, and then confirm with official evidence. A missing response or temporarily missing record remains unknown unless the protocol proves non-creation. Do not use fuzzy text/timestamp search to claim success. Reuse stage-aware classification from P4, with provider-specific rejection codes and rate limits. User-report completion remains outside the provider adapter.
- [ ] **Step 5: Run fixture tests for UTF-8 facets, own/shared captions, ordered image alt text, video processing, DPoP nonce, expired session, account mismatch, same-key reconciliation and denied upload.** Authorized device tests validate actual text, photo set and video independently. Persist the observed limits/SDK behavior in the capability evidence.
- [ ] **Step 6: Commit** with message `feat: publish Bluesky content with stable record recovery`.

### Task P6: Journal independent attempts and prevent unsafe retries

**Files:** Create `app/lib/features/publishing/{attempt_repository,publish_coordinator}.dart`, `app/test/features/publishing/{attempt_repository_test,publish_coordinator_test}.dart`; extend attempt.dart, local_database.dart, AppServices, Review and Instagram integration.

**Interfaces:** `DestinationAttempt({required String id,required String groupId,String? parentId,required ResolvedPost snapshot,required PublishOutcome outcome,DateTime? dispatchAt,required Map<String,String> uploadState})`; `AttemptGroup({required String id,required ReviewedPost snapshot,required String operationId,required DateTime createdAt})`, immutable models with copyWith/JSON codecs. `AttemptRepository(LocalDatabase,Clock,Ids)` exposes `begin(ReviewedPost,String operationId) -> Future<({AttemptGroup group,bool created})>`, `attempts(String groupId) -> Future<List<DestinationAttempt>>`, `claim(String attemptId) -> Future<bool>`, `markDispatch(String attemptId) -> Future<void>`, `record(String attemptId,PublishOutcome) -> Future<void>`, `saveUpload(String attemptId,String key,String value) -> Future<void>`, `recoverInterrupted() -> Future<void>`. `PublishCoordinator.confirm(ReviewedPost,{required String operationId}) -> Future<String>` returns group ID; `retry(String attemptId,ReviewedPost reviewed,{required String operationId}) -> Future<String>` returns child attempt ID; `check(String attemptId) -> Future<void>`; `reportFound(String attemptId) -> Future<void>`; `resendAfterCheck(String attemptId,ReviewedPost reviewed,{required String operationId,required bool duplicateRiskAccepted}) -> Future<String>`; `continuePending(String groupId,ReviewedPost reviewed,{required Set<String> attemptIds}) -> Future<void>` revalidates and explicitly claims only pending rows already in that group.

- [ ] **Step 1: Test partial success, double tap and retry scope.**

```dart
test('retrying failed Bluesky never repeats published X', () async {
  final h = await coordinatorHarness(x: PublishStatus.published, bluesky: PublishStatus.notPublished);
  addTearDown(h.close);
  final group = await h.coordinator.confirm(h.review, operationId: 'review-1');
  await h.coordinator.confirm(h.review, operationId: 'review-1');
  expect(h.x.sendCount, 1);
  final failed = (await h.attempts.attempts(group))
    .singleWhere((a) => a.snapshot.destination == Destination.bluesky);
  await h.coordinator.retry(failed.id, h.review, operationId: 'retry-1');
  expect(h.x.sendCount, 1);
  expect(h.bluesky.sendCount, 2);
  expect(h.instagramPrepareCount, 1);
});
```

Create `app/test/support/coordinator_fixture.dart`: real temporary SQLite repositories, fake PublishProviders with ordered outcomes and call counters, existing Instagram service with a counted preparation wrapper, and a persisted reviewed draft with account identities. Add `.getGroup(String) -> Future<AttemptGroup?>` and `.getAttempt(String) -> Future<DestinationAttempt?>` to the repository for recovery/results. Run the test; expect missing coordinator.
- [ ] **Step 2: Add durable dispatch tables and claims.**

```sql
CREATE TABLE attempt_groups(id TEXT PRIMARY KEY, draft_id TEXT NOT NULL,
  revision INTEGER NOT NULL, operation_id TEXT UNIQUE NOT NULL, payload TEXT NOT NULL,
  UNIQUE(draft_id, revision));
CREATE TABLE destination_attempts(id TEXT PRIMARY KEY, group_id TEXT NOT NULL,
  parent_id TEXT, retry_operation TEXT UNIQUE, destination TEXT NOT NULL,
  state TEXT NOT NULL, dispatch_at TEXT, payload TEXT NOT NULL,
  FOREIGN KEY(group_id) REFERENCES attempt_groups(id));
CREATE TABLE attempt_events(seq INTEGER PRIMARY KEY AUTOINCREMENT,
  attempt_id TEXT NOT NULL, at TEXT NOT NULL, payload TEXT NOT NULL);
```

Append-only events retain prior evidence; the row is a materialized current projection. `begin` creates the frozen group/destination rows transactionally before any external work; repeat operation returns the existing group with created=false, and confirm returns that group without starting work again. A different operation for an already submitted same draft revision opens the existing result rather than creating duplicate posts. Explicitly posting the same content again requires a new draft ID. Failed-destination editing creates a child snapshot, not edits to the group or successful destination.

```dart
final rows = await tx.query('destination_attempts', where: 'id = ?', whereArgs: [attemptId]);
if (rows.isEmpty) return false;
final current = DestinationAttempt.fromJson(
  jsonDecode(rows.single['payload'] as String) as Map<String,dynamic>);
if (current.outcome.status != PublishStatus.pending) return false;
final next = current.copyWith(outcome: current.outcome.copyWith(
  status: PublishStatus.preparing, source: EvidenceSource.local, at: clock.now()));
final changed = await tx.update('destination_attempts', {
  'state': 'preparing', 'payload': jsonEncode(next.toJson()),
}, where: 'id = ? AND state = ?', whereArgs: [attemptId, 'pending']);
if (changed == 1) {
  await tx.insert('attempt_events', {'attempt_id': attemptId,
    'at': next.outcome.at.toIso8601String(), 'payload': jsonEncode(next.outcome.toJson())});
}
return changed == 1;
```

This excerpt is the transaction body of claim; `tx` is the SQLite transaction and `clock` is the injected repository clock. Claims are database-backed, so two coordinator instances cannot both send. `markDispatch` transactionally updates both indexed state and payload plus its event before HTTP create. If that durable write fails, do not send. The provider may only receive the exact claimed snapshot. Save uploads/events with scoped IDs and no tokens. Validate outcomes before recording: Published requires provider evidence and a valid receipt; provider adapters cannot produce userReported.
- [ ] **Step 3: Execute confirmed work and preserve independent results.** Revalidate content/account identities and saved revision before begin. Prepare Instagram under a group-specific operation ID. Each direct destination has its own exception boundary and result; one failure does not erase another. Sequential direct sends simplify the MVP; network suspension may leave a later pending destination unsent. On restart pending says `Not sent — continue when ready`, not failed or automatically scheduled. No connectivity listener, lifecycle callback or bootstrap function calls confirm/retry. If the app dies after dispatch, recover sending as unknown. If it dies during pre-create upload, keep upload evidence and classify interrupted preparation as safe-to-resume only after an explicit reviewed action.
- [ ] **Step 4: Implement retries as child attempts with evidence gates.**

```dart
bool ordinaryRetryAllowed(PublishOutcome o) =>
  o.status == PublishStatus.notPublished || o.status == PublishStatus.connectionNeeded;
bool needsHumanDuplicateDecision(PublishOutcome o) => o.status == PublishStatus.unknown;
```

Connection-needed must be reconnected and re-reviewed first; rate limits enforce retryAfter. Exclude Published, processing, pending, sending, unknown and Instagram from ordinary Retry failed destinations. A parent has at most one active child; operation IDs deduplicate repeated retry taps. Unknown supports official check, user-reported found, or a duplicate-risk dialog followed by a new child attempt. `duplicateRiskAccepted` can only be set by that dialog action; it is not a default true. reportFound creates source=user/status=userReported without inventing a remote ID. Published originals remain immutable and are never remotely edited/deleted here.
- [ ] **Step 5: Run real-SQLite crash and concurrency tests.** Cover crash before begin commit (zero sends), after begin/before claim (pending, no automatic send), after dispatch/before response (unknown), after response/before outcome commit (unknown until exact reconciliation), two simultaneous confirm calls, storage failure at dispatch, own-caption edit before retry, account switch, and prepared Instagram retention. Verify claim state and payload projection agree in the same transaction. A successful response lost before local persistence is not proof of failure.
- [ ] **Step 6: Commit** with message `feat: journal independent posting attempts and safe retries`.

### Task P7: Complete result screens, account states and safe recovery navigation

**Files:** Create `app/lib/features/publishing/results_screen.dart`, `app/test/features/publishing/results_screen_test.dart`; modify Accounts/Review/Library/Instagram screens and app navigation; add `docs/testing/publishing-states.md`.

**Interfaces:** `ResultsScreen({required String groupId,required AttemptRepository attempts,required PublishCoordinator coordinator,required InstagramRepository instagram})`; `String outcomeLabel(PublishOutcome)` and `String outcomeDetail(PublishOutcome)` are pure presentation functions with status/source-aware copy. `LibraryRepository.listAttention()` returns unresolved groups and pending Instagram packages; stable order X, Bluesky, Instagram within a group. AppServices exposes these concrete repositories/coordinator.

- [ ] **Step 1: Test uncertainty has no ordinary Retry.**

```dart
testWidgets('unknown offers check and explicit resend, never normal retry', (tester) async {
  final h = await coordinatorHarness(x: PublishStatus.published, bluesky: PublishStatus.unknown);
  addTearDown(h.close);
  final id = await h.coordinator.confirm(h.review, operationId: 'r');
  await tester.pumpWidget(CaptionApp(home: ResultsScreen(groupId: id,
    attempts: h.attempts, coordinator: h.coordinator, instagram: h.instagramRepo)));
  await tester.pumpAndSettle();
  expect(find.text('Check Bluesky'), findsOneWidget);
  expect(find.text('I found the post'), findsOneWidget);
  expect(find.text('Send again…'), findsOneWidget);
  expect(find.text('Retry Bluesky'), findsNothing);
});
```

Run the test to establish missing UI. Use the same coordinator fixture; no real providers.
- [ ] **Step 2: Build the Caption results composition from actual evidence.** Use the first reviewed image with opaque subtitle boxes and a text-only fallback. Summary text derives independently from each outcome; do not use static `X published` sample copy. Official Published includes provider confirmation time and verified returned post link; User reported says `You marked this as posted · not verified by the app`. Upload progress and processing remain in-progress. Unknown uses warning icon/text and human-check actions. Instagram uses its own package state and source, never the direct-provider Published enum.
- [ ] **Step 3: Wire recovery actions and library.** Retry named failures opens a scoped review of only eligible versions, preserving frozen successful rows; edits affect the new child only. Check opens the exact post/profile in an external browser after any supported reconciliation, never treats browser return as confirmation. Send again shows the duplicate-risk dialog and requires new review. Leave [platform] out is an explicit Review edit. Offline never auto-sends on return. Local results remain readable when providers fail. Attention summaries remain above drafts; successful groups move to Results but stay accessible. Pending Instagram work survives disconnect, draft deletion and unrelated retries.
- [ ] **Step 4: Complete state coverage with actionable copy.** Exercise first connection, connecting/cancel, connected/expired/unavailable, no media, media loading/missing, profile validation unavailable, save failure, credential storage failure, API access/credit limit, rate limit/retry time, offline, preparation error, partial success and unknown. Show one dominant white action appropriate to the outstanding work; secondary fixes use outlined/text actions. Only actual durable saves justify `Your draft is saved on this device` in an offline banner. Don't silently promise verified capabilities in first-run/account copy when a provider remains gated.
- [ ] **Step 5: Run provider, coordinator and results tests, analyze, and mixed-device acceptance.** `flutter test test/features/accounts test/features/providers test/features/publishing`; `flutter analyze`. On authorized test accounts exercise X success + Bluesky definite failure + Instagram ready, retry only Bluesky, and return/mark/Undo Instagram. Separately inject a lost response through fake transport on device to inspect unknown UI without deliberately duplicating a real public post.
- [ ] **Step 6: Commit** with message `feat: complete truthful publishing results and recovery UX`.

## Milestone exit

Each advertised direct capability has official access evidence, a locked compatible SDK, fixture tests and authorized device evidence. A disabled integration is reported as incomplete, not disguised by demo data. Store the current cost/setup model in the engineering notes; an open-source native app can avoid a running backend while still needing public client metadata and platform developer access.
