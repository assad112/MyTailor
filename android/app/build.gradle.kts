plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mytailor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.mytailor"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // MultiDex (حتى مع minSdk>=21 يفضّل تفعيله عند تضخم الدوال)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // إعدادات إصدار نظيف وصغير
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // مؤقتاً: توقيع debug (بدّله بتوقيع الإصدار قبل النشر)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // مع minSdk=23 لا تحتاج مكتبة multidex، لكن لا يضر وجودها.
    implementation("androidx.multidex:multidex:2.0.1")
    // أضف فقط ما تحتاجه من Play Services/Firebase هنا…
}
