# OAuth configuration and SDK acceptance

Recorded 2026-11-16 (America/Los_Angeles). **Neither direct provider connection
is accepted for production.** Public build metadata, documented provider limits,
SDK compatibility and OAuth/device/live acceptance are separate gates.

## Build configuration and ownership

AppConfiguration requires xClientId, xRedirectUri, blueskyMetadataUri and
blueskyCallbackScheme. fromEnvironment reads X_CLIENT_ID, X_REDIRECT_URI,
BLUESKY_METADATA_URI and BLUESKY_CALLBACK_SCHEME. These are public metadata;
there is no client-secret field. No values are provisioned in this task.

connection(destination).configured means only that supplied syntax passes the
local guard. available remains false for both direct providers because provider
acceptance is incomplete. Missing/invalid X setup changes only X's reason;
missing/invalid Bluesky setup changes only Bluesky's reason. Instagram's gate
means local preparation, never verified receiving/publishing support.
LocalAccountRepository surfaces each direct unavailable reason. AppServices
composes the independent Instagram validator and dated direct capability gates.
Drafting/saving requires neither a connection nor network; Review retains every
selected destination and its content.

X release setup requires the app owner's public Native App registration, OAuth2
PKCE callback registration, billing/access decision and public client ID. Do
not embed a client secret. The guard accepts a public HTTPS callback or a
reverse-domain custom scheme with a single slash path; actual registered exact
matching and native routing remain untested. No DNS/ownership check is implied
by the local hostname syntax check. The app owner must confirm the selected
X access arrangement before any paid request; do not assume a universal free
API. Ordinary users authorize their account; developer registration must not
silently become an ordinary-user install/connect requirement. For a personal
self-build, the developer and ordinary user may be the same person, but the
roles and maintenance burden must still be explicit.

Bluesky requires owner-controlled HTTPS static client metadata, HTTP200,
application/json and no redirect. Metadata client_id must exactly equal the
canonical configured/emitted URL string. Compare strings, not Uri equivalence.
Dart Uri canonicalizes an explicit default HTTPS:443 away; this guard accepts
that canonical URL, rejects nondefault ports, queries/fragments/user-info and
local/IP-literal hosts. It does not claim DNS resolution or host ownership.
The custom scheme must equal metadata hostname in reverse-domain order; the
app's fixed redirect path is /callback, using scheme:/callback (one slash).
Example values in tests use reserved example.com; they are not owned endpoints.
A real owner/domain/scheme/product identity remains undecided. No Android
intent-filter or hosted metadata was registered/published here.

Metadata includes application_type=native, token_endpoint_auth_method=none,
authorization_code + refresh_token grants, response_type=code, atproto and all
requested scopes, and dpop_bound_access_tokens=true. Static hosting is required
without a token-holding backend. GitHub Pages may provide a suitable free public
option under its terms, but no host was chosen. Domain registration/renewal,
private hosting and resolver dependencies can cost money. No running service
was added; if later required, state its exact purpose/owner/cost first.
Bluesky ordinary users do not need developer accounts or personal metadata
hosting in the intended distributed app. Video account email verification and
account upload limits are additional per-user checks; no video availability is
promised. Default SDK identity resolution depends on public.api.bsky.app,
plc.directory and did:web documents; an optional resolver remains undecided.

## Exact published compatibility evidence

The isolated harness resolved and executed under Flutter3.50.0/Dart3.14.0.
At the P1 probe, the app lockfile and production dependency list were unchanged; P2 additions are recorded below.

| Package | Exact resolved candidate | License inspected |
| --- | --- | --- |
| atproto_oauth | 0.8.3 | BSD-3-Clause |
| atproto_core | 2.4.1 | BSD-3-Clause |
| bluesky | 2.18.0 | BSD-3-Clause |
| atproto_identity | 0.6.0 | BSD-3-Clause |
| atproto | 2.5.1 | BSD-3-Clause |
| bluesky_text | 1.8.0 | BSD-3-Clause |

