# Bluesky protocol fixture provenance

These responses are synthetic, sanitized fixtures, never live provider evidence.
The harness runs the real pinned OAuth/DPoP, XRPC, lexicon, rich-text, TID and
DAG-CBOR/CID SDK code against fake HTTP and real temporary owned files/SQLite.
`protocol.json` supplies the stable video job identity; the record TID is generated
by the SDK and the harness captures and checks the exact durable identity.

Application pins remain bluesky 2.18.0, atproto_core 2.4.1 and atproto_oauth 0.8.3.
Existing graph packages bluesky_text 1.8.0 and at_primitives 1.2.0 are declared
directly for their public helpers; no package version is upgraded.

## Exact contracts used

- feed.post requires `key:tid`, exact original text <=300 graphemes and <=3000
  UTF-8 bytes. `characters` counts graphemes. Invalid UTF-16 is rejected before
  it could become replacement text. Empty text is valid with an embed.
- `BlueskyText(original, enableMarkdown:false).entities.toFacetsResult(resolver:)`
  extracts offsets into the original UTF-8. Never call format/buildPostText here:
  the reviewed caption must not change. Handle lookups use the bound SDK
  `com.atproto.identity.resolveHandle`; unresolved handles have no mention facet.
  Review always warns conditionally when SDK-detected handles are present. It
  does not certify resolution before publication and never presents plain
  unresolved text as a mention notification.
- `FeedPostRecord`, `UFeedPostEmbed`, `EmbedImages`/`EmbedImagesImage`, `EmbedVideo`
  and `RichtextFacet` are SDK models. Ordered photos retain their exact alt text.
- createRecord supports caller-supplied rkey/repo/collection. `TidGenerator` and
  `isValidTid` come from the already pinned maintained SDK graph.
  `computeRecordCid` owns canonical DAG-CBOR and CID construction. Persistence
  contains the exact encoded record, source fingerprint and identity before
  markDispatch; create uses that identity and no transient retries.
- getRecord on that exact repo/collection/rkey confirms only if URI, CID and full
  canonical returned value match. Missing or different records stay Unknown.
  A success receipt with error fields stays Unknown. No fuzzy search exists.
- Only documented code/status pairs settle a dispatched rejection:
  InvalidSwap/400, InvalidRequest/400, AuthenticationRequired/401 and
  RateLimitExceeded/429. Other failure envelopes, transport loss, missing fields
  and 5xx remain uncertain after dispatch.

## Video scope and SDK discrepancy

Approved added permissions are `account:email?action=read`,
`rpc:app.bsky.video.getUploadLimits?aud=*` and
`rpc:com.atproto.repo.uploadBlob?aud=*`. Wildcard audiences grant broader
**delegation** than an exact audience. They are used because the hosted PDS
varies by account and current permission syntax requires DID service fragments
while the documented guide/pinned helpers use bare did:web audiences. This is
not an exact-audience grant or evidence of live scope acceptance. Runtime
getServiceAuth admission permits only (getUploadLimits, did:web:video.bsky.app)
and (uploadBlob, did:web:<bound hosted PDS>). Revisit these permissions before
production connection enablement if video is omitted.

Email confirmation is checked in memory through getSession with the frozen DID;
private email is never put in uploadState. Limits use a scoped service token.
Upload uses a second scoped service token. Neither service token is persisted;
only the exact minted endpoint token is admitted at https://video.bsky.app.
OAuth tokens/proofs never go there. Job status is a fixed unsigned SDK GET
through the same bounded/fenced transport. No arbitrary service bypass exists.

The current official uploadVideo lexicon requires `{jobStatus:{...}}` (retained
p5-video_upload.txt:15-21), but the official guide example casts the upload body
to bare JobStatus, and pinned bluesky codegen video_service.dart:151-163 also
decodes bare JobStatus. The exact upload endpoint normalizes a successful wrapper
to the pinned model shape after SDK model/DID/job/blob checks. The bare success
shape remains supported. Malformed, mixed error/envelope and non-2xx bodies are
never converted to success. This bounded compatibility handling is not live
conformance evidence. The official guide's `already_exists` plus valid matching
blob may become preparation-ready; processing/upload alone is never Published.

Check never uploads, sets metadata or creates a post. It can save job state and
return processing/local `preparation-ready`. Only explicit coordinator
continuation, after renewed validation and an exclusive atomic claim, calls
send. Unknown attempts have no ordinary retry. A safe failed new child starts
with empty provider state and a fresh TID, never the parent's record/dispatch
marker. Live codec, account entitlement/grants and numeric duration acceptance
remain unavailable. Production profiles remain unavailable, including video.

## Retained official source captures

Read 2026-11-17. Raw documents live in ignored `.tools/provider-probe/p5-*`.
The following SHA-256 values pin the exact inspected bytes. They are source
provenance, not proof of provider behavior. Current video size is 300,000,000
bytes; no authoritative numeric duration limit was established. The synthetic
fixture uses tiny fake MP4 bytes and explicit SYNTHETIC-only capabilities.

| Capture | Official source | SHA-256 |
| --- | --- | --- |
| post | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/feed/post.json | 383935b9d8425c7a4be904da95e6ab5e94ceb5d07e073c0eb8f7d39213525ce4 |
| images | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/images.json | 06491ead4a1bec37271a517d3c8ff2baa47ab5996d25819df471a6f68dd5d912 |
| video_embed | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/video.json | 789e2da1d249e7a05237885edf359387b8dcb863e007d5562a9a4166f70f1a31 |
| video_upload | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/uploadVideo.json | 751e4253cfb8ca7dbc095eadc1a31ee459ad272086bdc5c10bca18df1dec7900 |
| video_status | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/getJobStatus.json | 90437bacf987fe8e9d1446021fbdeefdb19c93d5126cd1eb0b592a794ed0c82b |
| video_defs | https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/video/defs.json | 4488b23aab25f7388c54c9d98b8c7406eccb458cb78e031820b4e3fe0847c8ba |
| create | https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/com/atproto/repo/createRecord.json | 33280437597bf6dd8232a8ebd1b001a151e9b52817f9812abe1b505b0b192dac |
| get | https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/com/atproto/repo/getRecord.json | d61aee451f284dd251b3451d16826e75f2bf8a6af32705120e1f67a3db4df8ff |
| session | https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/com/atproto/server/getSession.json | 506d84a1d66206ed35505402824dfae8fc2e106cd88cbed1652954506e413eb9 |
| serviceauth | https://raw.githubusercontent.com/bluesky-social/atproto/main/lexicons/com/atproto/server/getServiceAuth.json | 3a623f89b9d7dc39f7a13a10e13e797cd12ee97ea2a08f793e30ff6aeb1ee3d0 |
| video | https://docs.bsky.app/docs/about-bluesky-content/video | 33bdacee7703963dd8b095b19e1d09dd475bb72898b740be72948a298f910877 |
| permissions | https://atproto.com/specs/permission | 030d7c51f6b6000c02962e191aeb5f4dcbd730375f2fb1dcad99851d2a682b2d |
| xrpc | https://atproto.com/specs/xrpc | a330a4d82d671c1aab4d10bc157e2bb844d2c311bbe59151170697208934edd7 |
| xrpc-types | https://raw.githubusercontent.com/bluesky-social/atproto/main/packages/xrpc/src/types.ts | 5bc6dc05cff41bc24c2146c3b04d4e03b31db28514b1d58907c510bbc918f141 |
