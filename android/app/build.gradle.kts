import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("../key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.elevar.syncra_arg"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // Usamos la firma de debug por defecto para evitar errores si falta el archivo key.properties
    signingConfigs {
        getByName("debug") {
            // Si tenés datos en key.properties, los cargará, si no, usa los de debug
            keyAlias = keyProperties.getProperty("keyAlias") ?: "androiddebugkey"
            keyPassword = keyProperties.getProperty("keyPassword") ?: "android"
            val storeFileProp = keyProperties.getProperty("storeFile")
            storeFile = if (storeFileProp != null) rootProject.file("../$storeFileProp") else null
            storePassword = keyProperties.getProperty("storePassword") ?: "android"
        }
    }

    defaultConfig {
        applicationId = "com.elevar.syncra_arg"
        minSdk = 21 
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