The complete isolated graph is pinned in
app/test/fixtures/providers/sdk-probe.pubspec.lock. Relevant shared resolved
versions: characters1.4.1, crypto3.0.8, http1.6.0, pointycastle4.0.0,
freezed_annotation3.1.0, json_annotation4.12.0. Declared SDK range is
>=3.8.0<4.0.0. This demonstrates an isolated compatible solver/runtime graph,
not installing the packages into the app's complete graph or an Android build.
Candidate crypto uses the package's PointyCastleDPoPSigner (P-256/ES256); no
app crypto implementation or app-password fallback exists.

Exact pub.dev archive hashes, independently rechecked in Pub cache:

| Archive | SHA256 |
| --- | --- |
| atproto_oauth-0.8.3.tar.gz | c45b9de8a48adc12d273541c956c8fa45dae040eb963208e271073f9615196de |
| atproto_core-2.4.1.tar.gz | 03823235686c3ced51bbaf88bb54b4026be7708921f54200d5640fd8a6cdb42c |
| bluesky-2.18.0.tar.gz | bcc29aff5846115ddbb1b92f398bfe5e2f863c1031e6dfe96af6ce3cf096b533 |

The solver advertised bluesky2.18.1. Its exact published manifest and archive
CHANGELOG were inspected: same core^2.4.1/atproto^2.5.1/text^1.8.0 ranges;
regenerated ozone inbox/moderation/report lexicons, no OAuth fix claim. That is
not evidence of an OAuth acceptance fix; the candidate remains2.18.0.
Sources: https://pub.dev/api/packages/bluesky/versions/2.18.1 and
https://pub.dev/api/archives/bluesky-2.18.1.tar.gz (SHA256
908ce3acebf377a1d37d2ba179ba781be02e5268f5daea84f170401553835ed4).

## Executed local evidence

Run app/test/fixtures/providers/run-sdk-probe.ps1 from this repository. It
copies the tracked source fixture/pubspec/lock into ignored .tools/provider-probe
and executes a standalone Dart harness. Every HTTP endpoint and identity lookup
is fake/injected. No live sockets, browser, login, API cost or account operation
is part of the harness. Source is a .dart.txt fixture so Flutter's app analyzer
and test runner do not import unaccepted SDK dependencies.

`mock-tested` positives: real candidate package PAR challenge/retry; PKCE S256
challenge/verifier consistency; package-owned ES256 DPoP target/method and fresh
jti on retry; awaited state persistence before returning browser URL; serialized
JSON state restoration into a new client; awaited session persistence before
returning connection; actual Bluesky.fromOAuth API nonce challenge/retry;
concurrent refresh single-flight; awaited rotation persistence; serialized
rotated-session restoration; session-store failure rejects and consumes state;
wrong issuer/account reject before session persistence. JSON in-memory stores
prove ordering/serialization only, not encrypted OS storage or process death.

`mock-tested` defects/constraints: raw SDK accepts missing response nonce,
wrong callback scheme/path, Bearer token_type, different fetched client_id,
and concurrent callbacks exchanging the same state twice. Missing AS metadata
or an http.ClientException thrown by a rejecting AS transport still permits
PAR at guessed endpoints. Tests assert those observations deliberately; their
passing status is evidence of gaps, not passing protocol conformance.

The only candidate hardening code is an isolated HTTP NoncePolicy fixture.
It rejects DPoP responses with missing/empty nonce before the SDK receives them,
and is exercised on PAR, token and API success. It is not in app runtime and
is not an accepted complete OAuth adapter. No secure store or callback routing
was implemented in P1. Native cold/warm/cancel, real provider requests,
accounts/scopes/entitlements and publication remain `unavailable`.

## P3 acceptance handoff: precise boundaries

Source coordinates below refer to the exact atproto_oauth0.8.3 archive
https://pub.dev/api/archives/atproto_oauth-0.8.3.tar.gz, not repository main.

