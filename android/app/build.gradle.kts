import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký bản phát hành, đọc từ android/key.properties.
//
// CH Play TỪ CHỐI mọi bản ký bằng khoá gỡ lỗi — đó là khoá dùng chung do
// Android SDK phát, ai cũng có, nên nó không chứng minh được bản cài đặt này
// do nhóm nào phát hành. Trước đây chỗ này để nguyên `signingConfigs["debug"]`
// theo mẫu Flutter sinh ra, kèm dòng TODO chưa ai làm.
//
// key.properties KHÔNG được commit (đã nằm trong .gitignore). Mất khoá là mất
// luôn khả năng cập nhật ứng dụng đã phát hành, nên giữ bản sao ở nơi an toàn.
// Cách tạo: xem android/KHOA-KY.md.
val tepKhoa = rootProject.file("key.properties")
val khoa = Properties().apply {
    if (tepKhoa.exists()) tepKhoa.inputStream().use { load(it) }
}
val coKhoaThat = khoa.getProperty("storeFile") != null

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

    signingConfigs {
        if (coKhoaThat) {
            create("phatHanh") {
                storeFile = rootProject.file(khoa.getProperty("storeFile"))
                storePassword = khoa.getProperty("storePassword")
                keyAlias = khoa.getProperty("keyAlias")
                keyPassword = khoa.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Chưa có key.properties thì vẫn ký bằng khoá gỡ lỗi để
            // `flutter run --release` chạy được ở máy. Bản ấy KHÔNG nộp lên
            // CH Play được, và dòng cảnh báo bên dưới nói rõ điều đó ngay
            // trong log build thay vì để người ta phát hiện lúc bị từ chối.
            signingConfig = if (coKhoaThat) {
                signingConfigs.getByName("phatHanh")
            } else {
                logger.warn(
                    "[astrotarot] Chua co android/key.properties nen ban release " +
                        "van ky bang khoa go loi. Ban nay KHONG nop len CH Play duoc. " +
                        "Xem android/KHOA-KY.md."
                )
                signingConfigs.getByName("debug")
            }

            // Cố ý KHÔNG bật isMinifyEnabled ở đây. Thu nhỏ gói là việc đáng
            // làm, nhưng R8 cắt theo mã gọi tĩnh mà flutter_webrtc gọi một
            // phần qua reflection; bật lên là phải dựng bản release rồi gọi
            // thử một cuộc mới biết có gãy không. Để thành một việc riêng, có
            // kiểm thử đàng hoàng, chứ không ghép vào bản vá khoá ký.
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
