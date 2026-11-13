plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 서명 키는 쓰지 않는다(주인 결정): 빌드하는 컴퓨터의 시험용(디버그) 키로 서명한다.
// 그래서 새 버전은 덮어쓰기 설치가 되지 않는다 → 안드로이드 새 버전은
// "백업 파일을 앱 밖에 저장·확인 → 기존 앱 삭제 → 새 APK 설치 → 첫 화면에서 복원" 순서(README 참고).

android {
    namespace = "com.kwanhark.vaultassistant.account_vault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 예약 알림에 필요
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kwanhark.vaultassistant.account_vault"
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

dependencies {
    // local_auth 지문 대화상자는 AppCompat 테마가 필요
    implementation("androidx.appcompat:appcompat:1.7.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
