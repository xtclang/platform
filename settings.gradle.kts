/**
 * Settings configuration for XTC Platform project.
 *
 * Repository priority: mavenLocal → Maven Central Snapshots → Maven Central
 */

pluginManagement {
    repositories {
        mavenLocal { content { includeGroup("org.xtclang") } }
        maven("https://central.sonatype.com/repository/maven-snapshots/") {
            mavenContent { snapshotsOnly() }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

dependencyResolutionManagement {
    repositories {
        mavenLocal { content { includeGroup("org.xtclang") } }
        maven("https://central.sonatype.com/repository/maven-snapshots/") {
            mavenContent { snapshotsOnly() }
        }
        mavenCentral()
    }
}

rootProject.name = "platform"

include(
    ":auth",
    ":challenge",
    ":common",
    ":githubCLI",
    ":kernel",
    ":host",
    ":platformDB",
    ":platformUI",
    ":platformCLI",
    ":proxy",
    ":stub"
)
