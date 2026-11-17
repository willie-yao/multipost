# Provider evidence fixtures

All provider identities, codes, tokens, state and media in these tests are
synthetic. Never add real account data, keys, credentials or authorization URLs.
The SDK generates ephemeral package-owned DPoP keys in memory and prints only
sanitized scenario names/results. No fixture is a live provider receipt.

`../../support/provider_fixtures.dart` has FAKE-fixture-only-1 capabilities,
2 photos/20 grapheme fixture units/100-byte photos/200-byte videos/1000ms video.
FixtureTextCounter counts graphemes for tests only; it is not an X counter.
These fixtures never enter production assets or imports.

The exact published atproto_oauth0.8.3/core2.4.1/bluesky2.18.0 characterization
harness is `oauth_probe.dart.txt`, with standalone `sdk-probe.pubspec.yaml`
and `sdk-probe.pubspec.lock`. The .txt suffix prevents the Flutter app analyzer
from resolving unaccepted provider packages. No provider dependency is added
to the production app. Run from repository root with task-local Flutter:

```powershell
& ./app/test/fixtures/providers/run-sdk-probe.ps1
```

The runner copies only those files into ignored `.tools/provider-probe`, sets
process-local PUB_CACHE/DART_SUPPRESS_ANALYTICS, enforces the isolated lockfile
and runs Dart. Initial dependency download contacts pub.dev; the harness itself
uses only injected fake HTTP and identity endpoints and opens no network socket.
It requires the portable SDK at `.tools/flutter` or an equivalent explicit
runner adjustment. Nothing is registered, hosted, authenticated or posted.

Passing characterization cases intentionally reproduce raw SDK gaps; they are
not OAuth conformance approval. The NoncePolicy is an isolated tested candidate
for one boundary and never enters app runtime. See
`docs/engineering/oauth-configuration.md` for exact positive/negative evidence,
licenses, remaining acceptance gates and source-backed P3 enforcement points.
Mock store serialization/ordering does not prove encrypted native persistence,
real process death, native callbacks, account entitlement or live publication.