| Boundary and evidence | Maintained public enforcement point / smallest next proof |
| --- | --- |
| Mandatory DPoP nonce: oauth_client.dart _postWithDPoPProof:819-866 accepts absent nonce; core service_context.dart:710-728 does too. Mock reproduced; nonce-only transport candidate rejects. | OAuthClient.httpClient and Bluesky.getClient/postClient hooks can reject missing/empty case-insensitive DPoP-Nonce before response consumption. Apply the same bounded/no-redirect policy to every signed API path, test error/status/multipart paths and bounded nonce loops. No new signer needed. |
| Callback target/duplicate query values: callback:362-376 reads queryParameters and never compares exact target. Wrong scheme/path accepted in mock. | App callback entry wrapper checks exact registered scheme/host/port/path, no fragment, and queryParametersAll cardinality for state/code/iss/error before calling SDK. Test malformed, duplicates, unsolicited/wrong provider, cancellation, cold/warm callbacks. This is a feature-owned boundary, not a protocol fork. |
| Expiry/provenance/single-use: context lacks timestamp; callback find:378 then finally delete:466-468 permits concurrent exchange (mock reproduced). | Awaited OAuthStateStore.set/find/delete public hooks can store issuance time, configuration/client/redirect provenance and durable consumed/claimed state. Serialize and persist claim before returning context to the SDK; reject expired/consumed/disconnected flows. Test concurrent deliveries and restart after claim. An in-memory mutex alone is insufficient for crash/restart. |
| Client metadata binding: getClientMetadata:88-126 returns parsed foreign clientId (mock). | Fetch through strict transport and compare returned clientId string exactly to emitted canonical configuration before OAuthClient construction. Validate complete native metadata/declared scopes; no redirects, response bounds/timeouts. Test mismatch including equivalent-but-not-identical URL strings. |
| AS discovery: _discoverServerMetadata:711-741 catches Exception from transport and falls back; non200/nonJSON also guess paths. Mock proves policy exception swallowed. Metadata model drops mandatory flags. | A transport that only throws on bad discovery is insufficient. Prefer maintained strict-discovery SDK support; alternatively a narrow validated-document/endpoint admission policy must block every PAR/token request unless the exact bound issuer/document/required PAR/S256/DPoP/iss flags were accepted. Prove rejected discovery never emits authorization URL or signed/token request; handle refresh too. Do not rely on throwing an Error to evade SDK's catch. No such adapter accepted yet. |
| HTTPS/reserved networks/redirects: protected-resource fetch:915-917 uses client.get directly; identity resolver filters IP literals but not hostname DNS rebinding (source). | Inject strict native transport for *all* discovery/identity/OAuth/API paths: bounded responses/timeouts, no redirects/downgrades, resolved-address checks/pinning. Demonstrate malicious resource/AS redirects, private/reserved resolved hosts and DNS rebinding. A syntax-only AppConfiguration hostname check is not that transport. |
| Token type/raw fields: _buildSession:1071-1108 accepts Bearer/defaults absent type, refresh may supply old sub/scope; Bearer acceptance mock reproduced. | Validate raw token JSON in transport before SDK normalization (store hook cannot distinguish missing type after defaulting). Require DPoP, exact account/client/PDS/issuer and granted write scopes; repeat binding in awaited sessionStore.set. Test initial/refresh missing/reduced scope and missing/mismatched sub/type. No after-return-only validation: SDK already persists before callback returns. |
| Store failure/rotation: awaited sessionStore.set at463/591 and manager publication order are mock-positive. Default stores are memory only. | Implement explicit OS-backed secure async state/session stores, client/account namespaces, serialized writes and clear error handling. Delayed/failing native writes must block use; test restart after token rotation, invalid_grant and disconnect racing late completion. Never substitute unawaited broadcast persistence; never log sessions/keys/raw SDK errors. |
| Restore/logout: restore:657-667 trusts deserialized stored session; revoke deletes store but existing manager cache may survive. | Validate bound sensitive input during store.find, fence/dispose account manager and in-flight work on disconnect, reject late saves. Test timeout/rotation/disconnect races and revocation failure without leaking credentials. |
| Identity/scopes/media/account limits: mocked resolver intentionally bypasses network identity discovery; initial issuer/DID mismatch rejects. atproto is identity only. | Preserve SDK bidirectional handle/DID/PDS resolution through hardened transport; pin/test exact least-privilege text/photo/video permissions and per-account upload limits. No transition:generic shortcut, app passwords, unverified video duration or universal free-access assumption. |

