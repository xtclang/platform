/*
 * Build the "proxy manager" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
    xtcModule(projects.common)
}
