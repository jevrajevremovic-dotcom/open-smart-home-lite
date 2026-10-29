import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release key: android/key.properties (not in git; see docs/RELEASE.md).
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

// Installer brand: android/brand.properties (not in git; see docs/INSTALLER.md).
val brandProperties = Properties().apply {
    val file = rootProject.file("brand.properties")
    // UTF-8, not the Latin-1 default: names like "Pametna Kuća".
    if (file.exists()) file.reader(Charsets.UTF_8).use { load(it) }
}

// Demo to show without a home (tool/build_demo.sh): its own id and name, so
// it installs next to the real app and never over it.
val demo = project.findProperty("demo") == "true"

android {
    namespace = "org.opensmarthome.open_smart_home"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // A brand gets its own id, so it installs next to (not over) the
        // community app.
        applicationId = brandProperties.getProperty("applicationId")
            ?: "org.opensmarthome.lite"
        manifestPlaceholders["appLabel"] =
            brandProperties.getProperty("name") ?: "Open Smart Home Lite"
        if (demo) {
            applicationIdSuffix = ".demo"
            manifestPlaceholders["appLabel"] =
                (brandProperties.getProperty("name") ?: "Open Smart Home Lite") + " Demo"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties (another machine, CI) the debug key, so
            // the build still works — never for builds handed out.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("key.properties not found: release signed with the DEBUG key")
                signingConfigs.getByName("debug")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Adding new Matter devices over Bluetooth (Google Play services).
    implementation("com.google.android.gms:play-services-home:16.0.0")
    // Kiosk wake-on-approach (front camera); same version mobile_scanner uses.
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
}
