/*
 * Build the "platformCLI" module.
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
    xtcModule(project(":auth"))
}
