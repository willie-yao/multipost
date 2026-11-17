# Provider feasibility gates

Recorded 2026-11-16 (America/Los_Angeles). X and Bluesky direct connections
and publishing are **unavailable in this build**. Local drafting and Instagram
JPEG/PNG photo preparation remain independent. No account, app registration,
billing, hosted metadata, live upload/post, or native provider callback was used.

Evidence levels: `documented` means official documentation or exact published
source inspection; `mock-tested` means the specific synthetic checks described
in [OAuth configuration](oauth-configuration.md); `device-tested` requires a
recorded native device run; `unavailable` is unresolved. Documentary limits are
not live acceptance. Every matrix row below was accessed 2026-11-16 in the prior
official-source audit, reused here; P1 directly re-fetched the AT OAuth spec,
Bluesky post/images schemas and X counting page on the same local date.
The inspected package releases and mock conclusions are recorded separately.

The app owner must decide X developer/billing ownership, public native app and
registered callback, and Bluesky public HTTPS metadata/domain ownership and
native callback. No product identity or hosting choice is made here. Ordinary
users should install and authorize an account, not create developer accounts.
If X's selected access arrangement requires each user to register/pay, return
that burden for product review before calling install/connect supported.

## X evidence matrix

All sources were accessed 2026-11-16. Source keys resolve to exact URLs below.

| Area | Evidence and implementation constraint | Sources | Level |
| --- | --- | --- | --- |
| Native OAuth | Native App is a public client; no client secret. Authorization code + PKCE supported; choose S256 even though X also advertises plain. Enable OAuth 2.0 in owner's app settings. Public client sends client_id in token request body. | X1 | documented |
| Callback | redirect_uri must exactly match a registered callback. App must validate received target, random per-flow state, PKCE verifier, pending-flow expiry and one-use semantics. Exact proposed custom scheme acceptance in actual X console and Android/iOS handoff remain untested; inspected X page establishes Native App support and exact matching, not every platform's scheme behavior. | X1 | documented requirements; actual callback unavailable |
| Scope and identity | POST /2/tweets requires tweet.read, users.read, tweet.write; GET /2/users/me requires users.read and tweet.read; media upload requires media.write. Add offline.access for refresh tokens. GET /2/users/me provides stable numeric account ID; bind publishing to that ID, not mutable username or app owner's account. | X1-X4 | documented |
| Tokens | Access tokens default to two hours. offline.access causes refresh token issuance. Persist refreshed credentials securely before requests proceed. Native plugin, state persistence and refresh serialization remain to be implemented/tested; no token or verifier should be logged. | X1 | documented; integration unavailable |
| Text | Ordinary profile max 280 weighted units, not Dart String.length, runes.length, or grapheme count. NFC normalization; recognized emoji sequences weight 2, most Latin/common symbols 1, CJK/default ranges 2; detected URLs count 23. Premium longer-text entitlement exists but a generic maximum is not established here: keep conservative 280 profile. | X2, X8, XT1-XT4 | documented |
| Photos | Up to four photos/Post. POST https://api.x.com/2/media/upload with raw multipart or encoded media; tweet_image category. Attach returned IDs in media.media_ids at create, order significant. Image formats JPG, PNG, GIF, WEBP, at most 5 MB. Animated GIF is a separate one-item mode. | X2, X4-X5 | documented |
| Photo limits | Docs say 5 MB without exact numeric byte boundary. A 5,000,000-byte ceiling is a conservative **app restriction**, not proven precise provider maximum. No strict still-photo dimension/aspect limit established here. Preserve source distinctions instead of inventing limits. | X5 | documented wording; exact boundary unavailable |
| Accessibility | POST /2/media/metadata supports alt_text; inspected schema maxLength 1000 for text. Resolve Unicode length semantics before exact production counter. Confirm upload/metadata route and permissions in fake tests. | X9 | documented schema; counting details unavailable |
| Video | One video/Post; v2 initialize/append/finalize/status then POST /2/tweets after processing. POST /2/media/upload/initialize; POST /2/media/upload/{id}/append; POST /2/media/upload/{id}/finalize; GET /2/media/upload?command=STATUS&media_id=... . **Do not copy old command=INIT/APPEND/FINALIZE protocol into v2.** | X2, X5-X6 | documented |
| Processing | pending -> in_progress -> succeeded or failed. Respect check_after_secs and expires_after_secs. Use segments <=5 MB per guide (guide says server max 8 MB). A successful finalize may still fail Post create. Publication requires confirmed post creation. | X6 | documented |
| Video entitlement | Current docs: default Post video 0.5 seconds-20 minutes, 8 GB; Premium/verified 0.5 seconds-125 minutes, 16 GB. Limits follow posting user/media_category, not developer API plan. This differs from legacy 140-second/512-MB assumptions. Smaller app limits are permissible if labeled. Reliable entitlement detection and precise binary/decimal size interpretation not verified. | X2, X5-X6 | documented; account verification unavailable |
| Video format | Docs recommend H264 High Profile/AAC LC. Advanced requirements include <=60 fps, 32x32 through 1280x1024, aspect 1:3 through 3:1, square pixels, YUV 4:2:0, progressive, no open GOP, mono/stereo AAC LC. Same page recommends portrait 720x1280 and says Premium supports 1080p: **dimension guidance internally inconsistent**. Do not turn contradictory recommendations into falsely verified universal gate. | X5 | documented conflict; exact profile unavailable |
| Errors/limits | Handle 400 invalid input, 401 auth, 403 permission/entitlement, 404 missing resource, 429 rate/usage limits, 5xx transient failures. Post create may return 403 with user video duration cap after media success. Read x-rate-limit-limit/remaining/reset; app/user budgets differ and change. | X5-X7, X10 | documented |
| Idempotency | No client-supplied idempotency key or caller-selected post ID found in inspected Create Post operation. This is absence in inspected docs, not proof no future mechanism exists. Timeout after sending create leaves unknown outcome: retain operation/account/payload metadata, attempt appropriate read reconciliation, avoid automatically issuing second create. Generic advice to retry 5xx must be qualified for writes. Timeline/content/time matching can be ambiguous. | X2, X7 | documented operation; guaranteed reconciliation unavailable |
| Cost/owner | Current pricing: pay per usage with prepaid console credits, no subscriptions/minimum spend stated. Post Create $0.015/request; with URL $0.200/request; User Read $0.010/resource; Media Metadata $0.005/request. Full media-flow charges not established; console/current rates govern and can change. Billing ownership/budget/distribution/abuse handling need product decision. Normal users should authorize product app; do not silently require each user to create/pay for a developer app. | X11 | documented prices; project billing unavailable |
| Hosting | Native public OAuth does not require token-holding backend. Callback choice might introduce claimed-HTTPS association/static files; inspect selected native library/platform setup before promising no hosting. No service provisioned. | X1 | documented architecture; selected setup unavailable |

