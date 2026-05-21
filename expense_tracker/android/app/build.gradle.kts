import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

    plugins {
        id("com.android.application")
        id("kotlin-android")
        // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
        id("dev.flutter.flutter-gradle-plugin")
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")

    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

android {
        namespace = "com.intelliumdigital.sweldotrack"
        compileSdk = 36
        ndkVersion = flutter.ndkVersion

        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }

    defaultConfig {
        applicationId = "com.intelliumdigital.sweldotrack"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
            minSdk = flutter.minSdkVersion
            targetSdk = 35
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }

        signingConfigs {
            if (keystorePropertiesFile.exists()) {
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
                if (keystorePropertiesFile.exists()) {
                    signingConfig = signingConfigs.getByName("release")
                }
            }
    }
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.9.3")
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
