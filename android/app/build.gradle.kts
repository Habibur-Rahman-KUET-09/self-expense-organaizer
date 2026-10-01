plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.habibur.expensetracker.expense_tracker"
    // file_picker's flutter_plugin_android_lifecycle dependency requires
    // compileSdk 36+; Flutter's own default (flutter.compileSdkVersion) is
    // still 34 as of this Flutter version, so it's pinned explicitly here.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.habibur.expensetracker.expense_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        // Version "1.0.0.N": pubspec's 1.0.0 is the Play Store version and
        // only changes when decided; N (after "+") goes up by one on every
        // build (tool/bump_build.sh) and is the versionCode.
        versionCode = flutter.versionCode
        versionName = "${flutter.versionName}.${flutter.versionCode}"
    }

    signingConfigs {
        getByName("debug") {
            // A committed key (instead of each machine's own
            // ~/.android/debug.keystore) so every CI build is signed the
            // same way and a new APK installs over the previous one,
            // keeping the data on the phone.
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the Play Store build.
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
