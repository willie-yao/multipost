# Release signing handoff

No release keystore has been generated and no signed public candidate has been
authorized or distributed. The current Android release build type deliberately
still uses the generated **debug signing config**; `--release` enables release
compilation/minification, not a production signing identity. Both debug APKs and
the earlier minified privacy evaluation are development artifacts. Finish the
identity, holder, distribution and provider gates before enabling release signing.

The release owner must own the key and its encrypted offline backup. Android
updates require signature continuity and a compatible application ID with an
increasing version code; losing a direct-distribution signing key generally means
losing the ability to update installed copies. A namespace change is a coordinated
Kotlin/manifest/test/callback/docs change, not a text replacement. Do not distribute
`org.example.crossposting` as the final identity.

## Future owner-executed key creation

After signing authorization, choose an absolute directory outside the checkout
and run the official JDK keytool there. This is an example command only; no key
was created by this task:

```powershell
# Replace the absolute path and alias with owner-selected values.
& "$env:JAVA_HOME/bin/keytool.exe" -genkeypair -v -keystore '<private-absolute-directory>/caption-upload.jks' -keyalg RSA -keysize 2048 -validity 10000 -alias '<owner-selected-alias>'
```

Allow keytool to prompt for passwords; do not put them in command arguments,
terminal transcripts, source, build defines or chat. Record/verify the selected
alias and certificate fingerprint privately. Store encrypted backups of the
keystore, alias/password recovery information and ownership separately from the
development machine. Test backup recovery privately before relying on it.

## Future local/environment configuration

After identity/signing review, the owner can wire environment-backed Gradle
signing. Replace the existing debug signing assignment inside `release` and add a
signing config inside the existing `android` block, using this configuration shape:

```kotlin
// Applied only when the owner is ready to require release credentials locally.
signingConfigs {
    create("captionRelease") {
        storeFile = file(providers.environmentVariable("CAPTION_KEYSTORE_PATH").get())
        storePassword = providers.environmentVariable("CAPTION_STORE_PASSWORD").get()
        keyAlias = providers.environmentVariable("CAPTION_KEY_ALIAS").get()
        keyPassword = providers.environmentVariable("CAPTION_KEY_PASSWORD").get()
    }
}
// Inside buildTypes.release, replace its existing signingConfig line:
signingConfig = signingConfigs.getByName("captionRelease")
```

This snippet is documentation, not current configuration. As written it requires
all four values during Gradle configuration, including debug tasks; apply it only
for the authorized signing setup and review developer ergonomics then. Supply
values from the owner's local secret manager/current process, with an absolute
keystore path outside source. If instead using a local `key.properties` loader,
keep that file ignored, never commit it, and do not silently fall back to debug
signing when release credentials are missing. Environment values and local
properties are not an app backend or ordinary account-connect step.

For a later authorized candidate, use supported Flutter generation
(`flutter build apk --release --target lib/main.dart` with the reviewed public
metadata), verify the actual signer using Android build-tools
`apksigner verify --verbose --print-certs`, inspect the final merged manifest and
minified DEX, and record source commit, version, defines, certificate fingerprint
and artifact SHA256. Use `flutter build appbundle --release` only if Play is
selected. Neither command authorizes upload/publication.

Retain the debug/release AppAuth qualification in
[privacy](../engineering/privacy-and-storage.md). Release R8 removes the pinned
AppAuth logger calls, but it does not prove runtime logcat or every dependency is
silent. Repeat the compiled-artifact privacy check after dependency/optimizer
changes. Never use live credentials in the debug app.

Keystores, signing/local properties, private environment files and captured account
data are excluded by the ignore rules. Ignore rules are a guard, not a substitute
for reviewing `git diff --cached` and `git ls-files` before sharing source.
