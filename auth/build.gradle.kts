/*
 * Build the "auth" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(libs.versions.java.get().toInt()))
    }
}

dependencies {
    xdkDistribution(libs.xdk)
}