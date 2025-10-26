/*
 * Build the "platformUI" module.
 */

import com.github.gradle.node.yarn.task.YarnTask

plugins {
    alias(libs.plugins.xtc)
    alias(libs.plugins.node)
}

// The node plugin declares repositories which overrides settings repositories
// We need to explicitly add mavenLocal for SNAPSHOT dependencies, since refresh
// dependencies overwrites existing files for that special case.
repositories {
    mavenLocal()
    maven {
        url = uri("https://central.sonatype.com/repository/maven-snapshots/")
        mavenContent {
            snapshotsOnly()
        }
    }
    mavenCentral()
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
    xtcModule(projects.challenge)
    xtcModule(projects.common)
}

// GUI directories
val guiDir = file("${project.projectDir}/gui")
val guiDistDir = file("$guiDir/dist")

// Configure node-gradle plugin (default working dirs are under projectDir/.gradle by default, as usual
node {
    download = providers.gradleProperty("node.download").map { it.toBoolean() }.getOrElse(true)
    version = libs.versions.nodejs.get()
    npmVersion = libs.versions.npm.get()
    yarnVersion = libs.versions.yarn.get()
    nodeProjectDir = guiDir
}

// Reference existing setup task
val yarnSetup by tasks.existing

// Install node modules
val yarnInstall by tasks.registering(YarnTask::class) {
    args = listOf("install", "--ignore-engines")
    workingDir = guiDir
    dependsOn(yarnSetup)

    // Declare inputs/outputs for proper caching
    inputs.file("$guiDir/package.json")
    inputs.file("$guiDir/yarn.lock")
    outputs.dir("$guiDir/node_modules")
    outputs.cacheIf { true }
}

// Build GUI with Quasar
val buildGui by tasks.registering(YarnTask::class) {
    args = listOf("quasar", "build")
    workingDir = guiDir
    dependsOn(yarnInstall)

    // Declare all inputs that affect the build
    inputs.dir("$guiDir/src")
    inputs.dir("$guiDir/public")
    inputs.file("$guiDir/index.html")
    inputs.file("$guiDir/package.json")
    inputs.file("$guiDir/yarn.lock")
    inputs.file("$guiDir/quasar.config.js")
    inputs.file("$guiDir/postcss.config.cjs")
    inputs.file("$guiDir/jsconfig.json")

    // Outputs
    outputs.dir(guiDistDir)
    outputs.dir("$guiDir/.quasar")
    outputs.cacheIf { true }
}

// Add GUI build output as a resource directory
sourceSets {
    main {
        resources {
            srcDir(guiDistDir)
        }
    }
}

// Make processResources depend on GUI build
val processResources by tasks.existing {
    dependsOn(buildGui)
}
