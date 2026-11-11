import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 配布用の署名の鍵（デプロイ設計書 6.1）。app/android/key.properties（コミットしない）があれば使う
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.meowscope.meowscope"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 通知の部品（flutter_local_notifications）が新しい Java の日時の機能を使うため、古い Android でも動くよう変換する
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.meowscope.meowscope"
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
        if (!keystoreProperties.isEmpty) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildFeatures {
        // ビルドの種類ごとにアプリの名前（app_name）を変えるため
        resValues = true
    }

    buildTypes {
        // 開発版（debug・profile）は配布版と別のアプリにする（デプロイ設計書 6.3）。名前を足すのは開発側だけ
        debug {
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "MeowScope Dev")
        }
        maybeCreate("profile").apply {
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "MeowScope Dev")
        }
        release {
            resValue("string", "app_name", "MeowScope")
            // key.properties がなければ、今までどおり debug の鍵で署名する（flutter run --release・CI 用）
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
    // ウィジェットの表示の決め方（WidgetModel）の単体テスト
    testImplementation("junit:junit:4.13.2")
    // アプリの更新の APK を OS のインストーラーに渡す FileProvider（プラグインが使う版と同じ）
    implementation("androidx.core:core:1.18.0")
    // 通知の部品が求める、新しい Java の日時の機能の変換（README の指定の版）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
