/*
 * Build the "kernel" module.
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
    xtcModule(project(":common"))
    xtcModule(project(":platformDB"))
}

xtcCompile {
    verbose = true
}