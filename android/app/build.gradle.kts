import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// When `--target-platform` narrows the build to a subset of ABIs, drop the other
// ABIs' native libraries from the APK.
//
// Flutter filters its own libflutter.so and libapp.so when it copies them, but a
// plugin's .so arrive prebuilt -- in the AAR, and for this app in the vendored
// cargokit output -- and nothing downstream filters them. Setting abiFilters on
// the plugin projects does not reach them either: it worked for the `jni`
// package and did nothing for cargokit or datastore_shared_counter, which also
// ships a lib/x86 directory for an ABI Flutter no longer supports.
//
// Left alone, an arm64-only build carried 4.4 MB of x86_64 and armeabi-v7a that
// no device it can install on would ever load. The .so are stored uncompressed,
// so that is APK bytes, not just uncompressed total.
//
// The platform names and their mapping to ABIs are Flutter's own
// (FlutterPluginConstants.PLATFORM_ARCH_MAP); android-x86 is absent because
// Flutter dropped it, so x86 is always excluded. With no --target-platform the
// property is unset, this is a no-op, and the fat APK is left alone.
val requestedAbis: List<String> =
    (project.findProperty("target-platform") as String?)
        ?.split(",")
        ?.map { it.trim() }
        ?.filter { it.isNotEmpty() }
        ?.mapNotNull {
            when (it) {
                "android-arm" -> "armeabi-v7a"
                "android-arm64" -> "arm64-v8a"
                "android-x64" -> "x86_64"
                else -> null
            }
        }
        ?.takeIf { it.isNotEmpty() }
        ?: emptyList()

val allAbis = setOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
val unwantedAbis = allAbis - requestedAbis.toSet()

android {
    namespace = "dev.masum.calcflut"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    if (unwantedAbis.isNotEmpty()) {
        packaging {
            jniLibs {
                excludes += unwantedAbis.map { "lib/$it/**" }
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "dev.masum.calcflut"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Enable shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
