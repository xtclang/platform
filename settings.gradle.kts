/**
 * settings.gradle.kts is used for bootstrapping a build.
 *
 * This configuration uses Maven Central for release artifacts, Maven Snapshots
 * for snapshot artifacts, and Maven Local for local development.
 */

pluginManagement {
    val localOnly: String? by settings

    repositories {
        if (localOnly?.toBoolean() == true) {
            mavenLocal {
                content {
                    includeGroup("org.xtclang")
                    includeGroup("org.xtclang.xtc-plugin") // Gradle plugin marker artifact
                }
            }
            gradlePluginPortal()
            return@repositories
        }
        // Maven Central Snapshots for snapshot artifacts (check first for SNAPSHOT versions)
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        mavenCentral() // Maven Central for release XDK artifacts
        gradlePluginPortal() // Gradle Plugin Portal for release plugin artifacts
        mavenLocal {
            content {
                includeGroup("org.xtclang")
                includeGroup("org.xtclang.xtc-plugin") // Gradle plugin marker artifact
            }
        }
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    val localOnly: String? by settings

    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        if (localOnly?.toBoolean() == true) {
            mavenLocal {
                content {
                    includeGroup("org.xtclang")
                }
            }
            return@repositories
        }
        // Node.js distribution repository for node-gradle plugin
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
        // Maven Central Snapshots for snapshot artifacts (check first for SNAPSHOT versions)
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        // Maven Central for release artifacts
        mavenCentral()
        // Maven Local for local development (checked last)
        mavenLocal {
            content {
                includeGroup("org.xtclang")
            }
        }
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