## AT Protocol / Bluesky evidence matrix

Accessed 2026-11-16. Authoritative OAuth spec is on atproto.com. Bluesky docs routes moved; working URLs below. Official atproto README now points to bluesky-social/bsky for canonical app.bsky schemas; old app.bsky raw paths in bluesky-social/atproto return 404.

| Area | Evidence and implementation constraint | Sources | Level |
| --- | --- | --- | --- |
| Native OAuth | Public native clients supported. Mandatory authorization code, PKCE S256 (plain forbidden), PAR, DPoP ES256, issuer validation/account identity verification. No shared client_secret. Tokens opaque, not app-decoded JWT identity claims. | B1-B2 | documented |
| Metadata | client_id public HTTPS URL with no port; metadata returns HTTP 200 (no redirect)/application/json. client_id inside JSON exactly equals fetch URL. application_type native; grant_types authorization_code/refresh_token; response_types code; atproto in scope; dpop_bound_access_tokens true; public client token_endpoint_auth_method none. All potentially requested scopes declared. SDK model has relevant fields. | B1; SDK1 | documented |
| Callback | Custom scheme must match metadata hostname in reverse-domain order; use **single colon + single slash**, e.g. metadata app.example.com -> com.example.app:/callback. Arbitrary product-name://callback is not documented rule. Claimed HTTPS native redirect must share origin with client_id. Bind OS routing/exact target to chosen owner/domain and test cold/warm starts. | B1 | documented; device behavior unavailable |
| Owner/cost | Owner-controlled static HTTPS JSON hosting required even without backend. Domain owner, public metadata location, allowed native scheme, publication decision pending. Optional GitHub Pages supports public repos on GitHub Free; no host chosen/published. Verify 200/application/json/no redirect and hosting terms. Domain renewal/private hosting may add cost. | B1; H1 | documented options; decision unavailable |
| Identity | Handle -> DID bidirectionally checked against DID doc; DID -> authoritative PDS -> authorization server; token sub must equal expected DID. Both did:plc/did:web. DID stable primary identity. SDK default delegates handle resolution to public.api.bsky.app, fetches PLC directory or did:web doc, verifies handle/PDS links. External resolver dependency, not app-owned backend. | B1; SDK1, SDK4 | documented/source inspected |
| Scopes | atproto alone proves identity, not publication permission. Fine-grained spec supports repo/blob/rpc service-auth permissions. Candidate text permission repo:app.bsky.feed.post?action=create; photos need suitable blob permission. Preprocessed video needs exact getServiceAuth/delegation/RPC audience grants. SDK sends metadata.scope; does not choose least privilege. Final photo/video scope string and cross-PDS support **unavailable until verified**. Do not copy broad transition:generic from old snippets without review. | B1, B3, B6; SDK1 | documented syntax; final permission profile unavailable |
| Text | feed.post requires <=300 grapheme clusters AND <=3000 UTF-8 bytes. Text may be empty with embeds. Links/mentions facets use UTF-8 offsets, not X fixed 23 units. Large combining sequence can pass graphemes yet fail bytes. | B4, B8-B9; U1-U2 | documented |
| Photos | embed.images up to 4 images; maxSize 2,000,000 bytes each; accept image/*. image and alt string required; aspectRatio schema optional, guides recommend it; positive width/height integers. uploadBlob on user's PDS returns references for createRecord embed. Strip private image metadata. Explicit JPEG/PNG/WebP app subset reasonable; image/* schema does not prove all formats decode/display. | B4-B5, B7 | documented; concrete format/device support unavailable |
| Video limits | Current embed.video accepts video/mp4 maxSize **300,000,000 bytes**, formerly 100 MB. Numeric duration maximum absent in inspected embed/video/startUpload schemas and official guide. Search summary claimed ten minutes with only third-party citations, **not accepted as official evidence**. Keep video unavailable until authoritative duration/profile pinned. | B6, B10-B11 | documented size; duration unavailable |
| Account/PDS limits | Bluesky-hosted account needs verified email per guide. getUploadLimits exposes canUpload plus optional remainingDailyVideos/remainingDailyBytes/message/error; no universal daily count. Current rate-limit page states general PDS uploadBlob max 52,428,800 bytes, lower than embed video max. Direct uploadBlob alone cannot promise all 300-MB video input. | B6, B12-B13 | documented; OAuth email-check route/account limits unavailable |
| Video flow | Guide recommends service preprocessing: PDS-issued service auth audience PDS DID/lxm com.atproto.repo.uploadBlob, upload MP4 to video.bsky.app, poll getJobStatus until blob exists, then create post. It recommends 30-minute delegation. Use service token only for intended audience; do not send PDS DPoP token to arbitrary host. already_exists may include reusable blob; inspect blob even on job error. Direct uploadBlob starts processing after publication, showing missing video temporarily. | B6, B10, B14 | documented; permissions/roundtrip unavailable |
| Multipart route | Canonical startUpload/uploadPart/finishUpload/getUploadStatus/abortUpload exist; SDK 2.18.0 exposes them. startUpload exact size; duration/dimensions advisory; probe async. finishUpload/uploadPart described as idempotent; completedJobId may differ on deduplication. Choose/test one full route; old guide does not fully describe current multipart APIs. | B11, B15; SDK3 | documented/source inspected; integration unavailable |
| Processing/errors | States include created/encoding/encoded/scanning/scanned/uploading/uploaded/completed/failed; unknown states mean processing. failureCode values validation_failure, encoding_failure, pds_upload_failure, pds_upload_unsupported_blob_size, generic_failure. startUpload errors UnsupportedContentType, VideoTooLarge, VideoTooLong, BadAspectRatio, DailyLimitExceeded, TooManyOpenUploads, UploadForbidden, ServiceOverloaded. Bounded polling; publication requires confirmed createRecord. | B11, B14 | documented |
| Reconciliation | createRecord optional rkey, returns uri/cid. Proposed: persist valid TID key and exact record/account before dispatch, reconcile getRecord at repo/collection/key after ambiguous failure. Do not let convenience post generate fresh rkey per retry. Compare stored record/content reference, not mere existence. Documented primitives, not tested app behavior. | B16; SDK2-SDK3 | documented primitives; app behavior unavailable |
| Rate/cost | Bluesky-operated PDS: 5000 write points/hour, 35000/day; create=3, update=2, delete=1; overall API 3000/5min/IP. Other providers differ; 429/headers matter. Inspected docs no per-call charge for ordinary flow, **not contractual universal zero cost**. Hosting/optional resolver costs depend on owner choice. | B13; H1 | documented limits; universal cost unavailable |

## Exact source catalog

All sources directly accessed **2026-11-16**. Mutable branches should be pinned to immutable commits in later implementation evidence; no Git history/repository changed here.

### X and standards

- X1: https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code.md
- X2: https://docs.x.com/x-api/posts/create-post.md
- X3: https://docs.x.com/x-api/users/get-my-user.md
- X4: https://docs.x.com/x-api/media/upload-media.md
- X5: https://docs.x.com/x-api/media/quickstart/best-practices.md
- X6: https://docs.x.com/x-api/media/quickstart/media-upload-chunked.md
- X7: https://docs.x.com/x-api/fundamentals/response-codes-and-errors.md
- X8: https://docs.x.com/fundamentals/counting-characters.md
- X9: https://docs.x.com/x-api/media/create-media-metadata.md
- X10: https://docs.x.com/x-api/fundamentals/rate-limits.md
- X11: https://docs.x.com/x-api/getting-started/pricing.md
- XT1: https://raw.githubusercontent.com/twitter/twitter-text/master/config/v3.json
- XT2: https://raw.githubusercontent.com/twitter/twitter-text/master/js/src/parseTweet.js
- XT3: https://raw.githubusercontent.com/twitter/twitter-text/master/conformance/validate.yml
- XT4: https://raw.githubusercontent.com/twitter/twitter-text/master/conformance/README.md
- XT5: https://raw.githubusercontent.com/twitter/twitter-text/master/conformance/tlds.yml
- U1: https://www.unicode.org/reports/tr29/
- U2: https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakTest.txt
- H1: https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages

### AT Protocol and Bluesky

- B1: https://atproto.com/specs/oauth
- B2: https://docs.bsky.app/docs/oauth-client
- B3: https://atproto.com/specs/permission
- B4: https://docs.bsky.app/docs/bluesky-api/creating-a-post
- B5: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/images.json
- B6: https://docs.bsky.app/docs/about-bluesky-content/video
- B7: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/defs.json
- B8: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/feed/post.json
- B9: https://atproto.com/specs/lexicon
- B10: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/video.json
- B11: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/startUpload.json
- B12: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/getUploadLimits.json
- B13: https://docs.bsky.app/docs/rate-limits
- B14: https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/defs.json
- B15: SDK3 exact archive lib/src/services/codegen/app/bsky/video_service.dart (multipart/idempotence comments inspected); canonical sibling uploadPart/finishUpload schemas not independently fetched
- B16: https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/com/atproto/repo/createRecord.json
- B17: https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/README.md (canonical namespace owner)

### Exact published SDK artifacts

- SDK1 manifest: https://pub.dev/api/packages/atproto_oauth/versions/0.8.3
- SDK1 source: https://pub.dev/api/archives/atproto_oauth-0.8.3.tar.gz
- SDK2 manifest: https://pub.dev/api/packages/atproto_core/versions/2.4.1
- SDK2 source: https://pub.dev/api/archives/atproto_core-2.4.1.tar.gz
- SDK3 manifest: https://pub.dev/api/packages/bluesky/versions/2.18.0
- SDK3 source: https://pub.dev/api/archives/bluesky-2.18.0.tar.gz
- SDK4 manifest: https://pub.dev/api/packages/atproto_identity (latest 0.6.0 at access)
- SDK4 source: https://pub.dev/api/archives/atproto_identity-0.6.0.tar.gz
- SDK5 manifest: https://pub.dev/api/packages/atproto/versions/2.5.1
- SDK6 manifest: https://pub.dev/api/packages/bluesky_text/versions/1.8.0

Discovery limitations: search summaries supplied stale/broken schema paths, invented OAuth doc paths, unverified ten-minute duration. Those summaries were not used as official evidence. Old docs.bsky.app tutorial URLs returned HTML meta redirects, followed to working URLs above. api.github.com later returned unauthenticated rate-limit 403; canonical raw sources remained accessible. Guessed JSON OpenAPI paths were not treated as schemas.

P2 implementation update: the account service, production AppAuth adapter,
Keystore-backed vault with an awaited native disk barrier, public schema4 account
metadata and X-only callback guard are implemented. Synthetic unit/channel/native
checks are reported separately in task-13-report.md and OAuth configuration's P2
section. They do not change the unavailable direct capability gate. In particular,
AppAuth0.11.1 logs state values on mismatch; registered browser return and privacy
acceptance remain unresolved. No live connection or API request was performed.

## P5 local implementation evidence (2026-11-17)

The pinned official SDK path now has synthetic HTTP coverage for exact original
text/facets, ordered images/alt, source-backed video preprocessing/prerequisites,
record TID/CID persistence and exact same-record reconciliation. Current
production capabilities remain unavailable; video remains disabled because
numeric duration, live scopes/entitlement, codec and actual format evidence are
unverified. The current video upload lexicon wraps jobStatus while the official
guide/pinned SDK use bare JobStatus; the exact endpoint supports both proven
success shapes through a small SDK-validated adapter and rejects mixed/error
or malformed envelopes. Source captures/hashes and actual public hooks are in
app/test/fixtures/providers/bluesky/README.md and the P5 OAuth addendum above.
No provider login/upload/post or hosting operation was performed.
