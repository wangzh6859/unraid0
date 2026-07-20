import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------
// 读取签名信息（android/key.properties，由 CI 在构建前自动生成，
// 内容指向 CI 解码出来的 release.jks）。
// 本地开发如果没有这个文件也没关系，release 签名会退回 debug 签名，
// 只影响本地调试，不影响 CI 云端打包。
// ---------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zhaohongli.unraidmobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 应用唯一包名：这个值必须永远保持不变，否则手机会把新版本
        // 当成"另一个 App"，无法实现原地升级安装。
        applicationId = "com.zhaohongli.unraidmobile"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        // versionCode / versionName 由 CI 通过
        // `flutter build apk --build-name=... --build-number=...` 传入，
        // 这里读取 flutter 注入的默认值即可。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有签名信息就用正式签名（CI 环境）；本地没配置时退回 debug 签名，
            // 保证本地也能跑 `flutter build apk` 做测试。
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {}