The demonstrated nonce/callback/store boundaries have public hooks and do not
need a protocol fork. Strict discovery and end-to-end network admission remain
concrete maintenance/acceptance concerns; P3 must choose and test a narrow
maintained solution before enabling production connections. This task neither
rejects all SDK usage nor certifies the current candidate. Exact X OAuth/native
and weighted-text counter selection similarly remains unavailable until its
own focused implementation/conformance tests and genuine owner setup exist.

## P2 X connection implementation and remaining acceptance

The app now pins flutter_appauth13.0.0 (BSD-3-Clause),
flutter_secure_storage11.2.0 (BSD-3-Clause) and uses http1.6.0 directly.
FlutterAppAuth's published Android build declares net.openid:appauth:0.11.1
(Apache-2.0); the app declares that same native artifact for its receiver API.
Exact Pub archive hashes are in app/pubspec.lock. Package upgrades must recheck
the native/source boundaries below. This is Android-first implementation;
there is no iOS callback/storage acceptance evidence.

AppServices explicitly composes one XConnection with AppAuthXDriver,
SecureCredentialVault, LocalAccountRepository, clock and one owned http.Client.
The existing production ConnectionGate.available remains false even with valid
public build metadata. Neither a test fixture nor Android callback metadata
enables it. Accounts shows the actual setup/verification reason; drafting and
Instagram preparation remain independent. Public Connected metadata and direct
publishing capability are separate checks.

The X driver uses https://x.com/i/oauth2/authorize and
https://api.x.com/2/oauth2/token with tweet.read, tweet.write, users.read,
offline.access and media.write, without a client secret. Login/consent/MFA belong
to the external browser. Identity comes from a nonredirecting official
GET https://api.x.com/2/users/me; stable numeric subject and validated username
are bound into secure session material. Credentials are committed before public
Connected metadata. No callback URI, token or raw provider/native exception is
logged or interpolated by Caption's account code/UI.

Source inspection of the exact native AppAuth0.11.1 sources establishes:
AuthorizationRequest.Builder generates random state and code verifier;
CodeVerifierUtil derives S256 when SHA-256 exists. The native preflight requires
SHA-256, preventing its plain fallback. AuthorizationManagementActivity checks
state before returning successful code authorization. The default exported
RedirectUriReceiverActivity merely forwards the received URI. Caption replaces
that export with a private receiver and exposes XRedirectActivity, which checks
exact scheme/raw authority (including port)/raw path, no fragment, unambiguous
nonempty state and code-or-error query, pending lifetime (ten minutes) and one-use
consumption before forwarding into AppAuth. Query parameters remain available
to AppAuth. Wrong target/ambiguous query does not consume a valid pending flow.
The SDK still owns cryptographic state verification and token exchange.

The one public Flutter --dart-define=X_REDIRECT_URI value feeds both Dart and native
routing. The Android Gradle script selects that key from Flutter's existing
base64 dart-defines project value and rejects duplicate X_REDIRECT_URI definitions
with safe copy. It does not emit other defines or create a second setup setting.
The prepareXAuthorization bridge still compares the emitted Dart target with
native BuildConfig before any browser launch. Missing
native metadata disables XRedirectActivity; the default BuildConfig target is
empty and manifest scheme/host values are inert unconfigured markers, not release
registration. HTTPS filters have a configured host/path; custom-scheme filters
are narrowed by the receiver's runtime exact-target check. A claimed HTTPS app
link still needs genuine owner association/registration and device acceptance.
No release scheme, app identity or owner domain was selected. A process restart
loses Caption's pending callback guard and fails closed: the user reconnects.
Cold-process OAuth resumption is not claimed. Normal native activity recreation
and actual external-browser return/cancel still require device/provider tests.

Secure storage uses package RSA-OAEP key wrapping backed by Android Keystore and
AES-GCM ciphertext under fixed, separate caption_x_credentials and caption_bluesky_credentials
namespaces. Ordinary operations disable reset-on-error; unavailable secure storage
marks the public account repairRequired and requires explicit repair confirmation
before a fresh reconnect, while retaining drafts/results. Session JSON binds version1,
public client ID, exact redirect, stable identity, access/refresh tokens and expiry.
Public metadata alone lives in SQLite accounts (schema4).

