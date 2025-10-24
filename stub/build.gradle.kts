/*
 * Build the "stub" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
}
