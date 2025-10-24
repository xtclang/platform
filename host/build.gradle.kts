/*
 * Build the host module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
    xtcModule(projects.common)
    xtcModule(projects.challenge)
    xtcModule(projects.stub)
}