The pinned package's FlutterSecureStorage.writeUnsafe calls Editor.apply and
returns before the disk write; the wrapped key and namespaced cipher config also
use preferences. Caption awaits its package write/delete, then invokes one
accounts-owned background commit barrier covering the three artifacts in that
affected provider namespace: FlutterSecureKeyStorage:<namespace>,
FlutterSecureStorageConfiguration:<namespace>, <namespace>. The native bridge
accepts only fixed x/bluesky destination values, never arbitrary namespace names.
Each empty editor.commit waits for preceding applies in that file and returns a
boolean; false/native failures become CredentialStorageFailure. This reuses
package encryption and Android's durability contract, without custom crypto.
Owning API29 source: android-10.0.0_r47 SharedPreferencesImpl.java, commit at
576-599 and enqueueDiskWrite at626-674; writes are serialized and the commit
awaits writtenToDiskLatch. Source URL:
https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r47/core/java/android/app/SharedPreferencesImpl.java
Both pre-31 backup rules and API31+ cloud/device-transfer rules exclude all
shared preferences; allowBackup=false also remains explicit. Keystore keys do
not migrate with ordinary application backup. Host channel mocks alone do not
prove physical OS persistence; native phase evidence belongs in task-13-report.

One XConnection serializes durable mutations, single-flights refresh and fences
network completions by generation. Disconnect increments the fence before
awaiting metadata clear and secure deletion, preventing late connect/refresh
resurrection. A rejected/revoked refresh expires the account; offline/timeout
retains its credentials and reports unavailable connectivity. Failed rotation
storage marks repairRequired and blocks healthy authorization until deliberate repair
and a fresh reconnect.
Changed subject invalidates the immutable reviewed account through the existing
ReviewService revalidation comparison. No content/results are deleted.

A specific acceptance gap remains: native AppAuth0.11.1
AuthorizationManagementActivity.java:353-357 logs both returned and expected
state on mismatch through its internal Logger. No supported public logging
control was found. Caption never exposes that exception text, but that does not
sanitize SDK logcat. Production availability remains false; debug live OAuth is
not privacy-accepted. R2 must validate a maintained log-safe SDK approach or
release-only R8 stripping plus artifact/device evidence before accepting that
boundary. This task does not use reflection, SDK test hooks or an SDK fork.
Registered callback/owner access and billing decisions, actual browser/MFA/cancel,
logcat privacy, release artifact routing and real account checks remain unresolved.

### P2 review fix: deliberate repair and durable removal

CredentialVault adds repair(Destination); AccountConnection adds
repairCredentials(). These are exceptional destructive operations called only
after the user confirms the provider-specific Accounts dialog. Reset never
reports Connected: it durably clears only that provider's secure session, leaves
public state disconnected, and requires a separate ordinary Connect action.
No raw SDK exception parsing is used to infer permission for deletion.

AccountState.repairRequired and removalPending are narrow durable metadata
states. Ordinary secure-storage errors mark repairRequired; a disconnect first
saves removalPending with identity cleared, then deletes credentials durably,
then saves disconnected. Both states block authorization and reconnect. Accounts
offers Retry removing <provider> after failure and on a fresh open, without
requiring sign-in; repair is also available if deletion cannot initialize the
broken key. Retrying deletion is idempotent. Explicit repair preserves an existing
removalPending intent on failure. SQLite schema remains 4: only additive enum
serialization changed; no old enum values were renamed. P3 must honor these
states, the explicit confirmation contract and the vault-wide operation queue.

Pinned native namespace evidence: FlutterSecureStorageConfig
getEffectiveDataPrefsName/getEffectiveKeyStoragePrefsName/getKeyAliasSuffix
scope data prefs, wrapped-key prefs and alias suffix to storageNamespace.
NamespacedConfigSource writes FlutterSecureStorageConfiguration:<namespace>.
KeyCipherImplementationRSAOAEP appends .<namespace> to the package's
FlutterSecureStoragePluginKeyOAEP alias. StorageCipherFactory passes that config
to the key/storage cipher, so repairing X cannot delete Bluesky's RSA alias,
wrapped key, config or ciphertext. No migration from the old unreleased shared
namespace is provided: the old synthetic session was explicitly deleted, and
production connections have never been enabled.

