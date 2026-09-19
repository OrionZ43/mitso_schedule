// Приложение для часов. Собирается отдельно от телефонного:
//
//   cd android && ./gradlew :wear:assembleRelease
//
// Расписание приходит с телефона через Data Layer — сети и своего клиента у
// часов нет.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.z43studios.mitso_schedule.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Тот же идентификатор, что у телефонного приложения: для Wear OS это
        // одно приложение с двумя сборками.
        applicationId = "com.z43studios.mitso_schedule"
        // Wear OS 3 и новее: Pixel Watch 2 — Wear OS 5.
        minSdk = 30
        targetSdk = 36
        // Версия часов должна быть выше телефонной, если их когда-нибудь
        // выкладывать вместе в Play. Пока ставим сбоку, номер тот же.
        versionCode = 3
        versionName = "1.0.2"
    }

    buildFeatures {
        compose = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Своей подписи пока нет — как и у телефонной сборки.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Версии подобраны под AGP 9.0.1 и compileSdk 36 (как у телефонного
    // модуля): более свежие compose и lifecycle требуют AGP 9.1 и SDK 37.
    implementation("androidx.compose.ui:ui:1.9.0")
    implementation("androidx.compose.ui:ui-graphics:1.9.0")

    // Compose для часов: свои компоненты Material 3 — круглый экран,
    // ScalingLazyColumn, TimeText.
    implementation("androidx.wear.compose:compose-material3:1.6.2")
    implementation("androidx.wear.compose:compose-foundation:1.6.2")

    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    implementation("androidx.core:core-ktx:1.16.0")

    // Data Layer: расписание с телефона.
    implementation("com.google.android.gms:play-services-wearable:19.0.0")

    // Плитка «Ближайшая пара».
    implementation("androidx.wear.tiles:tiles:1.5.0")
    implementation("androidx.wear.protolayout:protolayout:1.3.0")
    implementation("androidx.wear.protolayout:protolayout-material3:1.3.0")
    implementation("com.google.guava:guava:33.4.0-android")
}
