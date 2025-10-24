/**
 * settings.gradle.kts is used for bootstrapping a build.
 *
 * This configuration uses Maven Central for release artifacts, Maven Snapshots
 * for snapshot artifacts, and Maven Local for local development.
 */

pluginManagement {
    repositories {
        // Maven Local for local development (checked first for local plugin builds)
        mavenLocal {
            content {
                includeGroup("org.xtclang")
                includeGroup("org.xtclang.xtc-plugin") // Gradle plugin marker artifact
            }
        }
        // Maven Central Snapshots for snapshot artifacts
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        mavenCentral() // Maven Central for release XDK artifacts
        gradlePluginPortal() // Gradle Plugin Portal for release plugin artifacts
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

dependencyResolutionManagement {
    repositories {
        // Maven Local for local development (checked first for local XDK builds)
        mavenLocal {
            content {
                includeGroup("org.xtclang")
            }
        }
        // Node.js distribution repository for node-gradle plugin
        // Commented out: Not needed when node-gradle plugin uses download = true
        // The plugin downloads Node.js directly from nodejs.org instead of resolving through Gradle dependencies
        /*
        ivy {
            name = "Node.js"
            setUrl("https://nodejs.org/dist/")
            patternLayout {
                artifact("v[revision]/[artifact](-v[revision]-[classifier]).[ext]")
            }
            metadataSources {
                artifact()
            }
            content {
                includeModule("org.nodejs", "node")
            }
        }
        */
        // Maven Central Snapshots for snapshot artifacts
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        // Maven Central for release artifacts
        mavenCentral()
    }
}

// Set the name of the main project
rootProject.name = "platform"

// Platform modules
include(":auth")
include(":challenge")
include(":common")
include(":githubCLI")
include(":kernel")
include(":host")
include(":platformDB")
include(":platformUI")
include(":platformCLI")
include(":proxy")
include(":stub")