flutter_secure_storage 11.2.0 initialize() short-circuits when already initialized
and retains resetOnError. Explicit repair therefore uses the official Flutter
plugin detach/attach lifecycle around package deleteAll with resetOnError:true
and migrateOnAlgorithmChange:false. The accounts channel marshals only
FlutterSecureStoragePlugin removal/recreation to Android's UI thread. A private,
static SecureCredentialVault queue covers every package call across all vault
instances/providers, so none overlaps this cache boundary. The existing background
commit barrier awaits the affected namespace before success. A finally block
recreates the plugin again; ordinary calls then use resetOnError:false. If final
cache restoration fails, a shared in-memory guard blocks normal calls until a
successful explicit repair or process restart rather than allowing inherited
destructive configuration. Other providers' disk material remains intact; no
credentials are copied, logged or put in public metadata.

This lifecycle coupling should be removed when a maintained package exposes a
supported per-namespace reinitialization/reset API that restores non-destructive
configuration. Reinspect exact names/cache/reset semantics on package upgrades.
The real key-loss fixture and two-provider process-persistence evidence are in
task-13-report.md; synthetic test-only instrumentation is excluded from production.


## P3 bounded Bluesky implementation (production still unavailable)

P3 installs exact atproto_oauth **0.8.3**, atproto_core **2.4.1**, bluesky
**2.18.0** and flutter_web_auth_2 **5.1.0** in the application graph. The SDK
archive pins retain the earlier reviewed versions; the app lockfile records
all resolved archive hashes. The browser package supports the selected Dart /
Flutter versions and Android API 21+, below Caption's provisional API 29 floor.
Its Android code uses maintained AndroidX Auth Tabs / Custom Tabs. Its current
Kotlin Gradle Plugin application produces Flutter's future migration warning;
current Android compilation succeeds. This version coupling needs rechecking
on Flutter or plugin upgrades.

