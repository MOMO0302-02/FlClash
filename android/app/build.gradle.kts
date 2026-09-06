import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val releaseStoreFile = file("keystore.jks")
val releaseStorePassword = localProperties.getProperty("storePassword")
val releaseKeyAlias = localProperties.getProperty("keyAlias")
val releaseKeyPassword = localProperties.getProperty("keyPassword")
val hasReleaseSigning = releaseStoreFile.exists() &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

android {
    namespace = "com.clashparty.app"
    compileSdk = libs.versions.compileSdk.get().toInt()
    ndkVersion = libs.versions.ndkVersion.get()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.clashparty.app"
        minSdk = flutter.minSdkVersion
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    sourceSets {
        // 长按图标的快捷方式（res/xml/shortcuts.xml）里，<intent> 的 action 与
        // targetPackage 只能把包名写死：res/ 下的 XML 用不了 AndroidManifest 的
        // ${'$'}{applicationId} 占位符，改成 @string 引用也不行（系统解析那段 intent
        // 用的不是应用自己的资源）。
        //
        // 而 debug 和「没有 keystore 的 release」都给 applicationId 加了后缀，
        // 写死的包名就对不上，表现是长按菜单里点了没反应。所以按变体各放一份：
        // debug 那份放 src/debug/res（AGP 默认就会合进来，不用在这里配），
        // 无签名 release 这份只有在真的缺 keystore 时才加进来。
        if (!hasReleaseSigning) {
            getByName("release").res.srcDir("src/releaseUnsigned/res")
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".dev"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 没有正式签名时用调试签名，包名另给一个后缀。
                //
                // **不能沿用 debug 的 `.dev`**：那样未签名的 release 和 debug
                // 是同一个包名，装 release 会直接把手上正在用的调试版覆盖掉
                // （实测踩过一次）。两个后缀分开，才能装在一起对比。
                signingConfig = signingConfigs.getByName("debug")
                applicationIdSuffix = ".unsigned"
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(project(":service"))
    implementation(project(":common"))
    implementation(project(":core"))
    implementation(libs.core.splashscreen)
    implementation(libs.gson)
    implementation(libs.smali.dexlib2) {
        exclude(group = "com.google.guava", module = "guava")
    }
}
