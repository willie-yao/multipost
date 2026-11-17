# Caption development toolchain

Recorded 2026-11-16 for task L1, from Git baseline
`79c82f28ea0a8ff16671e37af9521b263c0a7782` on
`codex/caption-native`. Flutter lives under `app/`; the root design inputs
are preserved.

## Verified Flutter SDK

| Item | Observed value |
| --- | --- |
| Host | Windows 11 25H2, build 10.0.26200.9911, x64 |
| Flutter | 3.50.0 stable |
| Framework revision | `ab2912035e160d9cad6306df307576da6128ebdb` |
| Engine revision | `371f77202a73e8dff57a8b3bff75bca55c090aee` |
| Dart | 3.14.0 |
| DevTools | 2.61.0 |
| Local SDK | `.tools/flutter` |
| Local Pub cache | `.tools/pub-cache` |

These values came from `flutter --version --machine` and `flutter doctor -v`,
not from example version pins. The release was selected using the official
[Windows release index](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json).
The selected release was published on 2026-11-11.

The downloaded archive is
[flutter_windows_3.50.0-stable.zip](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.0-stable.zip).
Its SHA-256 was checked against the official index **before extraction**:

```text
35fb843409c80a1c69b64bbae1756bba437222f909622d83540e266e1759aab8
```

The archive is 1,868,535,132 bytes. Extract it beneath `.tools/` so its
`flutter/` directory is at the path above. `.tools/` is ignored; the SDK and
caches must not enter commits. On a new machine, download this exact version
and verify the hash rather than selecting whichever stable release is newest.

## Generated project and SDK compatibility

The nested project was generated from the repository root with:

```powershell
flutter create --platforms=android --org org.example --project-name cross_posting_app app
```

Flutter 3.50.0's official template uses
`package:material_ui/material_ui.dart` and adds `material_ui: ^1.1.0`.
The actual resolved version is **1.11.1**, with its hosted source and SHA-256
recorded in `app/pubspec.lock`. The legacy
`package:flutter/material.dart` entrypoint is deprecated in this SDK after
3.47.0-0.0.pre. Caption and its tests therefore use the current template's
Material import consistently, preserving the planned public widget interfaces.
The first required missing-component test was run with the brief's original
Flutter Material import before this compatibility adjustment. No deprecation
suppression was added.

The approved reversible Android defaults are:

| Item | Value |
| --- | --- |
| Development application ID / namespace / Kotlin package | `org.example.crossposting` |
| Android floor | API 29 (Android 10), provisional |
| Compile / target SDK | Flutter 3.50.0 defaults; currently API 36 |
| Gradle wrapper | 9.5.0 |
| Android Gradle plugin | 9.3.1 |
| Kotlin plugin | 2.4.20 |
| Java/Kotlin bytecode target | 17 |
| Android display name | Caption |

The package ID is a development identifier. Release signing remains the
generated debug-key placeholder; release registration, signing, and deployment
have not been performed.

## Resolved direct packages

The required dependencies were added using this SDK's `flutter pub add`;
`app/pubspec.lock` pins the complete resolved graph. Use that lockfile rather
than copying version guesses from a plan.

| Runtime package | Resolved |
| --- | --- |
| material_ui | 1.11.1 |
| freezed_annotation | 3.1.0 |
| json_annotation | 4.12.0 |
| sqflite | 2.4.6 |
| path_provider | 2.1.6 |
| path | 1.9.1 |
| image_picker | 1.2.4 |
| image | 4.13.1 |
| crypto | 3.0.8 |
| uuid | 4.6.0 |
| characters | 1.4.1 |

| Development package | Resolved |
| --- | --- |
| flutter_lints | 6.0.0 |
| build_runner | 2.17.1 |
| freezed | 4.0.3 |
| json_serializable | 6.15.2 |
| sqflite_common_ffi | 2.4.7 |

These packages are available for the next local-feature tasks. L1 does not
initialize storage, pick media, connect accounts, or send content.

## Local commands

In PowerShell, from the repository root, set these values for the current
process only. No global PATH, Flutter configuration, or Git identity change is
needed.