The controller explicitly selected a smaller supported account boundary for
this slice: **did:plc accounts hosted by Bluesky**. This supersedes P1's broad
arbitrary-federation transport requirement for this implementation. The official
[API directory](https://docs.bsky.app/docs/api-directory) lists the entryway as
`https://bsky.social` and PDS instances as
`https://<NAME>.<REGION>.host.bsky.network`. The app admits exactly two ordinary
DNS labels before `.host.bsky.network`, bare HTTPS origins, and exact issuer
`https://bsky.social`; it does not infer a broader `*.bsky.network` allowance.
Ordinary and custom handles are lookup inputs: the pinned official identity
resolver checks handle/DID association through fixed
`https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle` and
`https://plc.directory/<did:plc:...>` paths. It never fetches a custom handle's
website. did:web and custom PDS accounts receive a named unsupported message,
with the previous connection and drafts retained. Supporting additional DID
methods, issuers, PDSes or external video services requires a fresh policy
and acceptance decision.

Transport uses the app-owned native `http.Client` with ordinary certificate-
and hostname-validating TLS. No custom DNS resolver, reserved-address list,
address pinning or certificate override was implemented. The security
assumptions are OS trust and continued provider ownership of admitted domains;
a DNS response alone cannot authenticate a different service without a trusted
certificate for the admitted hostname. Owner-configured client metadata is
an unauthenticated HTTPS fetch at its single exact configured URL. Arbitrary
response endpoints cannot be admitted. This is a bounded native-client policy,
not a claim of general AT Protocol federation or DNS-pinning conformance.

All used SDK metadata, identity, OAuth and API HTTP paths pass the same
feature-owned admission policy. It disables redirects, rejects all 3xx,
requires HTTPS/default port/no user-info/no fragment, bounds connection/body
reads to 20 seconds each and response bodies to 512 KiB, and rejects signed
requests outside the bound account PDS or accepted PAR/token URLs. The driver
uses only public `OAuthClient` HTTP/resolver/store/nonce hooks,
`OAuthSessionManager.fromSession(client:, nonceCache:)` and
`Bluesky.fromOAuth(getClient:, postClient:)` hooks. There is no SDK fork,
protocol/crypto implementation, generic transport framework or password
fallback. SDK cryptography generates and signs the P-256/ES256 keys/proofs.

Client metadata must exactly bind its emitted client_id, sole configured
redirect, native application type, none token authentication, DPoP flag,
authorization_code/refresh_token grants and code response. Requested and granted
scopes are restricted to `atproto`,
`repo:app.bsky.feed.post?action=create`, `blob:image/*` and `blob:video/*`.
This permission selection does not enable video publishing or prove provider
scope grants/account limits; live acceptance remains outstanding.

Raw protected-resource metadata must match its bound resource PDS and the
sole supported issuer. Raw authorization-server metadata must declare that
exact issuer, required PAR, S256, ES256 DPoP, response issuer support, code,
none authentication and both grants. Authorization/PAR/token endpoints must
be distinct exact HTTPS URLs on that issuer origin. No PAR/token request is
admitted unless this raw document was accepted; rejected/absent/throwing
metadata leaves admission closed even though OAuth0.8.3 swallows discovery
exceptions and tries guessed endpoint paths. Refresh repeats discovery under
the same policy. Raw successful token JSON is checked before SDK normalization:
explicit DPoP type, exact expected DID, complete allowed scopes, nonempty access
token, positive expiry and matching optional client_id/iss fields. SDK context
and awaited session persistence repeat DID/client/issuer/PDS binding.

Every response to a DPoP request requires a nonempty case-insensitive
DPoP-Nonce before the SDK consumes it, including PAR, token, API GET, JSON
procedure, binary upload and error paths. Header names are normalized when
forwarded to the SDK; originating request metadata is preserved for SDK
challenge/error construction. The transport awaits nonce persistence before
returning any signed response. The SDK receives a nonce-cache adapter that
reads this persisted value and treats its additional set notifications as
already committed; this prevents its fire-and-forget success callback from
starting late secure writes. Nonces expire locally after five minutes. SDK
challenge loops remain bounded; ordinary transient retries are disabled and an
ambiguous create failure is never automatically resent.

BlueskyConnection owns one SDK manager and a feature-local serial mutation
queue. A single opaque versioned envelope in CredentialVault's existing fixed
Bluesky namespace holds session, private DPoP/PKCE material, per-origin nonces,
pending state timestamps/claim and public identity/configuration provenance.
Every package access still goes through SecureCredentialVault's shared queue;
P3 does not directly use FlutterSecureStorage or extend its native repair API.
Only public AccountView JSON enters SQLite. State claims are durably committed
before returning SDK context. The SDK's awaited sessionStore.set is the durable
refresh authority before manager publication; onSessionUpdated is not used as
an unawaited persistence mechanism. Secure errors expose repairRequired and
invalidate cached clients; removal first records removalPending and remains
retryable after restart. Explicit repair uses the existing confirmed Accounts
action and keeps fresh connection separate. Disconnect fences late HTTP,
callback, nonce/session writes and clients already acquired by a provider
adapter. The adapter must supply its immutable reviewed DID to authorizedClient.

FlutterWebAuth2 is composed explicitly with the connection in AppServices;
there is one owned HTTP lifetime. Its Android CallbackActivity is a scheme
receiver; exact target/no-fragment/query-cardinality/issuer and durable state
checks happen in Dart before SDK exchange. BLUESKY_CALLBACK_SCHEME feeds Dart,
Gradle and the native redirect preflight through the existing Flutter define
source. The default receiver is disabled with an inert unconfigured scheme.
This does not register ownership of a callback. Pending browser flows cancel
on process loss: the plugin's process callback and connection's in-memory
state admission are not restored. A subsequent authorization or usable session
restore removes stale pending keys; there is no cold-process browser resumption
promise; Caption schedules no automatic authorization retry or send. Browser cancel preserves prior account
metadata/session. All UI errors use fixed safe copy; SDK/raw callback failures
are never interpolated.

Production availability remains **false**, including before metadata fetch or
browser launch. No metadata/domain was selected, published or registered, no
account was logged in, and no provider post/upload or paid service was used.
Reserved example.com build values verify compilation only. Actual owned
metadata, callback association, warm/cold/cancel/MFA behavior, account/scopes,
release logging/privacy, native visual/TalkBack and iOS acceptance remain
unverified. P2's AppAuth state-logging gate remains independently unresolved.
