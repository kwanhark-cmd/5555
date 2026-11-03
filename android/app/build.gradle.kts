plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 출시용 서명 키: GitHub Secrets → CI 가 파일로 풀어 환경 변수로 알려 준다.
// 키 파일·비밀번호는 저장소에 절대 넣지 않는다(.gitignore). 없으면 시험용(디버그) 서명.
val releaseKeystore: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val hasReleaseKey = releaseKeystore != null && file(releaseKeystore).exists()

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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseKeystore!!)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // 같은 키로 서명해야 안드로이드가 "업데이트"로 인식해 금고(앱 자료)를 그대로 둔다.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
