/*
 * Build the "kernel" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(project(":common"))
    xtcModule(project(":platformDB"))
}
