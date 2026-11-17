# Contributing to Caption

Start with [setup](docs/release/setup.md), the pinned SDK and `app/pubspec.lock`.
Keep changes focused and run the checks relevant to the changed boundary, then
the full host suite/analyzer before handing off a development change. Do not
upgrade Flutter, Gradle or provider SDKs as incidental cleanup. Regenerate
Freezed/JSON outputs from `app` with `dart run build_runner build`; commit source
and generated changes together and investigate unexplained drift.

`app/lib/app/` wires services and public configuration. `app/lib/design/` owns shared
Caption widgets/tokens. `app/lib/features/` owns drafts, compose, review, accounts,
media, Instagram, publishing, results and provider behavior.
`app/lib/storage/` owns SQLite
schema/lifecycle. Android platform channels, callback guards, MediaStore and
FileProvider boundaries live under `app/android/app/src/`. Preserve these
feature boundaries; no service, scheduler or broad architecture change is needed
for local development.

Tests under `app/test/` use real temporary SQLite where persistence matters,
fake clocks/transports/accounts and synthetic media. Provider fixtures live under
`app/test/fixtures/providers/`; the standalone SDK probe has its own instructions
and lockfile. Never substitute a live provider request for a fake test, embed an
account/token/client secret, or make paid API calls as part of the default suite.
Both direct production provider gates remain closed until separately accepted.
Any future CI must run these same credential-free checks with read-only tokens,
no deployment/signing secrets and immutable reviewed action revisions. No remote
or CI platform is currently selected.

Respect the product's recovery contracts: save acknowledgements apply to their
own revision, frozen submission snapshots stay immutable, one original submission
group exists per source draft ID, retries are explicit children, and app launch
or network return never sends. Text and media inheritance remain independent.
Instagram preparation/manual status never becomes a claim of automatic posting.
Use typed safe UI failures and the credential persistence port; do not log post
content, handles, paths, callback URLs, credentials or raw exception objects.
See [privacy](docs/engineering/privacy-and-storage.md).

Accessibility is part of every UI change: minimum 48×48 dp touch targets, 4.5:1
normal-text contrast, 3:1 meaningful component boundaries, labeled non-drag
controls, and growing/scrolling layouts at 200% text. Preserve one white action
per screen and cyan for a destination's own caption. Add focused semantics/layout
checks at narrow widths where useful. Host semantics do not replace real
TalkBack, keyboard/selection, OS font/display scaling or focus acceptance.
Follow [Android acceptance](docs/testing/android-acceptance.md) for device limits;
do not rerun process-death fixtures on personal data or clear app storage.

Keep `docs/design/` as historical references and distinguish illustrative boards
from executed native evidence. Add concise portable evidence to tracked docs;
keep SDKs, caches, captures with account data, keys and large fixture archives out
of commits. Before sharing source, finish the MIT holder and third-party notice
review in the [release checklist](docs/release/release-checklist.md).
