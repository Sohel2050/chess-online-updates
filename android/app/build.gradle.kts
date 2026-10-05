import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.albonik.chess"
    compileSdk = 36
    // Highest NDK required by plugins (integration_test, jni); NDKs are backward compatible.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.albonik.chess"
        // LevelPlay 9.x, LiveKit and Stockfish need at least API 23-24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Only configured when key.properties exists, so debug builds never crash.
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ---- Required by Unity LevelPlay (per official plug-in integration doc) ----
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
    implementation("com.google.android.gms:play-services-appset:16.1.0")

    // ---- LevelPlay mediation adapters (Android adapter / network SDK) ----
    // Versions from docs.unity.com "Mediation networks for Android". The LevelPlay
    // SDK itself comes from the unity_levelplay_mediation Flutter plugin.

    // AppLovin
    implementation("com.unity3d.ads-mediation:applovin-adapter:5.9.0")
    implementation("com.applovin:applovin-sdk:13.6.4")

    // Chartboost
    implementation("com.unity3d.ads-mediation:chartboost-adapter:5.10.0")
    implementation("com.chartboost:chartboost-sdk:9.14.1")

    // Meta Audience Network (the only network here that supports native ads)
    implementation("com.unity3d.ads-mediation:facebook-adapter:5.4.0")
    implementation("com.facebook.android:audience-network-sdk:6.22.0")

    // InMobi
    implementation("com.unity3d.ads-mediation:inmobi-adapter:5.9.0")
    implementation("com.inmobi.monetization:inmobi-ads-kotlin:11.4.1")

    // Mintegral
    implementation("com.unity3d.ads-mediation:mintegral-adapter:5.19.0")
    implementation("com.mbridge.msdk.oversea:mbridge_android_sdk:17.1.81")

    // MobileFuse
    implementation("com.unity3d.ads-mediation:mobilefuse-adapter:5.4.0")
    implementation("com.mobilefuse.sdk:mobilefuse-sdk-core:1.12.0")

    // Moloco
    implementation("com.unity3d.ads-mediation:moloco-adapter:5.17.0")
    implementation("com.moloco.sdk:moloco-sdk:4.12.0")

    // Ogury
    implementation("com.unity3d.ads-mediation:ogury-adapter:5.5.0")
    implementation("co.ogury:ogury-sdk:6.3.1")

    // PubMatic
    implementation("com.unity3d.ads-mediation:pubmatic-adapter:5.11.0")
    implementation("com.pubmatic.sdk:openwrap:5.4.1")

    // Smaato
    implementation("com.unity3d.ads-mediation:smaato-adapter:5.6.0")
    implementation("com.smaato.android.sdk:smaato-sdk:23.2.2")

    // Unity Ads
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.13.0")
    implementation("com.unity3d.ads:unity-ads:4.20.1")

    // Verve
    implementation("com.unity3d.ads-mediation:verve-adapter:5.8.0")
    implementation("net.pubnative:hybid.sdk:3.9.2")

    // Yandex
    implementation("com.unity3d.ads-mediation:yandex-adapter:5.15.0")
    implementation("com.yandex.android:mobileads:8.5.0")

    // Liftoff Monetize (Vungle)
    implementation("com.unity3d.ads-mediation:vungle-adapter:5.15.0")
    implementation("com.vungle:vungle-ads:7.7.8")

    // NOTE: No explicit billing dependency on purpose. The Flutter
    // in_app_purchase plugin pulls in the Play Billing version it was built
    // against; forcing a newer one here can cause NoSuchMethodError at runtime.
}
