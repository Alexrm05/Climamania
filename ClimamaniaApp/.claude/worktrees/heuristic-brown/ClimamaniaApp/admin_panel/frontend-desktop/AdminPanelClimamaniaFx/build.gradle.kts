plugins {
    application
    java
    id("org.openjfx.javafxplugin") version "0.1.0"
}

group = "com.climamania"
version = "0.1.0"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}

application {
    mainClass.set("com.climamania.adminpanel.App")
}

javafx {
    version = "21.0.2"
    modules = listOf("javafx.controls", "javafx.fxml")
}

dependencies {
    implementation("org.json:json:20240303")
}
