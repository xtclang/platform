/*
 * Build the platformDB module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
    xtcModule(projects.common)
}