```powershell
$repoRoot = (Get-Location).Path
$env:PATH = "$repoRoot\.tools\flutter\bin;C:\Program Files\Git\cmd;$env:PATH"
$env:PUB_CACHE = "$repoRoot\.tools\pub-cache"
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'

flutter --version --machine
flutter doctor -v
flutter devices

Set-Location app
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter test test/design/caption_scaffold_test.dart
flutter test
flutter analyze
```

The font and OFL license are bundled copies of
`docs/design/options-dark/assets/AtkinsonHyperlegibleNext.ttf` and its matching
license. SHA-256 checks confirmed both copies are byte-identical to their source.
The family name is `Atkinson Hyperlegible Next`.

## Android readiness and evidence limits

The initial L1 `flutter doctor -v` reported **Unable to locate Android SDK**;
Java was absent from PATH and the standard Android install locations were empty.
`flutter devices` listed Windows desktop, Chrome and Edge, with **no Android
device or emulator**. Its unrelated Windows desktop warning concerned missing
Visual Studio C++ components; L1 generates only the Android platform.

While L1 was being verified, the controller independently prepared local
Temurin JDK **21.0.13+9** at `.tools/jdk/jdk-21.0.13+9` and Android
command-line tools **23.0** at `.tools/android-sdk/cmdline-tools/23.0`.
The controller verified those tool versions. Installation of platform-tools,
`platforms;android-36`, `build-tools;36.0.0`, and
`ndk;28.2.13676358` was still in progress at this record's first writing.
Do not infer completed packages or an Android build from the existence of those
directories. Controller install evidence is under
`.superpowers/sdd/2026-11-16-flutter-caption-mvp/android-sdk-install.log`.

Once installation is verified, use process-local values:

```powershell
$env:JAVA_HOME = "$repoRoot\.tools\jdk\jdk-21.0.13+9"
$env:ANDROID_SDK_ROOT = "$repoRoot\.tools\android-sdk"
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:ANDROID_USER_HOME = "$repoRoot\.tools\android-user"
$env:GRADLE_USER_HOME = "$repoRoot\.tools\gradle"
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_SDK_ROOT\platform-tools;$env:PATH"
```

An Android device/emulator must still be selected and discovered before native
inspection. L1's automated checks exercise Flutter widget layout and semantics
at 320dp / 200% text and a 390dp inset fixture. They do **not** establish native
Android composition, TalkBack behavior, installation, plugin integration, or a
passing Android build. Native 390dp and 320dp frames and system keyboard/gesture
checks remain **unavailable** without an Android target; no browser rendering
is offered as substitute evidence.

Portable-tool provenance supplied by the controller:

- Android repository metadata: https://dl.google.com/android/repository/repository2-1.xml
- Command-line tools archive: https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip
  (154,957,218 bytes; verified official repository SHA-1
  `57d04f2d75eb8e8fffc5000a987e5de4b5a63e9d`).
- JDK release metadata: https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse
- JDK archive: https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13_9.zip
  (verified SHA-256
  `a4dbaa05fca4bd89d84584e58c459bd732efebb1722af80ab13c6516832004f9`).

## R3 current toolchain confirmation — 2026-11-17

The L1 readiness sections above are historical. The Android SDK is now installed
and Flutter doctor confirms its toolchain and accepted SDK licenses. R3 rechecked
Flutter 3.50.0 / Dart 3.14.0 at the exact framework/engine revisions above, Temurin
21.0.13+9, Android command-line tools 23.0, android-36 platform revision 2,
build-tools 36.0.0, NDK 28.2.13676358 and platform-tools 37.0.1. Gradle wrapper
9.5.0, AGP 9.3.1 and Kotlin 2.4.20 are unchanged. JDK 21 runs Gradle while the
app's Java/Kotlin bytecode target remains 17. `app/.flutter-version` pins Flutter.
The current graph, including provider dependencies added after L1, is in
`app/pubspec.lock`; the L1 package table above is not a current full inventory.

Use the self-contained [release setup](../release/setup.md) for process-local
SDK/Pub/Gradle paths, resource caps, locked generation and ordinary debug build.
R3 starts no AVD; ADB lists no Android device. The existing scoped native
observations remain in [Android acceptance](../testing/android-acceptance.md).
Flutter doctor still reports missing Visual Studio desktop C++ components; that
unrelated target is not part of this Android-only handoff. A passing assembly
must not be described as warning-free: plugin/toolchain warnings and the clean
source reproduction results are recorded in [release evidence](../release/evidence.md).
