plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.astrotarot.astrotarot_mobile"
    // Ghim 37 thay vì dùng flutter.compileSdkVersion (đang là 36).
    //
    // permission_handler_android 14.1.0 ghim cứng compileSdk = 37, và Gradle
    // bắt app phải biên dịch ở mức bằng hoặc cao hơn mọi thư viện nó dùng.
    //
    // Kèm một bẫy riêng của máy này: SDK Manager cài API 37 vào thư mục tên
    // "android-37.0" vì source.properties của gói ghi sai
    // AndroidVersion.ApiLevel=37.0. Gradle tìm "android-37" nên báo "Failed to
    // find target with hash string 'android-37'". Đã xử bằng junction
    // android-37 -> android-37.0 trong thư mục platforms của SDK.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.astrotarot.astrotarot_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
