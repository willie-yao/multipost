# Local Android setup and repeatable checks

These instructions build the development app without provider credentials,
accounts, a backend or an emulator. Verified host: Windows 11 x64, PowerShell 7.
Other hosts are not verified here. Public release decisions are separate from
being able to build/test locally; see [checklist](release-checklist.md).

## Install the pinned tools

Install Flutter **3.50.0 stable**, framework
`ab2912035e160d9cad6306df307576da6128ebdb`, with its bundled Dart **3.14.0**.
`app/.flutter-version` is the version pin; do not use whichever stable is newest.
The [toolchain record](../engineering/toolchain.md) contains the official Windows
archive URL/hash and JDK provenance. This guide assumes portable installs in
`.tools/` under the repository root; using equivalent absolute paths is fine.

Use Temurin JDK **21.0.13+9** to run Gradle. Java/Kotlin output targets **17**;
that is not the build JDK requirement. The tracked Gradle wrapper configuration
pins **9.5.0**; AGP **9.3.1** and Kotlin **2.4.20** remain the locked template
versions. Do not replace these with the plan's illustrative JDK 17 CI snippet.

Install Android command-line tools **23.0** at
`.tools/android-sdk/cmdline-tools/23.0`, then, after reviewing/accepting the Android
SDK licenses as the developer, install the following SDK packages using
`sdkmanager.bat`. No store enrollment or paid account is involved:

```powershell
& '.tools/android-sdk/cmdline-tools/23.0/bin/sdkmanager.bat' '--sdk_root=.tools/android-sdk' 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
```

The local verification used platform android-36 revision 2, build tools 36.0.0,
NDK 28.2.13676358, CMake 3.22.1 and platform-tools 37.0.1. SDK manager package
names such as `platform-tools` track upstream updates; record actual versions
when reproducing. No emulator/system image is necessary for host checks/builds.
First-time downloads need internet and disk space; verified local reproduction
reuses SDK, Pub and Gradle download caches, not prior app build outputs.

## Configure only this PowerShell process

From the repository root, before changing into `app`:

```powershell
$repoRoot = (Get-Location).Path
$env:JAVA_HOME = Join-Path $repoRoot '.tools/jdk/jdk-21.0.13+9'
$env:ANDROID_SDK_ROOT = Join-Path $repoRoot '.tools/android-sdk'
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:ANDROID_USER_HOME = Join-Path $repoRoot '.tools/android-user'
$env:GRADLE_USER_HOME = Join-Path $repoRoot '.tools/gradle-cache'
$env:PUB_CACHE = Join-Path $repoRoot '.tools/pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:PATH = (Join-Path $repoRoot '.tools/flutter/bin') + ';' + (Join-Path $env:JAVA_HOME 'bin') + ';' + (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools') + ';C:/Program Files/Git/cmd;' + $env:PATH
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs="-Xmx1536m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m" -Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process'
$env:JAVA_OPTS = '-Xmx512m'
flutter --version --machine
flutter doctor -v
```

These process-local caps were used for the evidence and override the template's
larger Gradle memory defaults. Do not edit global PATH or SDK config. Missing
Visual Studio C++ desktop components reported by doctor concern Windows desktop,
which is outside this Android-only target. Android toolchain/license errors need
fixing before an Android build. Do not launch an emulator just to build.

## Resolve, generate, check and build

In the same shell:

```powershell
Set-Location app
flutter pub get --enforce-lockfile
dart run build_runner build
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --target lib/main.dart
# After the build generates the Android wrapper/registrant:
Set-Location android
# First run allows Gradle to resolve JUnit and any missing dependencies.
.\gradlew.bat :app:testDebugUnitTest --max-workers=1 -Ptarget-platform=android-x64
Set-Location ../..
git diff --exit-code -- app/pubspec.lock app/lib
```

The recorded R3 validation used the same JVM task with `--offline` after its
dependencies were cached. On later cached runs you may add `--offline`; a first
checkout needs the online invocation above or a prepopulated Gradle cache. That
recorded cached pass is not evidence of a cold-cache run.

