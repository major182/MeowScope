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

// key.properties に要る4つの値。そろっていないときは release の署名を作らない（debug のビルドは止めない）
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasSigningKey = signingKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

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
        if (hasSigningKey) {
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
            // 配布用の鍵だけで署名する（NF-SC-12）。鍵がないときは下の確かめで止める
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// 配布版（release）を作るときだけ、配布用の鍵があるかを確かめる（NF-SC-12）
// なぜ：以前は鍵がないと開発用（debug）の鍵で黙って署名していた。それを配ると、
// 正しい鍵の版で上書きできなくなる。debug・profile・テスト・CI のビルドは止めない
// （preReleaseBuild は release を作るときにだけ動く、Android のビルドの最初の作業）
tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            val missing = signingKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "配布版のビルドには配布用の署名の鍵が要ります。app/android/key.properties に " +
                        "${missing.joinToString("・")} がありません（デプロイ設計書 6.1）",
                )
            }
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
