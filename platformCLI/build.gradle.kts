/*
 * Build the "platformCLI" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
}
