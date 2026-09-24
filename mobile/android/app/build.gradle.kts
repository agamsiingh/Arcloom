import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- AdMob: single source of truth is mobile/config/admob.json -------------------------
// Debug/profile builds get Google's public TEST app ID; release builds get the production ID.
@Suppress("UNCHECKED_CAST")
val admob = JsonSlurper().parse(rootProject.file("../config/admob.json")) as Map<String, Map<String, Map<String, String>>>
val admobTestAppId: String = admob.getValue("test").getValue("android").getValue("appId")
val admobReleaseAppId: String = admob.getValue("release").getValue("android").getValue("appId")

// ---- Release signing: android/key.properties + upload keystore (never committed) ---------
// storeFile=/absolute/path/to/upload-keystore.jks
// storePassword=...   keyAlias=upload   keyPassword=...
// Release builds are signed with the Play *upload* key; Google Play App Signing re-signs them
// with the app signing key. Debug builds keep the default Android debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (keystoreProperties.getProperty(key).isNullOrBlank()) {
            throw GradleException("android/key.properties is missing '$key'")
        }
    }
    if (!file(keystoreProperties.getProperty("storeFile")).exists()) {
        throw GradleException("Upload keystore not found: ${keystoreProperties.getProperty("storeFile")}")
    }
}

android {
    namespace = "com.arcloom.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.arcloom.game"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobTestAppId
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            manifestPlaceholders["admobAppId"] = admobReleaseAppId
            // Never fall back to the debug key: a release without the upload key fails (see below).
            if (hasReleaseKeystore) signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Fail release packaging early and clearly when the upload key is not configured.
tasks.configureEach {
    if (!hasReleaseKeystore && (name == "bundleRelease" || name == "assembleRelease")) {
        doFirst {
            throw GradleException(
                "Release signing is not configured: create android/key.properties pointing at the upload keystore.",
            )
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
