import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The same public Flutter define feeds Dart and native routing; no second setup knob.
val xRedirectTargets = providers.gradleProperty("dart-defines").orElse("").get()
    .split(',').mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
            ?.takeIf { it.startsWith("X_REDIRECT_URI=") }?.removePrefix("X_REDIRECT_URI=")
    }
require(xRedirectTargets.size <= 1) { "Supply X_REDIRECT_URI only once" }
val xRedirectTarget = xRedirectTargets.singleOrNull() ?: ""
val xRedirect = runCatching { URI(xRedirectTarget) }.getOrNull()
require(xRedirectTarget.isEmpty() || (xRedirect != null && xRedirect.isAbsolute &&
    xRedirect.rawQuery == null && xRedirect.rawFragment == null && xRedirect.rawUserInfo == null)) {
    "X_REDIRECT_URI must be a callback target without query, fragment or user information"
}

// Same Flutter public define as Dart; an empty default never captures callbacks.
val blueskySchemes = providers.gradleProperty("dart-defines").orElse("").get()
    .split(',').mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
            ?.takeIf { it.startsWith("BLUESKY_CALLBACK_SCHEME=") }?.removePrefix("BLUESKY_CALLBACK_SCHEME=")
    }
require(blueskySchemes.size <= 1) { "Supply BLUESKY_CALLBACK_SCHEME only once" }
val blueskyScheme = blueskySchemes.singleOrNull() ?: ""
require(blueskyScheme.isEmpty() || Regex("[a-z][a-z0-9]*(?:[.-][a-z0-9]+)+").matches(blueskyScheme)) {
    "BLUESKY_CALLBACK_SCHEME must be a reverse-domain callback scheme"
}
val blueskyRedirect = if (blueskyScheme.isEmpty()) "" else "$blueskyScheme:/callback"

android {
    sourceSets.getByName("test").resources.srcDir("../../test/fixtures/providers/x")
    buildFeatures { buildConfig = true }
    namespace = "org.example.crossposting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.example.crossposting"
        testInstrumentationRunner = "org.example.crossposting.CredentialKeyLossInstrumentation"
        manifestPlaceholders["captionBlueskyCallbackEnabled"] = blueskyScheme.isNotEmpty().toString()
        manifestPlaceholders["captionBlueskyCallbackScheme"] = blueskyScheme.ifEmpty { "org.example.crossposting.bluesky.unconfigured" }
        buildConfigField("String", "CAPTION_BLUESKY_REDIRECT_URI", "\"$blueskyRedirect\"")
        manifestPlaceholders["appAuthRedirectScheme"] = "org.example.crossposting.unconfigured"
        manifestPlaceholders["captionXCallbackEnabled"] = xRedirectTarget.isNotEmpty().toString()
        manifestPlaceholders["captionXCustomScheme"] = if (xRedirect?.scheme != "https")
            xRedirect?.scheme ?: "org.example.crossposting.unconfigured" else "org.example.crossposting.unconfigured"
        manifestPlaceholders["captionXHttpsHost"] = if (xRedirect?.scheme == "https")
            xRedirect.host ?: "unconfigured.invalid" else "unconfigured.invalid"
        manifestPlaceholders["captionXHttpsPath"] = if (xRedirect?.scheme == "https")
            xRedirect.rawPath ?: "/unconfigured" else "/unconfigured"
        buildConfigField("String", "CAPTION_X_REDIRECT_URI", "\"${xRedirectTarget.replace("\\", "\\\\").replace("\"", "\\\"")}\"")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles("privacy-rules.pro")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("net.openid:appauth:0.11.1")
    implementation("androidx.browser:browser:1.9.0")
    implementation("com.twitter.twittertext:twitter-text:3.1.0")
    testImplementation("junit:junit:4.13.2")
}
