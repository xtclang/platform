/*
 * Build the "stub" module.
 */

import org.xtclang.plugin.tasks.XtcTestTask

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
}

// Make the build fail when any xunit test fails. The XTC plugin's default is to
// only log test failures and exit 0, which would let regressions slip through
// the CI gate.
tasks.withType<XtcTestTask>().configureEach {
    failOnTestFailure = true
}
