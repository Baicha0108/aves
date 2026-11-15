import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.ksp)
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// NOTE (baicha fork): `namespace` / class package stays as upstream, because all Kotlin & Java
// sources live under `deckers.thibault.aves` and component names (activities, services,
// providers) are derived from it in the manifest and in `res/xml/app_widget_info.xml`.
// Only the *application id* (what Android, the launcher, the system search and other apps see)
// is changed for this fork.
val classPackage = "deckers.thibault.aves"
val appId = "io.github.baicha.aves"
// NOTE (baicha fork): ship a single arm64-v8a APK. For local emulator testing (MuMu is
// x86_64) the ABI set can be overridden with the `BAICHA_ABIS` environment variable, e.g.
//   $env:BAICHA_ABIS="x86_64"; flutter build apk --target-platform android-x64
val forkAbis = (System.getenv("BAICHA_ABIS") ?: "arm64-v8a")
    .split(",")
    .map { it.trim() }
    .filter { it.isNotEmpty() }

// Keys

val keystoreProperties = Properties()
val keystorePropertiesFile: File = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    println("Load keystore props from file=$keystorePropertiesFile")
    // for release using credentials stored in a local file
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else {
    println("Load keystore props from system environment")
    // for release using credentials in environment variables set up by GitHub Actions
    // warning: in property file, single quotes should be escaped with a backslash,
    // but they should not be escaped when stored in env variables
    val env = System.getenv()
    fun getEnv(propKey: String, envKey: String) {
        if (envKey in env) {
            keystoreProperties[propKey] = env[envKey]
        }
    }
    getEnv("storeFile", "AVES_STORE_FILE")
    getEnv("storePassword", "AVES_STORE_PASSWORD")
    getEnv("keyAlias", "AVES_KEY_ALIAS")
    getEnv("keyPassword", "AVES_KEY_PASSWORD")
    getEnv("googleApiKey", "AVES_GOOGLE_API_KEY")
}

android {
    namespace = classPackage
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // enable support for the new language APIs on older devices
        // e.g. `java/util/function/Supplier` on Android 5.0 (API 21)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        // Gradle looks up toolchain JDKs (for this app and each of its modules)
        // among locally installed JDKs (including in `~/.gradle/jdks/` and `~/jdks`)
        // and download them from configured repositories if necessary.
        jvmToolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
            vendor.set(JvmVendorSpec.ADOPTIUM) // Temurin
            // for consistency, refresh `gradle-daemon-jvm.properties` with the following:
            // ./gradlew updateDaemonJvm --jvm-version=21 --jvm-vendor=ADOPTIUM
        }
    }

    defaultConfig {
        applicationId = appId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleApiKey"] = keystoreProperties["googleApiKey"] ?: "NONE"
        multiDexEnabled = true
        // NOTE (baicha fork): single arm64-v8a APK for every build type.
        // Placed in `defaultConfig` so it also applies to debug/profile, where third-party
        // native libraries (e.g. media_kit / libmpv) would otherwise bring in every ABI.
        ndk {
            abiFilters += forkAbis
        }
    }

    // remove dependency metadata from build artifacts
    // cf https://izzyondroid.org/about/security/ApkScans/#signingblock-checks
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    signingConfigs {
        val storeFilePath = keystoreProperties["storeFile"] as String?
        if (storeFilePath != null) {
            println("Create signing config for release using file=$storeFilePath")
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    flavorDimensions += "store"

    productFlavors {
        create("play") {
            // Google Play
            dimension = "store"
        }

        create("izzy") {
            // IzzyOnDroid
            // check offending libraries with `scanapk`
            // cf https://android.izzysoft.de/articles/named/app-modules-2
            dimension = "store"
        }

        create("libre") {
            // F-Droid
            // check offending libraries with `fdroidserver`
            // cf https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/
            dimension = "store"
        }
    }

    buildFeatures {
        buildConfig = true
        resValues = true
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
        }

        getByName("profile") {
            applicationIdSuffix = ".profile"
        }

        getByName("release") {
            if (signingConfigs.names.contains("release")) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("Skip release signing as it is not configured")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // NOTE (baicha fork): ABI filtering is configured once in `defaultConfig`
            // (arm64-v8a only, one APK per build type), so upstream's per-variant
            // `abiFilters` / `--split-per-abi` handling is intentionally dropped here.
        }

        val abiCodes = mapOf(
            "armeabi-v7a" to 1,
            "arm64-v8a" to 2,
            "x86" to 3,
            "x86_64" to 4
        )

        applicationVariants.all {
            println("Application variant applicationId=$applicationId name=$name")

            resValue("string", "screen_saver_settings_activity", "${applicationId}/${classPackage}.ScreenSaverSettingsActivity")
            resValue("string", "search_provider", "${applicationId}.search_provider")

            outputs.forEach { output ->
                val abi = output.filters.find { it.filterType == "ABI" }?.identifier
                val baseAbiVersionCode = abiCodes[abi]
                if (baseAbiVersionCode != null) {
                    val versionCodeOverride = versionCode * 100 + baseAbiVersionCode
                    println("  output versionCodeOverride=$versionCodeOverride for abi=$abi")
                    (output as ApkVariantOutputImpl).versionCodeOverride = versionCodeOverride
                }
            }
        }
    }
}

