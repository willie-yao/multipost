# Privacy and local storage

Caption keeps drafts, imported media, prepared Instagram packages and posting
attempts on the current Android installation. There is no cloud sync or Caption
server. Clearing app data or uninstalling loses this local library and its account
connections. Keep another copy of anything you need before doing either. Cloud
backup and automatic device migration are outside this MVP.

## Storage boundaries

| Data | Owner and lifetime |
| --- | --- |
| Draft captions, descriptions, account display metadata, frozen posting attempts and package records | Ordinary SQLite in application-support storage, protected by Android's app sandbox. These tables intentionally contain post content; they are not a credential store or app-level encrypted archive. |
| Imported media and prepared photos | App-private owned roots. Generated identifiers, normalized paths, canonical-root checks and file verification keep imports/exports inside those roots. Picker filenames do not choose destination paths. |
| App-managed credential persistence: OAuth tokens, Bluesky pending OAuth context, DPoP private keys and nonces | `CredentialVault` is the sole app-managed credential persistence port. `SecureCredentialVault` uses pinned `flutter_secure_storage` 11.2.0 and fixed `caption_x_credentials` / `caption_bluesky_credentials` Android namespaces with device-bound Keystore protection. Ordinary access uses `resetOnError: false`; explicit confirmed account repair uses the existing serialized package lifecycle and reset path. |
| Explicitly saved Instagram photos | A user-requested MediaStore export leaves app-private storage. Gallery copies have OS/gallery lifetimes and may be included in the user's photo backup. Caption's backup XML cannot control those copies or promise their removal on uninstall. |
| Explicitly copied caption/recovery text | Clipboard copies leave app-private storage and have OS/clipboard lifetimes. Copy is a user action; browsing the library does not read the clipboard. |

X native AppAuth owns its in-flight random state, S256 verifier and code exchange;
those pending values are not stored by the app vault. X vault persistence holds
the resulting tokens, account identity and public configuration. Bluesky uses the
vault-backed pending context as well as persisted sessions/keys.

Credential loss or an unusable Keystore key blocks publication and requires
reconnection or the existing explicit account repair. It does not erase drafts,
attempts or prepared packages. Disconnect removes that provider's credential
namespace/public connection identity while retaining local content. It does not
promise to revoke an already issued remote session. There is no automatic resend
on startup or network return.

## Android backup, network and URI policy

The application declares `allowBackup="false"`, `usesCleartextTraffic="false"`,
and explicit legacy backup / Android 12+ data-extraction rules. Legacy backup,
cloud backup and device transfer each exclude `root`, `file`, `database`,
`sharedpref` and `external` at `.`. This also prevents restoring encrypted
preferences without their original device key under a compliant implementation.
The rules apply to app data; they do not govern the gallery/clipboard copies
above. XML and merged-manifest inspection cannot prove every OEM migration
implementation honors these choices. Supported-device backup/transfer acceptance
remains required; never test uninstall or clear-data on a personal installation.

The supported paths require network access, network-state inspection and Android's
system picker/MediaStore APIs. No broad storage or `QUERY_ALL_PACKAGES` permission
is requested. The merged manifest adds scoped visibility queries for Instagram,
Flutter text processing and OAuth browser discovery (Custom Tabs / HTTPS intents),
plus an AndroidX signature-only dynamic-receiver permission. The Instagram
FileProvider is non-exported and exposes only
`files/instagram-packages/`; handoff grants temporary read permission, never
write permission. Export rechecks canonical package roots, generated filenames,
photo type and hashes before copying.

X callbacks pass the exact configured scheme/authority/path and one-active-flow
native guard before AppAuth, which owns OAuth state/PKCE exchange validation.
Bluesky's receiver dispatches by scheme; the connection validates the exact target,
unambiguous callback fields, issuer and single-use pending state before SDK
exchange. Unsolicited callbacks cannot publish, export arbitrary files or select
an outbound token destination. Production callback receivers are inert without
configuration. Syntactically valid public metadata still leaves both direct
provider availability gates closed. Test harnesses supply synthetic acceptance
only in tests; no release flag bypasses the production gates.

## Error and diagnostic boundaries

`userSafeMessage` accepts a literal reason code and selects fixed allowlisted
copy. Raw response bodies, callback URLs, credentials and exception strings are
never reason codes. Its unknown fallback mentions saved work and is used only
for a known committed snapshot. Failed saves retain **Couldn't save — keep this
screen open**, selectable/copyable unsaved text, Retry saving and conflict reload
controls. Bootstrap/load/edit failures use context-specific safe copy where a
saved snapshot is not assured. Existing feature-owned typed exceptions retain
safe, actionable repair instructions; their constructors are reviewed at their
owning boundaries.

Production app code currently has no print/debugPrint/log calls. Future
diagnostics may record operation, destination and allowlisted reason codes only:
never captions, descriptions, file paths, handles, tokens, private keys or full
URLs/query strings. Do not send raw exception objects or vault dumps to crash
reporting. Generated model `toString` methods are not a diagnostic API.

AppAuth Android 0.11.1 logs expected and returned OAuth state on a mismatch. Its
internal logger has no supported public level setter. The release build enables
R8 and `privacy-rules.pro` removes only AppAuth Logger's static severity entry
points, including stack variants. This removes diagnostic side effects while
retaining SDK protocol checks; it does not change the SDK, use reflection or
strip Android logging globally. Debug builds retain the upstream logging risk,
so real OAuth material must not be used there. Reinspect the pinned library and
actual minified DEX whenever the dependency or release optimizer changes.

## Verification limits

Task 20 adds synthetic host widget and real-SQLite checks for unknown UI failures,
failed authentication/refresh, interrupted upload/create, committed attempt/package
records and disconnect. The pinned real Bluesky SDK generates synthetic DPoP keys
against fake HTTP/browser fixtures; only those test-owned keys are inspected.
Host print capture and outcome checks never dump a real user's vault. Library
browsing is checked with network creation denied and clipboard reads counted;
source inspection confirms it reads only owned local repository/package data,
not an unrelated gallery enumeration.

The local minified evaluation artifact and merged Android manifest are inspected
separately. When switching from an integration/debug build, use the normal
`flutter build apk --release` tooling-generation path: `--no-pub` can retain a
stale debug registrant that refers to the excluded dev-only integration plugin.
The dependency graph remains pinned; generated registrants must not be edited.
Host tests and DEX inspection are not device logcat, AppAuth callback
execution, OEM backup/transfer, reinstall or live-provider acceptance. This task
does not enable either production provider. Earlier native evidence remains
limited to the recorded API 29 emulator/Skia configuration; real-device/default
renderer and live provider gates remain outstanding.
