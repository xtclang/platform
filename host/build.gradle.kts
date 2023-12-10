/*
 * Build the host module.
 */

plugins {
    alias(libs.plugins.xtc)
}

xtcCompile {
    verbose = true
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(project(":common"))
}