Check every exit code; stop on failure. `pubspec.lock` is committed and must stay
unchanged. Generated `.freezed.dart`/`.g.dart` files are committed; regeneration
must match their tracked content. The pinned build_runner 2.17.1 removed
`--delete-conflicting-outputs`; it warns and ignores that legacy flag, so use the
plain `build` command above. Do not hand-edit generators, registrants or
SDK files. The Android JVM task currently has 6 tests; no release unit-test
variant exists and none needs enabling for this handoff. Formatting the entire
historical tree is not a clean-generation requirement; avoid unrelated changes.

The debug APK is `app/build/app/outputs/flutter-apk/app-debug.apk`, package
`org.example.crossposting`, version `0.1.0+1`, signed with a development debug key.
For the ordinary handoff always use the explicit `lib/main.dart` command above,
with **no** `--dart-define` or `--dart-define-from-file` arguments. The public
metadata defaults are unconfigured and both direct provider gates stay closed.
Debug AppAuth retains an upstream logging risk: use synthetic local fixtures,
never real OAuth material, in debug builds.

Integration builds overwrite the same `app-debug.apk` with their own entrypoint.
Freeze/name native fixture APKs separately and rebuild the ordinary app last.
When switching build mode/entrypoint, let Flutter regenerate platform tooling:
use normal `flutter build ...`, without `--no-pub`. A stale integration registrant
once broke a `--release --no-pub` evaluation by referencing dev-only
`integration_test`; supported normal release generation fixed it without changing
the locked graph. A release-mode evaluation is still debug signed in this tree;
it is not a distributable candidate. See [signing](signing.md).

For a second fresh source checkout or tracked-source export, run the same steps
with the same SDK/cache paths. It must start without `app/build`, `.dart_tool`,
`local.properties`, wrapper launchers/JAR or generated registrants; Flutter
regenerates local tooling. Compare the lockfile and all tracked generated outputs
by Git diff (checkout) or SHA256 manifest (export). Shared download caches are
allowed; reusing the first checkout's app build directory is not. This proves
source/generation/build repeatability, not byte-identical APKs across hosts,
keystores or timestamps. See [recorded evidence](evidence.md).

For local interactive inspection on a separately authorized test device:

```powershell
Set-Location (Join-Path $repoRoot 'app')
# Replace with the ID actually listed by flutter devices.
flutter devices
flutter run --debug --target lib/main.dart -d <authorized-device-id>
```

Do not use a personal installation for destructive recovery tests. Device/native
acceptance needs its own recorded evidence; this R3 handoff starts no emulator.

## App-owner metadata versus ordinary connection

Local drafting/test setup is complete without any of the values below. The app
owner, before a later separately accepted direct integration, must choose the
public identity, callback/domain ownership, provider registration and X billing
arrangement. Public configuration is supplied at build time with:

- `--dart-define=X_CLIENT_ID=<public-native-client-id>`
- `--dart-define=X_REDIRECT_URI=<exact-registered-callback>`
- `--dart-define=BLUESKY_METADATA_URI=<canonical-owned-https-client-json-url>`
- `--dart-define=BLUESKY_CALLBACK_SCHEME=<reversed-metadata-host>`

Never put a client secret, token, password or private key in a Dart define: APK
contents and build arguments are public. The same defines feed Dart and Android
routing. X uses official external-browser OAuth2 PKCE; exact registered callbacks
and account entitlement need native/live acceptance. Bluesky needs owner-hosted
HTTPS static metadata returning 200 and application/json without redirects; its
exact `client_id` must equal the configured canonical URL and the native redirect
is `<scheme>:/callback` (one slash). Required metadata includes native application,
no client authentication, code/refresh grants, atproto scopes and DPoP binding.
Use the full [OAuth configuration record](../engineering/oauth-configuration.md)
for the strict metadata/SDK boundaries before provisioning. Reserved example.com
fixtures in tests are not owned endpoints or deployable configuration. Supplying
syntactically valid public values **does not enable** the production gates.

Ordinary users of a future accepted distribution authorize their own account in
the external provider browser; they do not supply client secrets, run a backend,
register developer apps or host metadata. A personal self-builder may hold both
roles, but the X costs/registration and public metadata maintenance still need an
explicit owner. Tokens and app-managed pending credentials use the Android-backed
vault as documented in [privacy](../engineering/privacy-and-storage.md), not a
`.env`, SQLite content row, build define or committed fixture.
