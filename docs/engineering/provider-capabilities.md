# Provider capability validation

Recorded 2026-11-16. Production registry composition lives in AppServices:
CapabilityRegistry.production receives the existing InstagramPhotoPolicy and
adds dated documentary X/Bluesky profiles. The direct profiles have
CapabilityStatus.unavailable. They return a blocking destination-scoped
`requirements-unverified` issue: “Couldn't check current requirements”.
They cannot authorize direct publication even with syntactically valid build
configuration. Their versions and source URLs identify the documentary
snapshot. Changing documentary limits is a new evidence version and invalidates
reviewed snapshots through the existing ReviewService version check.

A profile can be current, superseded or unavailable. Current must be assigned
only after the owning evidence/counter and required account/media contract are
verified. There is no arbitrary elapsed-day expiry or live fetch on every
keystroke; supersession is explicit. Unavailable/malformed/superseded profiles
fail closed. Changing a status alone is not OAuth or connection acceptance.

CapabilityValidator uses the injected platform-specific TextCounter and also
checks an optional UTF-8 byte limit. It never substitutes String.length or a
grapheme counter for X weighted parsing. X official twitter-text v3 requires
normalization, URL extraction, weighted code points and emoji recognition;
no production X counter has been accepted. Bluesky requires both <=300
clusters and <=3000 UTF-8 bytes; its production counter/Unicode conformance is
also pending. The shipping unavailable counter cannot accidentally authorize
content if used directly. No fixture limits enter runtime imports/assets.

For current profiles validation checks resolved attachment IDs/order, photo
count, explicit MIME set, positive byte/dimension metadata, photo/video size,
positive known video duration, duration ceiling, optional named width/height
and aspect bounds, and text availability/count. Exact boundary values pass.
The app supports a photo set or one video per destination; mixed media and
multiple videos are conservatively blocked. Unknown media types or metadata
block only their destination. Optional dimension/aspect fields are restrictions
with explicit names, not undocumented provider defaults. No speculative
alt-text length rule was added: Bluesky's required alt property can be an empty
string and Attachment already owns one; X's exact Unicode length semantics
remain unresolved. Provider serialization/permission work must preserve alt.

The X documentary photo byte ceiling 5,000,000 is a conservative app restriction
from the documented “5 MB”; it is not an asserted exact provider boundary.
Bluesky's photo schema says 2,000,000 bytes. Both documentary profiles restrict
MIME to the app's local JPEG/PNG subset; this does not prove receiving format
support. Direct video remains unavailable: X account/profile contradictions
and Bluesky authoritative duration/account/permission checks are unresolved.
See [the evidence matrix](provider-feasibility.md) for all media distinctions.

Instagram uses its existing independent local policy: preparationVerified,
JPEG/PNG and at most20 photos. This is local preparation evidence only; single
photo/carousel receiver shortcuts remain disabled pending dated device evidence.
The new registry does not replace that adapter or create an Instagram sign-in.

ProviderCapabilities owns copies of MIME/source collections; CapabilityRegistry
owns its validator map. Review snapshots continue to own their selected posts,
assets, account identities and capability versions. Missing configuration and
validation never remove destinations or prevent saving/editing offline drafts.
Review still reports each blocked direct destination and retains its content.

Host evidence: provider tests cover fixture boundaries, emoji/UTF-8 distinction,
metadata/MIME/count/aspect checks, conservative unavailable/superseded behavior,
collection ownership, real SQLite offline persistence and explicit AppServices
composition. `test/support/provider_fixtures.dart` has FAKE-fixture-only-1,
2 photos/20 text units/100-byte photos/200-byte videos/1000ms video and an
explicitly fixture-only grapheme counter. These are mock/local checks, not
provider, device, entitlement or publication evidence.
