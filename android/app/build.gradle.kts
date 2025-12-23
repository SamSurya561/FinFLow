plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
        import java.io.FileInputStream

        android {
            namespace = "com.sun.finflow"
            compileSdk = flutter.compileSdkVersion
            ndkVersion = "29.0.14206865"

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }

            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_11.toString()
            }

            defaultConfig {
                applicationId = "com.sun.finflow"
                minSdk = 21
                targetSdk = flutter.targetSdkVersion
                versionCode = 1
                versionName = "0.1.5-Beta"
            }

            // --- FIX: Define keystore properties INSIDE the android block ---
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            }
            // -------------------------------------------------------------

            signingConfigs {
                create("release") {
                    // We use safe calls (?.) to prevent build crashes if the file is empty
                    keyAlias = keystoreProperties["keyAlias"] as String? ?: "sun"
                    keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
                    storeFile = if (keystoreProperties["storeFile"] != null) file(keystoreProperties["storeFile"] as String) else null
                    storePassword = keystoreProperties["storePassword"] as String? ?: ""
                }
            }

            buildTypes {
                release {
                    signingConfig = signingConfigs.getByName("release")
                    // Optional: Enable shrinking for smaller APK size
                    // isMinifyEnabled = true
                    // isShrinkResources = true
                    // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
                }
            }
        }

flutter {
    source = "../.."
}