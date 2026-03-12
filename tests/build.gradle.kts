/*
 * Test module for verifying platform native tool dependencies.
 *
 * This is a plain Java project (not XTC) that tests whether the native tools
 * required by the XDK's CertificateManager are installed and functional.
 */

plugins {
    java
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        showStandardStreams = true
    }
}
