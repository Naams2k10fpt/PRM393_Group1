plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = providers.environmentVariable("QUIZ_ANDROID_KEYSTORE")

android {
    namespace = "com.quizmanagement.prm393.quiz_management_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.quizmanagement.prm393.quiz_management_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore.isPresent) {
            create("production") {
                storeFile = file(releaseKeystore.get())
                storePassword = providers.environmentVariable("QUIZ_ANDROID_STORE_PASSWORD").get()
                keyAlias = "quizmanagement"
                keyPassword = storePassword
            }
        }
    }

    buildTypes {
        release {
            // Local demo builds and CI do not have the production signing key.
            signingConfig = signingConfigs.findByName("production") ?: signingConfigs.getByName("debug")
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
