# X parser and synthetic protocol evidence

Recorded 2026-11-17. These fixtures contain public conformance strings and
invented protocol IDs only. They are not captures of accounts or live posts.

## Exact official parser

- Maven: `com.twitter.twittertext:twitter-text:3.1.0`, binary 59,102 bytes;
  [published POM](https://repo.maven.apache.org/maven2/com/twitter/twittertext/twitter-text/3.1.0/twitter-text-3.1.0.pom).
- Binary SHA-256: `b454e20d4cdf89659d7837cba549909af1c7e4d3f3a53064285984ea8d3b9734`.
- [Published sources](https://repo.maven.apache.org/maven2/com/twitter/twittertext/twitter-text/3.1.0/twitter-text-3.1.0-sources.jar)
  SHA-256: `8b92848747904b492e319e64a7fa65d929595ff2aafc398dbd6c298ebfde8983`.
- POM SHA-256: `5d813c7756dcacb522b7c43b8a9005f067862924ca9a4061e4f3fed821238fe5`.
- Official release tag `v3.1.0` resolved with `git ls-remote` to
  `65e7e00da383fb77f5ab7fe3c0dc26b724e14035`.
- [Pinned Java README](https://raw.githubusercontent.com/twitter/twitter-text/65e7e00da383fb77f5ab7fe3c0dc26b724e14035/java/README.md)
  specifies this artifact and `TwitterTextParser.parseTweet(String)` with
  `weightedLength` and `isValid`. Source uses NFC internally; the adapter never
  replaces the reviewed caption with normalized text.
- Published POM declares Java 7 source/target, Apache 2.0, and only runtime
  dependency `com.google.code.findbugs:jsr305:2.0.1`. Its exact resolved POM also
  declares Apache 2.0. JUnit/Jackson dependencies are test scoped. No JS runtime
  or ICU is added. Normalizer/regex support is available at Android API 29;
  Android compilation/D8 and JVM checks are separate from device acceptance.
- The upstream license is packaged under Android `assets/licenses/` with an
  attribution notice. No upstream algorithm was modified or ported.

`weighted-v3.tsv` is an exact extraction of all **22** cases in
`tests.WeightedTweetsWithDiscountedEmojiCounterTest` in
[the pinned official validate.yml](https://raw.githubusercontent.com/twitter/twitter-text/65e7e00da383fb77f5ab7fe3c0dc26b724e14035/conformance/validate.yml).
Original YAML SHA-256:
`29fa1be663676f3d0bb0a67f393b32c15d92c5dd10db9be401bf7708d7c5b703`.
Each row is `base64(UTF-8 exact text) TAB weightedLength TAB valid`; this lossless
encoding lets the JVM test consume official strings without adding a test YAML
or JSON library to the Android graph. Extraction used the existing Dart yaml
reader in an ignored script; it did not calculate expected counts. The JVM test
calls the production wrapper and real Maven parser for every case, checking
both count and validity. Cases cover Latin, CJK, NFC, URL detection/domain bounds,
ZWJ family, modifiers, emoji versions and over-limit invalidity. A second JVM
check verifies forbidden U+FFFF, empty invalidity and decomposed NFC count.
Dart channel tests prove the one-call transport and blocking failure behavior;
they are **not** counted as actual parser/conformance execution.

## Official v2 protocol

The following owning Markdown/OpenAPI pages were fetched directly on the date
above. All returned OpenAPI version `2.175`. These mutable documents are pinned
here by accessed content hashes, rather than represented as immutable URLs.

| Page under `https://docs.x.com/x-api/` | SHA-256 of fetched Markdown |
| --- | --- |
| `media/upload-media.md` | `ed8a46e283bfe92aa49c434fdaa7040ad7b5d0eacbc50a1fc14709afe4727645` |
| `media/initialize-media-upload.md` | `6321d353053dfb6fc0636667bbaf07deb006516330271b99b3bd2f22323a7379` |
| `media/append-media-upload.md` | `d2d6094877641da291ad82a8bce2aaf64ac7c999fc653b7045f6259e6b806c6a` |
| `media/finalize-media-upload.md` | `afa8f86256dabe668d943f6adbb3008a379685163b7409ffca22801f8b6ad0c0` |
| `media/get-media-upload-status.md` | `8dbedd65995440a08eadf952b664f97060b4e2285df2771f9c879f77de4067b1` |
| `media/create-media-metadata.md` | `e88c7955574f7e57ee041197ee5581af3f756e93e7df442f87c837e57930633a` |

Protocol fixtures in `protocol.json` feed the synthetic HTTP fixture transport.
The implementation uses only fixed `https://api.x.com` endpoints:

1. Still photos use raw multipart `POST /2/media/upload`, `media_category` of
   `tweet_image` and a streamed owned `media` file. The exact simple-upload
   schema permits only `media`, `media_category` and optional `additional_owners`
   (`additionalProperties:false`); this app sends no additional owners and no
   `media_type` field. The wire regression checks the exact two-part body.
2. MP4 uses JSON `POST /2/media/upload/initialize` with `total_bytes`, `media_type`
   and `tweet_video`; raw multipart `POST /2/media/upload/{id}/append` uses
   zero-based `segment_index` and at most 5,000,000 bytes per segment, below the
   documented 8 MB raw limit; JSON-free `POST /2/media/upload/{id}/finalize`.
   No old v1 `command=INIT/APPEND/FINALIZE` protocol is used in v2.
3. Processing checks use `GET /2/media/upload?command=STATUS&media_id={id}`.
   `data.processing_info.state` pending/in_progress remains processing; unknown
   states also remain processing. `check_after_secs` and persisted expiration
   fence checks and continuation; failed never becomes ready from a later poll.
4. The **current** metadata schema is
   `POST /2/media/metadata {id, metadata:{alt_text:{text}}}`, returning `data.id`.
   This differs from legacy `media_id/alt_text` examples. Every nonempty reviewed
   description must receive a matching metadata receipt before create. The
   schema maxLength is 1000 with unspecified Unicode units; the app's documented
   conservative restriction is 1000 UTF-16 units, with blocking rather than
   dropping text. Production acceptance remains unavailable.
5. [Create Post](https://docs.x.com/x-api/posts/create-post.md) defines text as
   "Required unless media is provided" with empty default, establishing the
   media-only request shape. `media.media_ids` preserves order. Only status 201
   plus a numeric `data.id`, string `data.text`, and no errors becomes Published.
   Media upload/processing/metadata success cannot become publication evidence.
6. [Errors](https://docs.x.com/x-api/fundamentals/response-codes-and-errors.md)
   lists `invalid-request`, `not-authorized-for-resource`, `client-forbidden`,
   `usage-capped`, `rate-limit-exceeded` problem types. Only those explicit
   top-level rejection semantics on 4xx can settle a dispatched create failure.
   Generic statuses, loss, 5xx, partial errors or malformed receipts stay Unknown.
   Retry-After (seconds/date) and rate reset are retained, with no create retry.
7. [Pricing](https://docs.x.com/x-api/getting-started/pricing.md) documents
   credit-exhaustion request blocking, but the inspected page does not pin an
   exact credit-specific error identifier. Synthetic generic 402 therefore stays
   Unknown after dispatch and carries an app-owner billing remedy; no invented
   credit problem code is classified as definitive.

Current shipping connection/capability snapshots remain unavailable. Synthetic
MP4 bytes and metadata validate app protocol and durability behavior only;
they do not prove a real codec/entitlement or text/photo/video live acceptance.
