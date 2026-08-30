import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val androidKeystoreFile = rootProject.file("key.properties")
val flutterKeystoreFile = rootProject.file("../key.properties")
when {
    androidKeystoreFile.exists() -> keystoreProperties.load(FileInputStream(androidKeystoreFile))
    flutterKeystoreFile.exists() -> keystoreProperties.load(FileInputStream(flutterKeystoreFile))
}

fun resolveStoreFile(raw: String?): File? {
    if (raw.isNullOrBlank()) return null
    val asFile = File(raw)
    if (asFile.isAbsolute) return asFile
    val fromAndroid = rootProject.file(raw)
    if (fromAndroid.exists()) return fromAndroid
    val fromRepoRoot = rootProject.file("../$raw")
    if (fromRepoRoot.exists()) return fromRepoRoot
    return fromAndroid
}

android {
    namespace = "xtended16gmail.com.vtm_helper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "xtended16gmail.com.vtm_helper"
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
            storePassword = keystoreProperties.getProperty("storePassword")
            storeFile = resolveStoreFile(keystoreProperties.getProperty("storeFile"))
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}