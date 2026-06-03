plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.climamaniaapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.climamaniaapp"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        // Upgraded to Java 21 LTS for improved performance and latest features
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // 🔑 Habilitamos desugaring para usar java.time en Android < API 26
        isCoreLibraryDesugaringEnabled = true
    }

    // Mostrar advertencias de compilador más detalladas para ayudar a corregir
    // deprecated/unchecked warnings durante el desarrollo.
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:deprecation", "-Xlint:unchecked"))
    }
}

dependencies {
    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.activity)
    implementation(libs.constraintlayout)
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")


    implementation("com.android.volley:volley:1.2.1")

    // Room (SQLite) para persistencia local de eventos
    implementation("androidx.room:room-runtime:2.5.2")
    implementation(libs.camera.camera2.pipe)
    annotationProcessor("androidx.room:room-compiler:2.5.2")

    // ✅ RecyclerView (para la lista de eventos en el calendario)
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.exifinterface:exifinterface:1.3.7")

    // ✅ Desugaring (para poder usar LocalDate, DayOfWeek, etc.)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")

    testImplementation(libs.junit)
    androidTestImplementation(libs.ext.junit)
    androidTestImplementation(libs.espresso.core)
}
