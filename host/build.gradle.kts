/*
 * Build the host module.
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
    xtcModule(project(":common"))
    xtcModule(project(":challenge"))
    xtcModule(project(":stub"))
}

xtcCompile {
    verbose = true
}