androidComponents {
    onVariants(selector().all()) { variant ->
        // NOTE (baicha fork): this fork ships a single arm64-v8a APK.
        // Flutter's Gradle plugin resets `defaultConfig.ndk.abiFilters` to the full platform
        // list (see FlutterPlugin.configureAbiWithoutSplits), which would pull in
        // armeabi-v7a / x86_64 native libraries from third-party dependencies
        // (media_kit's libmpv, libtiff, libimageOps...). Enforce the filter again at
        // packaging level so the APK really only contains arm64-v8a.
        val allAbis = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        variant.packaging.jniLibs.excludes.addAll(allAbis.filter { it !in forkAbis }.map { "lib/$it/**" })
    }

    onVariants(selector().withFlavor("store", "izzy")) { variant ->
        // uncompressed native libraries are recommended:
        // https://developer.android.com/build/releases/agp-4-2-0-release-notes#compress-native-libs-dsl
        // but compressed native libraries yield smaller APK files, following Izzy's policy
        variant.packaging.jniLibs.useLegacyPackaging = true
    }
}

flutter {
    source = "../.."
}

repositories {
    maven {
        url = uri("https://jitpack.io")
        content {
            includeGroup("com.github.contentauth")
            includeGroup("com.github.deckerst")
            includeGroup("com.github.deckerst.mp4parser")
        }
    }
    maven {
        url = uri("https://s3.amazonaws.com/repo.commonsware.com")
        content {
            excludeGroupByRegex("com\\.github\\.deckerst.*")
        }
    }
}

dependencies {
    // cf https://developer.android.com/studio/write/java8-support#library-desugaring
    coreLibraryDesugaring(libs.android.desugarJdkLibs)

    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.androidx.annotation)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.ktx)
    implementation(libs.androidx.performance)
    implementation(libs.androidx.lifecycle)
    implementation(libs.androidx.media)
    // Jetpack `security-crypto` library is deprecated:
    // https://developer.android.com/privacy-and-security/cryptography#security-crypto-jetpack-deprecated
    implementation(libs.androidx.security.crypto)
    implementation(libs.androidx.work.runtime)

    implementation(libs.commonsware.cwac)
    implementation(libs.contentauth.c2pa)
    implementation(libs.metadata.extractor)
    implementation(libs.glide)
    implementation(libs.google.material)
    // SLF4J implementation for `mp4parser`
    implementation(libs.slf4j)

    // forked, built by JitPack:
    // - https://jitpack.io/p/deckerst/Android-TiffBitmapFactory
    // - https://jitpack.io/p/deckerst/androidsvg
    // - https://jitpack.io/p/deckerst/mp4parser
    // - https://jitpack.io/p/deckerst/pixymeta-android
    implementation(libs.deckerst.tiffbitmapfactory)
    implementation(libs.deckerst.androidsvg)
    implementation(libs.deckerst.mp4parser.isoparser)
    implementation(libs.deckerst.mp4parser.muxer)
    implementation(libs.deckerst.pixymeta)
    implementation(project(":exifinterface"))

    testImplementation(libs.junit)

    ksp(libs.glideKsp)

    compileOnly(rootProject.findProject(":streams_channel")!!)
}

if (rootProject.extra["aves_useCrashlytics"] as Boolean) {
    println("Building flavor with Crashlytics plugin")
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    println("Building flavor without reporting plugin")
}
