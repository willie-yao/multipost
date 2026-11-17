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
The app lockfile and production dependency list are unchanged.

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
