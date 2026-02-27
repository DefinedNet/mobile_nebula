import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.defined.mobile_nebula"
    // needs to match version in flake.nix
    compileSdk = flutter.compileSdkVersion
    // needs to match version in flake.nix
    ndkVersion = flutter.ndkVersion

    // needs to match version in flake.nix
    buildToolsVersion = "35.0.0"

    compileOptions {
        // needs to match version in flake.nix
        sourceCompatibility = JavaVersion.VERSION_17
        // needs to match version in flake.nix
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            // needs to match version in flake.nix
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "net.defined.mobile_nebula"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion //TODO: was hardcoded to 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            resValue("string", "app_name", "\"Nebula\"")
        }

        debug {
            resValue("string", "app_name", "\"Nebula-DEBUG\"")
            applicationIdSuffix = ".debug"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    var workVersion = "2.11.1"
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("androidx.work:work-runtime-ktx:$workVersion")
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("com.google.guava:guava:33.5.0-android")
    implementation(project(":mobileNebula"))

}

