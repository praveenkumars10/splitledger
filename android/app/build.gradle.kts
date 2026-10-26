plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.splitledger.split_ledger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.splitledger.split_ledger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
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

tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val rootDir = project.rootDir.parentFile
        val flutterApkDir = File(rootDir, "build/app/outputs/flutter-apk")
        val releaseApk = File(flutterApkDir, "app-release.apk")
        if (releaseApk.exists()) {
            val vName = flutter.versionName ?: "1.0.0"
            val vCode = flutter.versionCode ?: 1
            val versionedName = "SplitLedger-v${vName}-build${vCode}.apk"
            val targetApk = File(flutterApkDir, versionedName)
            releaseApk.copyTo(targetApk, overwrite = true)
            
            val releasesDir = File(rootDir, "releases")
            if (!releasesDir.exists()) releasesDir.mkdirs()
            releaseApk.copyTo(File(releasesDir, versionedName), overwrite = true)
            println("✓ Auto-versioned APK copied to releases/$versionedName")
        }
    }
}

